package br.com.zelo.zelo_mobile

import java.util.Calendar
import java.util.TimeZone

object ReminderSchedule {
    fun next(now: Long, minutes: List<Int>, weekdays: Set<Int>, zone: TimeZone = TimeZone.getDefault()): Long? {
        if (minutes.isEmpty() || weekdays.isEmpty()) return null
        require(minutes.all { it in 0..1439 } && weekdays.all { it in 1..7 })
        var earliest: Long? = null
        for (offset in 0..7) {
            for (minute in minutes) {
                val candidate = Calendar.getInstance(zone).apply {
                    timeInMillis = now
                    add(Calendar.DATE, offset)
                    set(Calendar.HOUR_OF_DAY, minute / 60)
                    set(Calendar.MINUTE, minute % 60)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val day = ((candidate.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
                val at = candidate.timeInMillis
                if (day in weekdays && at > now && (earliest == null || at < earliest)) earliest = at
            }
        }
        return earliest
    }
}
