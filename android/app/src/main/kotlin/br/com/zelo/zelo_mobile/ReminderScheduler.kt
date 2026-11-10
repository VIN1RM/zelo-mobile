package br.com.zelo.zelo_mobile

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class ReminderScheduler(private val context: Context) {
    private val preferences = context.getSharedPreferences("zelo_reminders", Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun connect(messenger: BinaryMessenger) {
        MethodChannel(messenger, "br.com.zelo/reminders").setMethodCallHandler { call, result ->
            try {
                val uid = call.argument<String>("uid")
                when (call.method) {
                    "activate" -> { activate(uid); result.success(null) }
                    "load" -> {
                        require(!uid.isNullOrBlank())
                        val config = load(uid)
                        result.success(mapOf("enabled" to config.optBoolean("enabled"),
                            "minutes" to values(config, "minutes"), "weekdays" to values(config, "weekdays")))
                    }
                    "save" -> {
                        require(!uid.isNullOrBlank() && preferences.getString("active", null) == uid)
                        val minutes = call.argument<List<Int>>("minutes") ?: emptyList()
                        val weekdays = call.argument<List<Int>>("weekdays") ?: emptyList()
                        val enabled = call.argument<Boolean>("enabled") == true
                        require(minutes.size in 1..3 && minutes.distinct().size == minutes.size && minutes.all { it in 0..1439 })
                        require(weekdays.isNotEmpty() && weekdays.all { it in 1..7 })
                        channel()
                        if (enabled) check(notifications.areNotificationsEnabled() &&
                            notifications.getNotificationChannel(CHANNEL).importance != NotificationManager.IMPORTANCE_NONE)
                        val config = JSONObject().put("enabled", enabled).put("minutes", JSONArray(minutes.sorted()))
                            .put("weekdays", JSONArray(weekdays.distinct().sorted()))
                        val old = preferences.getString("config:$uid", null)
                        preferences.edit().putString("config:$uid", config.toString()).commit()
                        try { reschedule() } catch (error: Exception) {
                            preferences.edit().putString("config:$uid", old).commit()
                            reschedule()
                            throw error
                        }
                        result.success(null)
                    }
                    "remove" -> {
                        require(!uid.isNullOrBlank())
                        preferences.edit().remove("config:$uid").commit()
                        if (preferences.getString("active", null) == uid) activate(null)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("REMINDER_FAILED", "Não foi possível atualizar os lembretes. Confira as notificações do ZELO nos ajustes do Android e tente novamente.", null)
            }
        }
    }

    private fun channel() {
        notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Lembretes de proteção", NotificationManager.IMPORTANCE_DEFAULT))
    }

    private fun load(uid: String): JSONObject = preferences.getString("config:$uid", null)?.let { JSONObject(it) }
        ?: JSONObject().put("enabled", false).put("minutes", JSONArray(listOf(480)))
            .put("weekdays", JSONArray(listOf(1, 2, 3, 4, 5)))

    private fun values(config: JSONObject, key: String): List<Int> {
        val values = config.optJSONArray(key) ?: JSONArray()
        return (0 until values.length()).map { values.getInt(it) }
    }

    private fun alarm(): PendingIntent = PendingIntent.getBroadcast(context, ID,
        Intent(context, ReminderReceiver::class.java).setAction(ACTION), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun activate(uid: String?) {
        alarms.cancel(alarm())
        notifications.cancel(ID)
        preferences.edit().putString("active", uid).commit()
        reschedule()
    }

    fun reschedule() {
        alarms.cancel(alarm())
        val uid = preferences.getString("active", null) ?: return
        val config = load(uid)
        if (!config.optBoolean("enabled")) { notifications.cancel(ID); return }
        val next = ReminderSchedule.next(System.currentTimeMillis(), values(config, "minutes"), values(config, "weekdays").toSet()) ?: return
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarm())
    }

    fun deliver() {
        val uid = preferences.getString("active", null) ?: return
        val config = load(uid)
        if (!config.optBoolean("enabled")) return
        try {
            val journal = OperationalJournal.read(context)
            val alert = OperationalJournal.alert(journal, uid)
            if (MonitoringService.instance?.uid == uid || alert?.optString("outcome") == "PENDING") return
            channel()
            if (!notifications.areNotificationsEnabled()) return
            val open = PendingIntent.getActivity(context, ID, Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            notifications.notify(ID, NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Vai sair? Prepare sua proteção")
                .setContentText("Abra o ZELO, confira os requisitos e inicie quando quiser.")
                .setContentIntent(open).setAutoCancel(true).build())
        } finally { reschedule() }
    }

    companion object {
        const val ACTION = "br.com.zelo.REMIND_PROTECTION"
        private const val CHANNEL = "protection_reminders"
        private const val ID = 2401
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val scheduler = ReminderScheduler(context)
            when (intent.action) {
                ReminderScheduler.ACTION -> scheduler.deliver()
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> scheduler.reschedule()
            }
        } catch (_: Exception) { }
    }
}
