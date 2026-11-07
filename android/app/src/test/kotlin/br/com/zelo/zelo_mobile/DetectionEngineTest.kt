package br.com.zelo.zelo_mobile

import org.junit.Assert.*
import org.junit.Test

class DetectionEngineTest {
    @Test fun controlledImpactRequiresRotationAndSubsequentQuiet() {
        val engine=DetectionEngine("mount")
        assertFalse(engine.acceleration(1000,50f,0f,0f))
        engine.gyro(1100,5f,0f,0f)
        assertFalse(engine.acceleration(1200,0f,0f,9.80665f))
        assertTrue(engine.acceleration(2800,0f,0f,9.80665f))
        assertFalse(engine.acceleration(3000,80f,0f,0f))
    }
    @Test fun isolatedImpactDoesNotCreateAnAlert() {
        val engine=DetectionEngine("mount")
        assertFalse(engine.acceleration(1000,50f,0f,0f))
        assertFalse(engine.acceleration(1200,0f,0f,9.80665f))
        assertFalse(engine.acceleration(2800,0f,0f,9.80665f))
    }
    @Test fun profilesHaveIndependentExperimentalThresholds() {
        val engine=DetectionEngine("pocket")
        assertFalse(engine.acceleration(1000,50f,0f,0f))
        engine.gyro(1100,5f,0f,0f)
        assertFalse(engine.acceleration(2800,0f,0f,9.80665f))
    }
}
