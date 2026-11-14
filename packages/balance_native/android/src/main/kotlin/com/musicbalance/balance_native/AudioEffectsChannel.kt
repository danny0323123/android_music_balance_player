package com.musicbalance.balance_native

import android.media.audiofx.DynamicsProcessing
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 每個播放器（audio session）掛一個 DynamicsProcessing，處理順序：
 * 輸入增益（音量均衡）→ 等化器 → 壓縮器（開車模式）→ 限幅器（避免放大後破音）。
 *
 * 等化器和開車模式是全域設定，套用到所有 session；增益每個 session 各自設定，
 * 這樣淡入淡出時兩首歌可以各自有自己的音量均衡值。
 */
class AudioEffectsChannel : MethodChannel.MethodCallHandler {
    private val sessions = HashMap<Int, DynamicsProcessing>()

    private var eqEnabled = false
    private var eqGains = FloatArray(EQ_CUTOFFS.size)
    private var drivingMode = false

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "music_balance/effects").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                // 回傳 false 表示這台手機不支援（Android 9 以下或建立失敗），Dart 端會改用音量縮小
                "attach" -> result.success(attach(call.argument<Int>("session")!!))
                "release" -> {
                    sessions.remove(call.argument<Int>("session")!!)?.release()
                    result.success(null)
                }
                "setGain" -> {
                    val dp = sessions[call.argument<Int>("session")!!]
                    if (dp != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        dp.setInputGainAllChannelsTo(call.argument<Double>("db")!!.toFloat())
                    }
                    result.success(null)
                }
                "setEqualizer" -> {
                    eqEnabled = call.argument<Boolean>("enabled")!!
                    val gains = call.argument<List<Double>>("gains")!!
                    eqGains = FloatArray(EQ_CUTOFFS.size) { gains.getOrElse(it) { 0.0 }.toFloat() }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) sessions.values.forEach(::applyEq)
                    result.success(null)
                }
                "setDrivingMode" -> {
                    drivingMode = call.argument<Boolean>("enabled")!!
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) sessions.values.forEach(::applyCompressor)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w(TAG, "${call.method} failed", e)
            result.error("EFFECTS_ERROR", e.message, null)
        }
    }

    /** 引擎被銷毀時播放器也都不在了，把全部音效釋放掉。 */
    fun releaseAll() {
        sessions.values.forEach { it.release() }
        sessions.clear()
    }

    private fun attach(session: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        sessions[session]?.let { return true }
        return try {
            val config = DynamicsProcessing.Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
                CHANNELS,
                true, EQ_CUTOFFS.size, // 等化器
                true, 1, // 壓縮器（單一頻段）
                false, 0, // 不用後段等化器
                true, // 限幅器
            ).setPreferredFrameDuration(10f).build()
            val dp = DynamicsProcessing(0, session, config)
            dp.setInputGainAllChannelsTo(0f)
            applyEq(dp)
            applyCompressor(dp)
            dp.setLimiterAllChannelsTo(
                DynamicsProcessing.Limiter(
                    true, true, 0,
                    1f, // attack ms
                    60f, // release ms
                    10f, // ratio
                    -1f, // threshold dBFS
                    0f, // post gain
                ),
            )
            dp.enabled = true
            sessions[session] = dp
            true
        } catch (e: Exception) {
            Log.w(TAG, "DynamicsProcessing unavailable for session $session", e)
            false
        }
    }

    private fun applyEq(dp: DynamicsProcessing) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        val eq = DynamicsProcessing.Eq(true, eqEnabled, EQ_CUTOFFS.size)
        for (i in EQ_CUTOFFS.indices) {
            eq.setBand(i, DynamicsProcessing.EqBand(true, EQ_CUTOFFS[i], if (eqEnabled) eqGains[i] else 0f))
        }
        dp.setPreEqAllChannelsTo(eq)
    }

    /**
     * 開車模式：壓縮動態範圍，讓安靜的段落不會被路噪蓋過、突然大聲的地方不會嚇人。
     * 歌曲已經被音量均衡調到 -14 LUFS 左右，主體大約在 -18 dBFS 上下：
     * 門檻 -30 dBFS、3:1、補償 +8 dB 時，主體大致不變，安靜段落約提高 8 dB，峰值被壓低。
     */
    private fun applyCompressor(dp: DynamicsProcessing) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        val mbc = DynamicsProcessing.Mbc(true, drivingMode, 1)
        mbc.setBand(
            0,
            DynamicsProcessing.MbcBand(
                true, 20000f,
                10f, // attack ms
                200f, // release ms
                3f, // ratio
                -30f, // threshold dBFS
                6f, // knee width dB
                -90f, // noise gate threshold（不使用）
                1f, // expander ratio（不使用）
                0f, // pre gain
                if (drivingMode) 8f else 0f, // post gain（補償）
            ),
        )
        dp.setMbcAllChannelsTo(mbc)
    }

    companion object {
        private const val TAG = "AudioEffects"
        private const val CHANNELS = 2

        /** 10 段等化器，中心頻率 31Hz…16kHz（八度間隔），值是每段的上限頻率。 */
        private val EQ_CUTOFFS = floatArrayOf(44f, 88f, 177f, 354f, 707f, 1414f, 2828f, 5657f, 11314f, 20000f)
    }
}
