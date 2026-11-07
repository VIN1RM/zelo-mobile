package br.com.zelo.zelo_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Presentation-only sensor stream and clearly labelled local test notification. */
class DeviceResourcesBridge(context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler, SensorEventListener {
    private val context = context.applicationContext
    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val events = EventChannel(messenger, "br.com.zelo/resources/accelerometer")
    private val methods = MethodChannel(messenger, "br.com.zelo/resources")
    private var sink: EventChannel.EventSink? = null
    private var foreground = true
    private var registered = false
    private var lastSample = 0L

    init {
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "testNotification" -> {
                    val delay = call.argument<Int>("delaySeconds") ?: 5
                    if (delay !in 0..10) {
                        result.error("INVALID_DELAY", "Prazo de teste inválido.", null)
                    } else if (!notificationAllowed()) {
                        result.error("NOTIFICATIONS_DISABLED", "Permita as notificações do ZELO nos ajustes do Android.", null)
                    } else {
                        // This handler belongs to the application, not the sensor stream.
                        // Locking the screen pauses sensors but leaves the test scheduled.
                        Handler(Looper.getMainLooper()).postDelayed({
                            try { if (notificationAllowed()) showNotification() }
                            catch (_: SecurityException) { /* Permission changed after scheduling. */ }
                        }, delay * 1000L)
                        result.success(null)
                    }
                }
                "testNotificationVisible" -> result.success(
                    notifications.activeNotifications.any { it.id == NOTIFICATION_ID }
                )
                "accelerometerListening" -> result.success(registered)
                "clearTestNotification" -> {
                    notifications.cancel(NOTIFICATION_ID)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun notificationAllowed(): Boolean {
        if (!notifications.areNotificationsEnabled()) return false
        val channel = NotificationChannel(CHANNEL_ID, "Testes dos recursos do aparelho", NotificationManager.IMPORTANCE_HIGH)
        channel.description = "Notificações locais de demonstração. Não representam uma emergência."
        channel.enableVibration(true)
        notifications.createNotificationChannel(channel)
        return notifications.getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun showNotification() {
        val intent = Intent(context, MainActivity::class.java)
            .setAction("br.com.zelo.RESOURCE_TEST")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        notifications.notify(NOTIFICATION_ID, NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("TESTE DO ZELO — possível acidente")
            .setContentText("Notificação de demonstração. Nenhuma emergência foi registrada ou mensagem enviada.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Este é um teste local dos recursos do aparelho. Nenhuma emergência foi registrada ou mensagem enviada. Toque para voltar ao ZELO."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build())
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stopSensor()
        sink = events
        lastSample = 0
        if (foreground) startSensor()
    }

    private fun startSensor() {
        if (registered || sink == null) return
        val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer == null) {
            sink?.error("SENSOR_UNAVAILABLE", "Este aparelho não oferece acelerômetro.", null)
            return
        }
        registered = sensors.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
        if (!registered) sink?.error("SENSOR_UNAVAILABLE", "Não foi possível iniciar a leitura do acelerômetro.", null)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!foreground || !registered || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val now = SystemClock.elapsedRealtime()
        if (lastSample != 0L && now - lastSample < 100) return
        lastSample = now
        sink?.success(mapOf("x" to event.values[0].toDouble(), "y" to event.values[1].toDouble(), "z" to event.values[2].toDouble()))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    override fun onCancel(arguments: Any?) { stopSensor(); sink = null }
    private fun stopSensor() { sensors.unregisterListener(this); registered = false }
    fun pause() { foreground = false; stopSensor() }
    fun resume() { foreground = true; startSensor() }
    fun dispose() { onCancel(null); events.setStreamHandler(null); methods.setMethodCallHandler(null) }

    companion object {
        private const val CHANNEL_ID = "zelo_resource_tests"
        private const val NOTIFICATION_ID = 9042
    }
}
