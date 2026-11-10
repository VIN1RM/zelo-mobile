package br.com.zelo.zelo_mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.ZonedDateTime
import java.util.TimeZone

class ReminderScheduleTest {
    private val zone = TimeZone.getTimeZone("America/Sao_Paulo")
    private fun at(value: String) = ZonedDateTime.parse(value).toInstant().toEpochMilli()

    @Test fun choosesNextTimeTodayAndThenNextWeekday() {
        val monday = at("2026-11-09T07:00:00-03:00[America/Sao_Paulo]")
        assertEquals(at("2026-11-09T08:00:00-03:00[America/Sao_Paulo]"),
            ReminderSchedule.next(monday, listOf(480, 1080), setOf(1, 2, 3, 4, 5), zone))
        assertEquals(at("2026-11-09T18:00:00-03:00[America/Sao_Paulo]"),
            ReminderSchedule.next(monday + 3600000, listOf(480, 1080), setOf(1, 2, 3, 4, 5), zone))
        assertEquals(at("2026-11-16T08:00:00-03:00[America/Sao_Paulo]"),
            ReminderSchedule.next(at("2026-11-13T19:00:00-03:00[America/Sao_Paulo]"), listOf(480), setOf(1, 2, 3, 4, 5), zone))
    }

    @Test fun respectsLocalTimeZoneAndSunday() {
        val sunday = at("2026-11-15T10:00:00Z[UTC]")
        assertEquals(at("2026-11-15T11:00:00Z[UTC]"), ReminderSchedule.next(sunday, listOf(480), setOf(7), zone))
        assertEquals(at("2026-11-22T08:00:00Z[UTC]"), ReminderSchedule.next(sunday, listOf(480), setOf(7), TimeZone.getTimeZone("UTC")))
        assertNull(ReminderSchedule.next(sunday, emptyList(), setOf(7), zone))
    }
}
