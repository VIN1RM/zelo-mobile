package br.com.zelo.zelo_mobile

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.hardware.*
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.*
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.UUID
import kotlin.math.abs
import kotlin.math.sqrt

class MonitoringService : Service(), SensorEventListener {
    companion object {
        var instance: MonitoringService? = null
            private set
        const val SERVICE_ID = 10
        const val ALERT_ID = 11
        const val ACTION_RESOLVE = "br.com.zelo.RESOLVE_ALERT"
        @Synchronized fun snapshot(context: Context, uid: String): JSONObject {
            val data = OperationalJournal.read(context)
            val session = data.optJSONObject("session")
            var changed = false
            if (instance == null && session != null && session.optString("status") in listOf("ACTIVE", "LIMITED", "PREPARING")) {
                session.put("status", "INTERRUPTED").put("endedAt", System.currentTimeMillis())
                OperationalJournal.event(data, session.getString("userId"), "session", session); changed = true
            }
            val alert = OperationalJournal.alert(data,uid)
            if ((instance==null || instance?.uid!=uid) && alert?.optString("outcome") == "PENDING" && alert.optLong("deadline") <= System.currentTimeMillis()) {
                alert.put("outcome", "TIMED_OUT").put("preserved", true)
                OperationalJournal.event(data, alert.getString("userId"), "incident", alert); changed = true
            }
            if (changed) OperationalJournal.write(context, data)
            val events = org.json.JSONArray()
            val all = data.optJSONArray("events") ?: org.json.JSONArray()
            for (i in 0 until all.length()) if (all.getJSONObject(i).optString("userId") == uid) events.put(all.getJSONObject(i))
            return JSONObject().put("running", instance?.uid == uid)
                .put("remainingMs",if(instance?.uid==uid) instance!!.remainingMs() else JSONObject.NULL)
                .put("accelerationSamples",if(instance?.uid==uid) instance!!.accelerationSamples else 0)
                .put("rotationSamples",if(instance?.uid==uid) instance!!.rotationSamples else 0)
                .put("session", if(session?.optString("userId") == uid) session else JSONObject.NULL)
                .put("alert", if(alert?.optString("userId") == uid) alert else JSONObject.NULL).put("events", events)
        }
    }
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var sensors: SensorManager
    private var wakeLock: PowerManager.WakeLock? = null
    private var detector = DetectionEngine("pocket")
    private var ringtone: Ringtone? = null
    var uid = ""
        private set
    private var sessionId = ""
    private var lastAcceleration = 0L
    private var lastRotation = 0L
    private var lastMovement = 0L
    private var inactivityWarned = false
    private var lowWarned = false
    private var criticalWarned = false
    private var healthy = false
    private var stopping = false
    private var alertElapsedDeadline=0L
    private var accelerationSamples=0L
    private var rotationSamples=0L
    fun remainingMs():Long? {
        val alert=OperationalJournal.alert(OperationalJournal.read(this),uid)
        if(alert?.optString("userId")!=uid || alert.optString("outcome")!="PENDING" || alertElapsedDeadline==0L) return null
        return (alertElapsedDeadline-SystemClock.elapsedRealtime()).coerceAtLeast(0)
    }
    fun checkDeadline() {
        val remaining=remainingMs() ?: return
        if(remaining==0L) {
            val alert=OperationalJournal.alert(OperationalJournal.read(this),uid)!!
            resolve(alert.getString("id"),"TIMED_OUT")
        }
    }
    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
            if (level < 0 || scale <= 0) return
            val percent = level * 100 / scale
            if (percent <= 10 && !criticalWarned) { criticalWarned = true; lowWarned=true; warn("Bateria crítica", "Bateria em 10% ou menos. A sessão não foi encerrada.") }
            else if (percent <= 20 && !lowWarned) { lowWarned = true; warn("Bateria baixa", "Bateria em 20% ou menos. Confira a carga do aparelho.") }
        }
    }
    private val tick = object : Runnable {
        override fun run() {
            try {
                var data = OperationalJournal.read(this@MonitoringService)
                if((data.optJSONArray("events")?.length() ?: 0)>9000) { failClosed(); return }
                val alert = OperationalJournal.alert(data,uid)
                if (alert?.optString("outcome") == "PENDING" && remainingMs()==0L) {
                    checkDeadline()
                    data = OperationalJournal.read(this@MonitoringService)
                }
                val now = SystemClock.elapsedRealtime()
                val receiving = lastAcceleration > 0 && lastRotation > 0 && now - lastAcceleration < 5000 && now - lastRotation < 5000
                if(wakeLock?.isHeld == false) wakeLock?.acquire(12*60*60*1000L)
                if (receiving != healthy) {
                    healthy = receiving
                    val session = data.optJSONObject("session")
                    if (session != null) {
                        session.put("status", if (healthy) "ACTIVE" else "LIMITED")
                        OperationalJournal.event(data, uid, "session", session); OperationalJournal.write(this@MonitoringService, data)
                        notifications().notify(SERVICE_ID, monitoringNotification())
                    }
                }
                if (now-lastMovement >= 15*60*1000 && !inactivityWarned) {
                    inactivityWarned = true; warn("Sem movimento há 15 minutos", "A sessão continua. Encerre manualmente quando desejar.")
                }
            } catch (_: Exception) { failClosed() }
            if (!stopping) handler.postDelayed(this, 1000)
        }
    }
    override fun onCreate() {
        super.onCreate(); instance = this
        sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        notifications().createNotificationChannel(NotificationChannel("monitoring", "Monitoramento", NotificationManager.IMPORTANCE_LOW))
        notifications().createNotificationChannel(NotificationChannel("emergency", "Alertas de emergência", NotificationManager.IMPORTANCE_HIGH).apply { enableVibration(true) })
        notifications().createNotificationChannel(NotificationChannel("warnings", "Avisos da sessão", NotificationManager.IMPORTANCE_DEFAULT))
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action != "START") { stopSelf(); return START_NOT_STICKY }
        if (uid.isNotEmpty()) return START_NOT_STICKY
        uid = intent.getStringExtra("uid") ?: ""
        sessionId = intent.getStringExtra("sessionId") ?: ""
        if (uid.isBlank() || sessionId.isBlank()) { stopSelf(); return START_NOT_STICKY }
        try {
            val notification = monitoringNotification()
            if (Build.VERSION.SDK_INT >= 34) startForeground(SERVICE_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(SERVICE_ID, notification)
            val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: error("Accelerometer unavailable")
            val gyroscope = sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE) ?: error("Gyroscope unavailable")
            check(sensors.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME))
            check(sensors.registerListener(this, gyroscope, SensorManager.SENSOR_DELAY_GAME))
            detector = DetectionEngine(intent.getStringExtra("position") ?: "pocket")
            val now = System.currentTimeMillis()
            val data = OperationalJournal.read(this)
            val session = JSONObject().put("id", sessionId).put("userId", uid).put("startedAt", now)
                .put("status", "LIMITED").put("position", intent.getStringExtra("position") ?: "pocket").put("local", true)
            data.put("session", session); OperationalJournal.event(data, uid, "session", session); OperationalJournal.write(this, data)
            val power = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ZELO:Monitoring").apply { acquire(12*60*60*1000L) }
            lastMovement = SystemClock.elapsedRealtime()
            registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            handler.post(tick)
        } catch (_: Exception) { failClosed() }
        return START_NOT_STICKY
    }
    override fun onSensorChanged(event: SensorEvent) {
        if (stopping) return
        try {
            val at = event.timestamp / 1000000
            val now = SystemClock.elapsedRealtime()
            if (event.sensor.type == Sensor.TYPE_GYROSCOPE) { rotationSamples++; lastRotation = now; detector.gyro(at, event.values[0], event.values[1], event.values[2]) }
            if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
                accelerationSamples++
                lastAcceleration = now
                val magnitude = sqrt(event.values[0]*event.values[0]+event.values[1]*event.values[1]+event.values[2]*event.values[2])
                if (abs(magnitude-9.80665)>0.8) { lastMovement=now; inactivityWarned=false }
                if (detector.acceleration(at,event.values[0],event.values[1],event.values[2])) triggerAlert()
            }
        } catch (_: Exception) { failClosed() }
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    fun changePosition(position: String) {
        check(position in listOf("pocket","mount"))
        val data=OperationalJournal.read(this)
        val session=data.getJSONObject("session").put("position",position)
        detector.changePosition(position)
        OperationalJournal.event(data,uid,"session",session); OperationalJournal.write(this,data)
    }
    private fun triggerAlert() {
        val data=OperationalJournal.read(this)
        val existing=OperationalJournal.alert(data,uid)
        if (existing?.optString("userId")==uid && existing.optString("outcome") in listOf("PENDING","HELP_REQUESTED","TIMED_OUT") && existing.optString("condition")!="SAFE") return
        val session=data.getJSONObject("session")
        val now=System.currentTimeMillis()
        val alert=JSONObject().put("id",UUID.randomUUID().toString()).put("userId",uid).put("sessionId",sessionId)
            .put("type","POSSIBLE_ACCIDENT").put("position",session.getString("position")).put("occurredAt",now)
            .put("deadline",now+30000).put("outcome","PENDING").put("condition","UNKNOWN").put("preserved",true).put("detectionVersion","experimental-v1")
        alertElapsedDeadline=SystemClock.elapsedRealtime()+30000
        OperationalJournal.putAlert(data,uid,alert); OperationalJournal.event(data,uid,"incident",alert); OperationalJournal.write(this,data)
        notifications().notify(ALERT_ID,alertNotification(alert))
        ringtone=RingtoneManager.getRingtone(this,RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
        if(Build.VERSION.SDK_INT>=28) ringtone?.isLooping=true
        ringtone?.play()
    }
    fun simulateForTest() {
        check((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)!=0 && uid.startsWith("integration-"))
        triggerAlert()
    }
    fun resolve(id: String,outcome: String) {
        val data=OperationalJournal.read(this)
        val alert=OperationalJournal.alert(data,uid) ?: return
        if(alert.optString("userId")!=uid || alert.optString("id")!=id || alert.optString("outcome")!="PENDING") return
        check(outcome in listOf("CANCELLED","HELP_REQUESTED","TIMED_OUT"))
        val actual=if(alertElapsedDeadline>0 && SystemClock.elapsedRealtime()>=alertElapsedDeadline) "TIMED_OUT" else outcome
        alert.put("outcome",actual).put("preserved",actual!="CANCELLED")
        if(actual=="CANCELLED") alert.put("condition","SAFE")
        if(actual=="HELP_REQUESTED") alert.put("condition","NEEDS_HELP")
        OperationalJournal.event(data,uid,"incident",alert); OperationalJournal.write(this,data)
        ringtone?.stop(); ringtone=null
        if(actual=="CANCELLED") notifications().cancel(ALERT_ID)
        else notifications().notify(ALERT_ID, NotificationCompat.Builder(this,"emergency").setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Pedido de ajuda preparado").setContentText("Abra o ZELO para escolher o contato e enviar. Envio não confirmado.")
            .setContentIntent(openApp()).setAutoCancel(true).build())
    }
    fun complete() {
        val data=OperationalJournal.read(this)
        if(OperationalJournal.alert(data,uid)?.optString("outcome")=="PENDING") error("Resolve the alert before stopping")
        data.getJSONObject("session").put("status","COMPLETED").put("endedAt",System.currentTimeMillis())
        OperationalJournal.event(data,uid,"session",data.getJSONObject("session")); OperationalJournal.write(this,data)
        stopping=true; stopSelf()
    }
    fun failClosed() {
        stopping=true
        try {
            val data=OperationalJournal.read(this)
            val session=data.optJSONObject("session")
            if(session!=null) { session.put("status","INTERRUPTED").put("endedAt",System.currentTimeMillis()); OperationalJournal.event(data,uid,"session",session); OperationalJournal.write(this,data) }
        } catch (_:Exception) { /* Do not replace an unreadable journal or claim protection. */ }
        notifications().notify(12,NotificationCompat.Builder(this,"warnings").setSmallIcon(android.R.drawable.ic_dialog_alert).setContentTitle("Monitoramento interrompido")
            .setContentText("Abra o ZELO. Um novo início manual será necessário.").setContentIntent(openApp()).build())
        stopSelf()
    }
    private fun notifications()=getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    private fun warn(title:String,message:String) {
        val alert=OperationalJournal.alert(OperationalJournal.read(this),uid)
        if(alert?.optString("userId")==uid && alert.optString("outcome")=="PENDING") return
        notifications().notify(13,NotificationCompat.Builder(this,"warnings")
            .setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title)
            .setContentText(message).setContentIntent(openApp()).setAutoCancel(true).build())
    }
    private fun openApp()=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun monitoringNotification()=NotificationCompat.Builder(this,"monitoring").setSmallIcon(android.R.drawable.ic_menu_compass)
        .setContentTitle(if(healthy) "ZELO — monitoramento experimental" else "ZELO — monitoramento limitado")
        .setContentText("Abra o aplicativo para revisar ou encerrar a sessão.").setOngoing(true).setContentIntent(openApp()).build()
    private fun alertNotification(alert:JSONObject):Notification {
        fun action(outcome:String,request:Int)=PendingIntent.getBroadcast(this,request,Intent(this,AlertActionReceiver::class.java)
            .setAction(ACTION_RESOLVE).putExtra("id",alert.getString("id")).putExtra("outcome",outcome).putExtra("uid",uid),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this,"emergency").setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Possível acidente — responda em 30 segundos").setContentText("Estou bem ou preciso de ajuda. Nenhuma mensagem será enviada automaticamente.")
            .setCategory(NotificationCompat.CATEGORY_ALARM).setPriority(NotificationCompat.PRIORITY_MAX).setOngoing(true)
            .setContentIntent(openApp()).setVibrate(longArrayOf(0,500,300,500))
            .addAction(0,"Estou bem",action("CANCELLED",1)).addAction(0,"Preciso de ajuda",action("HELP_REQUESTED",2)).build()
    }
    override fun onDestroy() {
        handler.removeCallbacks(tick); sensors.unregisterListener(this)
        try { unregisterReceiver(batteryReceiver) } catch (_:Exception) {}
        if(wakeLock?.isHeld==true) wakeLock?.release()
        ringtone?.stop()
        if(!stopping && uid.isNotEmpty()) {
            try {
                val data=OperationalJournal.read(this)
                val session=data.optJSONObject("session")
                if(session!=null && session.optString("status") in listOf("ACTIVE","LIMITED")) {
                    session.put("status","INTERRUPTED").put("endedAt",System.currentTimeMillis())
                    OperationalJournal.event(data,uid,"session",session); OperationalJournal.write(this,data)
                }
            } catch (_:Exception) {}
        }
        stopForeground(STOP_FOREGROUND_REMOVE); instance=null
        super.onDestroy()
    }
    override fun onBind(intent:Intent?):IBinder?=null
}

class AlertActionReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        if(intent.action!=MonitoringService.ACTION_RESOLVE) return
        val id=intent.getStringExtra("id") ?: return
        val outcome=intent.getStringExtra("outcome") ?: return
        val uid=intent.getStringExtra("uid") ?: return
        try {
            if(MonitoringService.instance?.uid==uid) { MonitoringService.instance!!.resolve(id,outcome); return }
            check(outcome in listOf("CANCELLED","HELP_REQUESTED"))
            val data=OperationalJournal.read(context)
            val alert=OperationalJournal.alert(data,uid) ?: return
            if(alert.optString("userId")!=uid || alert.optString("id")!=id || alert.optString("outcome")!="PENDING") return
            val actual=if(System.currentTimeMillis()>=alert.getLong("deadline")) "TIMED_OUT" else outcome
            alert.put("outcome",actual).put("preserved",actual!="CANCELLED")
            if(actual=="CANCELLED") alert.put("condition","SAFE")
            if(actual=="HELP_REQUESTED") alert.put("condition","NEEDS_HELP")
            OperationalJournal.event(data,alert.getString("userId"),"incident",alert); OperationalJournal.write(context,data)
            val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(MonitoringService.ALERT_ID)
            if(actual!="CANCELLED") {
                val open=PendingIntent.getActivity(context,0,Intent(context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                manager.notify(MonitoringService.ALERT_ID,NotificationCompat.Builder(context,"emergency").setSmallIcon(android.R.drawable.ic_dialog_alert).setContentTitle("Ajuda preparada — envio não confirmado").setContentText("Abra o ZELO para escolher um contato e concluir o envio.").setContentIntent(open).setAutoCancel(true).build())
            }
        } catch (_:Exception) {}
    }
}
