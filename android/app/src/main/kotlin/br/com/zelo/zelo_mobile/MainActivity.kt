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

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
