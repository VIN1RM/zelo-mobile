package br.com.zelo.zelo_mobile

import android.app.NotificationManager
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var permissionResult:MethodChannel.Result?=null
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if(requestCode==4101) {
            permissionResult?.success((getSystemService(NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled())
            permissionResult=null
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"br.com.zelo/permissions").setMethodCallHandler { call,result ->
            when(call.method) {
                "notificationsGranted" -> result.success((getSystemService(NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled())
                "requestNotifications" -> {
                    if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        if(permissionResult!=null) result.error("BUSY","Aguarde a permissão pendente.",null)
                        else { permissionResult=result; requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),4101) }
                    } else result.success((getSystemService(NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled())
                }
                "openSettings" -> {
                    try { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,android.net.Uri.parse("package:$packageName"))); result.success(null) }
                    catch (_:Exception) { result.error("SETTINGS_UNAVAILABLE","Não foi possível abrir os ajustes.",null) }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"br.com.zelo/monitoring")
            .setMethodCallHandler { call,result ->
                val uid=call.argument<String>("uid") ?: ""
                if(uid.isBlank()) { result.error("INVALID_USER","Entre novamente.",null); return@setMethodCallHandler }
                try {
                    when(call.method) {
                        "snapshot" -> {
                            MonitoringService.instance?.takeIf { it.uid==uid }?.checkDeadline()
                            result.success(MonitoringService.snapshot(this,uid).toString())
                        }
                        "start" -> {
                            check(MonitoringService.instance==null) { "A session already exists" }
                            val notifications=getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                            check(notifications.areNotificationsEnabled()) { "Notifications required" }
                            val sensors=getSystemService(SENSOR_SERVICE) as SensorManager
                            check(sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)!=null && sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE)!=null)
                            val sessionId=call.argument<String>("sessionId") ?: error("Session required")
                            val position=call.argument<String>("position") ?: "pocket"
                            check(position in listOf("pocket","mount"))
                            startForegroundService(Intent(this,MonitoringService::class.java).setAction("START").putExtra("uid",uid).putExtra("sessionId",sessionId).putExtra("position",position))
                            result.success(null)
                        }
                        "stop" -> { val service=MonitoringService.instance; check(service?.uid==uid); service!!.complete(); result.success(null) }
                        "detach" -> { MonitoringService.instance?.takeIf { it.uid==uid }?.failClosed(); result.success(null) }
                        "testAlert" -> {
                            check((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)!=0 && uid.startsWith("integration-"))
                            val service=MonitoringService.instance; check(service?.uid==uid); service!!.simulateForTest(); result.success(null)
                        }
                        "testBackground" -> {
                            check((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)!=0 && uid.startsWith("integration-"))
                            moveTaskToBack(true); result.success(null)
                        }
                        "blockEmergency" -> {
                            val data=OperationalJournal.read(this)
                            val previous=OperationalJournal.alert(data,uid)
                            check(previous?.optString("userId")!=uid || previous.optString("outcome")!="PENDING")
                            val incident=JSONObject(call.argument<String>("incident") ?: error("Incident required")).put("userId",uid)
                            OperationalJournal.putAlert(data,uid,incident); OperationalJournal.write(this,data); result.success(null)
                        }
                        "safe" -> {
                            val data=OperationalJournal.read(this)
                            val alert=OperationalJournal.alert(data,uid)
                            if(alert?.optString("userId")==uid && alert.optString("id")==call.argument<String>("id")) {
                                alert.put("condition","SAFE"); OperationalJournal.write(this,data)
                            }
                            result.success(null)
                        }
                        "dismiss" -> {
                            val data=OperationalJournal.read(this)
                            val alert=OperationalJournal.alert(data,uid)
                            if(alert?.optString("userId")==uid && alert.optString("id")==call.argument<String>("id")) {
                                check(alert.optString("outcome")!="PENDING")
                                OperationalJournal.removeAlert(data,uid);OperationalJournal.write(this,data)
                                (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(MonitoringService.ALERT_ID)
                            }
                            result.success(null)
                        }
                        "position" -> { val service=MonitoringService.instance; check(service?.uid==uid); service!!.changePosition(call.argument<String>("position") ?: "pocket"); result.success(null) }
                        "resolve" -> {
                            val id=call.argument<String>("id") ?: error("Alert required")
                            val outcome=call.argument<String>("outcome") ?: error("Outcome required")
                            check(outcome in listOf("CANCELLED","HELP_REQUESTED"))
                            val service=MonitoringService.instance
                            if(service?.uid==uid) service.resolve(id,outcome)
                            else {
                                val data=OperationalJournal.read(this)
                                val alert=OperationalJournal.alert(data,uid)
                                if(alert?.optString("userId")==uid && alert.optString("id")==id && alert.optString("outcome")=="PENDING") {
                                    val actual=if(System.currentTimeMillis()>=alert.getLong("deadline")) "TIMED_OUT" else outcome
                                    alert.put("outcome",actual).put("preserved",actual!="CANCELLED")
                                    if(actual=="CANCELLED") alert.put("condition","SAFE")
                                    if(actual=="HELP_REQUESTED") alert.put("condition","NEEDS_HELP")
                                    OperationalJournal.event(data,uid,"incident",alert); OperationalJournal.write(this,data)
                                }
                            }
                            result.success(null)
                        }
                        "ack" -> { OperationalJournal.acknowledge(this,uid,(call.argument<List<String>>("ids") ?: emptyList()).toSet()); result.success(null) }
                        "clear" -> { check(MonitoringService.instance?.uid!=uid); OperationalJournal.clear(this,uid); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (_:Exception) { result.error("OPERATION_FAILED","Não foi possível concluir a operação Android. Confira sensores, notificações e o estado da sessão.",null) }
            }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.zelo/device_diagnostics",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "read" -> {
                    val sensors = getSystemService(SENSOR_SERVICE) as SensorManager
                    val notifications =
                        getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    val power = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(
                        mapOf(
                            "androidApi" to Build.VERSION.SDK_INT,
                            "accelerometerAvailable" to
                                (sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                            "gyroscopeAvailable" to
                                (sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null),
                            "notificationsEnabled" to notifications.areNotificationsEnabled(),
                            "batteryOptimizationExempt" to
                                power.isIgnoringBatteryOptimizations(packageName),
                        ),
                    )
                }
                "openNotificationSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                        )
                        result.success(null)
                    } catch (_: android.content.ActivityNotFoundException) {
                        result.error("SETTINGS_UNAVAILABLE", "Settings unavailable", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
