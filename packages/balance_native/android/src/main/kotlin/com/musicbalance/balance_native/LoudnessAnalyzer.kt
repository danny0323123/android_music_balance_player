package com.musicbalance.balance_native

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.SystemClock
import android.util.Log
import java.nio.ByteOrder
import kotlin.math.log10

/** 把音檔解碼成 PCM，交給 [LoudnessMeter] 計算響度。 */
object LoudnessAnalyzer {
    private const val TAG = "LoudnessAnalyzer"
    private const val TIMEOUT_US = 10_000L

    class Result(val lufs: Double, val peakDb: Double)

    /** 無法解碼或整首都是靜音時回傳 null。 */
    fun analyze(context: Context, uri: Uri): Result? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(context, uri, null)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: return null
            extractor.selectTrack(track)
            val inputFormat = extractor.getTrackFormat(track)

            codec = MediaCodec.createDecoderByType(inputFormat.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(inputFormat, null, null, 0)
            codec.start()

            val started = SystemClock.elapsedRealtime()
            val meter = decode(extractor, codec) ?: return null
            val lufs = meter.integratedLoudness() ?: return null
            val peakDb = if (meter.samplePeak > 0) 20 * log10(meter.samplePeak) else -120.0
            Log.d(TAG, "%.1f LUFS in %d ms: %s".format(lufs, SystemClock.elapsedRealtime() - started, uri))
            return Result(lufs, peakDb)
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            codec?.release()
            extractor.release()
        }
    }

    private fun decode(extractor: MediaExtractor, codec: MediaCodec): LoudnessMeter? {
        val info = MediaCodec.BufferInfo()
        var meter: LoudnessMeter? = null
        var channels = 0
        var floatPcm = false
        var scratch = FloatArray(0)
        var inputDone = false
        var idleAfterInput = 0

        fun readOutputFormat() {
            // 取樣率、聲道數、PCM 格式以解碼器輸出為準（可能和檔案標示的不同）
            val format = codec.outputFormat
            channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            floatPcm = format.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                format.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
            meter = LoudnessMeter(format.getInteger(MediaFormat.KEY_SAMPLE_RATE), channels)
        }

        var shortScratch = ShortArray(0)

        // 每一輪：先把能送的輸入全部送進解碼器，再把現成的輸出全部取完，
        // 兩邊都沒有進展時才短暫等待。
        // 實測（Pixel 8a）時間主要花在 MediaCodec 每次呼叫的固定開銷（每格約 2ms），
        // 不是等待也不是計算，所以加速靠的是同時分析多首（見 MediaChannel）。
        while (true) {
            var progressed = false
            while (!inputDone) {
                val inIndex = codec.dequeueInputBuffer(0)
                if (inIndex < 0) break
                progressed = true
                val buffer = codec.getInputBuffer(inIndex)!!
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) {
                    codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    inputDone = true
                } else {
                    codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                    extractor.advance()
                }
            }

            var timeout = if (progressed) 0L else TIMEOUT_US
            while (true) {
                val outIndex = codec.dequeueOutputBuffer(info, timeout)
                timeout = 0L
                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    readOutputFormat()
                    continue
                }
                if (outIndex < 0) {
                    // 輸入都送完了，解碼器卻遲遲不回報結束（約 2 秒）：用目前的結果
                    if (!progressed && inputDone && ++idleAfterInput > 200) return meter
                    break
                }
                idleAfterInput = 0
                if (meter == null) readOutputFormat()
                val currentMeter = meter
                if (currentMeter != null && info.size > 0) {
                    val buffer = codec.getOutputBuffer(outIndex)!!
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    buffer.order(ByteOrder.nativeOrder())
                    val count = if (floatPcm) info.size / 4 else info.size / 2
                    if (scratch.size < count) scratch = FloatArray(count)
                    if (floatPcm) {
                        buffer.asFloatBuffer().get(scratch, 0, count)
                    } else {
                        if (shortScratch.size < count) shortScratch = ShortArray(count)
                        buffer.asShortBuffer().get(shortScratch, 0, count)
                        for (i in 0 until count) scratch[i] = shortScratch[i] / 32768f
                    }
                    currentMeter.addInterleaved(scratch, count - count % channels)
                }
                codec.releaseOutputBuffer(outIndex, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return meter
            }
        }
    }
}
