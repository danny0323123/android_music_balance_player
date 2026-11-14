package com.musicbalance.balance_native

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.tan

/**
 * 依照 ITU-R BS.1770-4 / EBU R128 計算整首歌的響度（integrated loudness, LUFS）。
 *
 * 流程：每個聲道先經過 K-weighting 濾波（高架濾波 + 高通濾波），
 * 以 400ms 區塊、每 100ms 移動一次計算均方值，再做兩段門檻（gating）：
 * 先丟掉低於 -70 LUFS 的區塊，再丟掉比剩下平均低 10 LU 以上的區塊，
 * 這樣歌曲裡安靜的段落不會把整首歌的響度拉低。
 *
 * 一首歌有上千萬個樣本，所以濾波器的係數和狀態都放在區域變數與陣列裡，
 * 避免每個樣本都呼叫物件方法。
 */
class LoudnessMeter(sampleRate: Int, private val channels: Int) {
    // K-weighting 兩段雙二階濾波器的係數（公式與 libebur128 相同，48kHz 時等於 BS.1770 的係數）
    private val sb0: Double
    private val sb1: Double
    private val sb2: Double
    private val sa1: Double
    private val sa2: Double
    private val ha1: Double
    private val ha2: Double

    /** 每個聲道 4 個狀態：高架濾波 z1、z2，高通濾波 z1、z2。 */
    private val state = DoubleArray(channels * 4)

    /** 5.1 聲道的環繞聲道權重 1.41，其餘 1.0（BS.1770 表 3）。 */
    private val weights = DoubleArray(channels) { ch -> if (channels >= 5 && ch >= 3) 1.41 else 1.0 }

    private val subblockSize = (sampleRate * 0.1).roundToInt()

    /** 目前 100ms 子區塊中，各聲道濾波後的平方和。 */
    private val subblockSums = DoubleArray(channels)
    private var subblockFill = 0

    /** 每個完成的 100ms 子區塊：各聲道均方值的加權總和。 */
    private val subblocks = ArrayList<Double>()

    /** 最大樣本絕對值（0..1），用來估計峰值。 */
    var samplePeak = 0.0
        private set

    init {
        val fs = sampleRate.toDouble()

        // 第一段：高架濾波器，模擬頭部對高頻的放大
        var k = tan(PI * 1681.974450955533 / fs)
        var q = 0.7071752369554196
        val vh = 10.0.pow(3.999843853973347 / 20)
        val vb = vh.pow(0.4996667741545416)
        var a0 = 1 + k / q + k * k
        sb0 = (vh + vb * k / q + k * k) / a0
        sb1 = 2 * (k * k - vh) / a0
        sb2 = (vh - vb * k / q + k * k) / a0
        sa1 = 2 * (k * k - 1) / a0
        sa2 = (1 - k / q + k * k) / a0

        // 第二段：高通濾波器（RLB weighting），去掉人耳不敏感的低頻。分子固定是 1, -2, 1
        k = tan(PI * 38.13547087602444 / fs)
        q = 0.5003270373238773
        a0 = 1 + k / q + k * k
        ha1 = 2 * (k * k - 1) / a0
        ha2 = (1 - k / q + k * k) / a0
    }

    /** 交錯排列（L R L R ...）的樣本，數值範圍 -1..1。 */
    fun addInterleaved(samples: FloatArray, count: Int = samples.size) {
        val sb0 = sb0
        val sb1 = sb1
        val sb2 = sb2
        val sa1 = sa1
        val sa2 = sa2
        val ha1 = ha1
        val ha2 = ha2
        val state = state
        val sums = subblockSums
        var peak = samplePeak

        var i = 0
        while (i + channels <= count) {
            for (ch in 0 until channels) {
                val x = samples[i + ch].toDouble()
                val ax = abs(x)
                if (ax > peak) peak = ax
                val s = ch * 4
                // Transposed Direct Form II
                val y1 = sb0 * x + state[s]
                state[s] = sb1 * x - sa1 * y1 + state[s + 1]
                state[s + 1] = sb2 * x - sa2 * y1
                val y2 = y1 + state[s + 2]
                state[s + 2] = -2 * y1 - ha1 * y2 + state[s + 3]
                state[s + 3] = y1 - ha2 * y2
                sums[ch] += y2 * y2
            }
            i += channels
            if (++subblockFill == subblockSize) finishSubblock()
        }
        samplePeak = peak
    }

    private fun finishSubblock() {
        var z = 0.0
        for (ch in 0 until channels) {
            z += weights[ch] * subblockSums[ch] / subblockSize
            subblockSums[ch] = 0.0
        }
        subblocks.add(z)
        subblockFill = 0
    }

    /** 整首歌的響度（LUFS）；太短或全是靜音時回傳 null。 */
    fun integratedLoudness(): Double? {
        // 400ms 區塊 = 連續 4 個 100ms 子區塊的平均（75% 重疊）
        if (subblocks.size < 4) return null
        val blocks = DoubleArray(subblocks.size - 3) { i ->
            (subblocks[i] + subblocks[i + 1] + subblocks[i + 2] + subblocks[i + 3]) / 4
        }

        val absGated = blocks.filter { loudness(it) > ABSOLUTE_GATE }
        if (absGated.isEmpty()) return null
        val relativeGate = loudness(absGated.average()) - 10.0

        val gated = absGated.filter { loudness(it) > relativeGate }
        if (gated.isEmpty()) return null
        return loudness(gated.average())
    }

    private fun loudness(meanSquare: Double): Double = -0.691 + 10 * log10(meanSquare)

    companion object {
        private const val ABSOLUTE_GATE = -70.0
    }
}
