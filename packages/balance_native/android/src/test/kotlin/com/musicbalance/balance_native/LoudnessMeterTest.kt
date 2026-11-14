package com.musicbalance.balance_native

import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 測試訊號與預期值來自 EBU Tech 3341（容許誤差 ±0.1 LU）。 */
class LoudnessMeterTest {
    /** [segments]：每段（dBFS，秒數）的 1kHz 正弦波，依序接起來。 */
    private fun measure(
        sampleRate: Int,
        channels: Int,
        vararg segments: Pair<Double, Double>,
    ): LoudnessMeter {
        val meter = LoudnessMeter(sampleRate, channels)
        var n = 0L
        for ((dbfs, seconds) in segments) {
            val amplitude = if (dbfs.isInfinite()) 0.0 else 10.0.pow(dbfs / 20)
            val frames = (sampleRate * seconds).toInt()
            val chunk = FloatArray(4096 * channels)
            var done = 0
            while (done < frames) {
                val count = minOf(4096, frames - done)
                for (f in 0 until count) {
                    val v = (amplitude * sin(2 * PI * 1000 * n / sampleRate)).toFloat()
                    for (ch in 0 until channels) chunk[f * channels + ch] = v
                    n++
                }
                meter.addInterleaved(chunk, count * channels)
                done += count
            }
        }
        return meter
    }

    @Test
    fun stereoSineAt48k() {
        val lufs = measure(48000, 2, -23.0 to 20.0).integratedLoudness()!!
        assertEquals(-23.0, lufs, 0.1)
    }

    @Test
    fun stereoSineAt44k() {
        val lufs = measure(44100, 2, -33.0 to 20.0).integratedLoudness()!!
        assertEquals(-33.0, lufs, 0.1)
    }

    @Test
    fun relativeGateIgnoresQuietParts() {
        // EBU 3341 case 3：-36 / -23 / -36 dBFS，安靜的段落被相對門檻排除
        val lufs = measure(48000, 2, -36.0 to 10.0, -23.0 to 60.0, -36.0 to 10.0)
            .integratedLoudness()!!
        assertEquals(-23.0, lufs, 0.1)
    }

    @Test
    fun absoluteGateIgnoresSilence() {
        // EBU 3341 case 5 的概念：中間夾一段幾乎無聲（-72 dBFS）的片段
        val lufs = measure(48000, 2, -26.0 to 20.0, -20.0 to 20.1, -26.0 to 20.0, -72.0 to 10.0)
            .integratedLoudness()!!
        assertEquals(-23.0, lufs, 0.1)
    }

    @Test
    fun monoIsThreeDecibelsQuieterThanStereo() {
        val lufs = measure(48000, 1, -23.0 to 20.0).integratedLoudness()!!
        assertEquals(-26.0, lufs, 0.1)
    }

    @Test
    fun silenceHasNoLoudness() {
        assertNull(measure(48000, 2, Double.NEGATIVE_INFINITY to 5.0).integratedLoudness())
    }

    @Test
    fun samplePeakTracksLargestSample() {
        val meter = measure(48000, 2, -6.0 to 1.0)
        assertEquals(10.0.pow(-6.0 / 20), meter.samplePeak, 0.001)
    }
}
