package br.com.zelo.zelo_mobile

import kotlin.math.abs
import kotlin.math.sqrt

/** Experimental, uncalibrated candidate detector. Never classifies a confirmed crash. */
class DetectionEngine(private var position: String) {
    private var impactAt = 0L
    private var rotated = false
    private var quietSince = 0L
    private var cooldownUntil = 0L
    fun changePosition(value: String) { position = value; impactAt = 0; rotated = false; quietSince = 0 }
    fun gyro(at: Long, x: Float, y: Float, z: Float) {
        if (impactAt > 0 && at - impactAt <= 1500 && sqrt(x*x + y*y + z*z) > 3.5) rotated = true
    }
    fun acceleration(at: Long, x: Float, y: Float, z: Float): Boolean {
        val magnitude = sqrt(x*x + y*y + z*z).toDouble()
        if (at < cooldownUntil) return false
        val threshold = if (position == "mount") 4.5 * 9.80665 else 5.5 * 9.80665
        if (magnitude > threshold && impactAt == 0L) { impactAt = at; rotated = false; quietSince = 0 }
        if (impactAt == 0L) return false
        if (at - impactAt > 6000) { impactAt = 0; return false }
        if (abs(magnitude - 9.80665) < 1.5) { if (quietSince == 0L) quietSince = at } else quietSince = 0
        if (rotated && quietSince > 0 && at - quietSince >= 1500) {
            cooldownUntil = at + 60000; impactAt = 0; return true
        }
        return false
    }
}
