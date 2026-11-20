package com.musicbalance.balance_native

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaScannerConnection
import android.net.Uri
import org.jaudiotagger.audio.AudioFileIO
import org.jaudiotagger.audio.mp3.MP3File
import org.jaudiotagger.tag.FieldKey
import org.jaudiotagger.tag.TagOptionSingleton
import org.jaudiotagger.tag.id3.ID3v23Tag
import org.jaudiotagger.tag.images.ArtworkFactory
import java.io.File
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * 音訊指紋：只看壓縮後的音訊資料（MediaExtractor 讀出來的，不含標籤），
 * 所以改歌名、改封面、搬資料夾、改檔名、換手機都不會變。
 * 取開頭和第 30 秒各 64 KB，避免開頭都是靜音的歌撞在一起。
 */
object Fingerprint {
    private const val CHUNK = 64 * 1024
    private const val SECOND_CHUNK_US = 30_000_000L

    fun of(context: Context, uri: Uri): String? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(context, uri, null)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: return null
            extractor.selectTrack(track)
            val digest = MessageDigest.getInstance("SHA-1")
            val buffer = ByteBuffer.allocate(1 shl 20)
            val first = read(extractor, buffer, digest)
            if (first == 0) return null
            extractor.seekTo(SECOND_CHUNK_US, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            if (extractor.sampleTime >= SECOND_CHUNK_US / 2) read(extractor, buffer, digest)
            return digest.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            return null
        } finally {
            extractor.release()
        }
    }

    private fun read(extractor: MediaExtractor, buffer: ByteBuffer, digest: MessageDigest): Int {
        var total = 0
        while (total < CHUNK) {
            buffer.clear()
            val size = extractor.readSampleData(buffer, 0)
            if (size < 0) break
            val n = minOf(size, CHUNK - total)
            digest.update(buffer.array(), 0, n)
            total += n
            extractor.advance()
        }
        return total
    }
}

/** 直接改手機上的音樂檔（需要「所有檔案存取權」），改完通知系統重新索引。 */
object AudioFiles {
    private val keys = mapOf(
        "title" to FieldKey.TITLE,
        "artist" to FieldKey.ARTIST,
        "album" to FieldKey.ALBUM,
        "albumArtist" to FieldKey.ALBUM_ARTIST,
        "genre" to FieldKey.GENRE,
        "year" to FieldKey.YEAR,
    )

    init {
        // 不用桌面 Java 的 ImageIO，封面改用 Android 的方式處理
        TagOptionSingleton.getInstance().isAndroid = true
    }

    /**
     * [fields] 只放要改的欄位，空字串表示清除；[artPath] 不為 null 時換封面。
     * 回傳寫入失敗的檔案路徑。
     */
    fun writeTags(context: Context, paths: List<String>, fields: Map<String, String>, artPath: String?): List<String> {
        val failed = mutableListOf<String>()
        val written = mutableListOf<String>()
        for (path in paths) {
            try {
                val audio = AudioFileIO.read(File(path))
                // Android 讀不到 ID3v2.4 的年份（TDRC），MP3 一律存成 v2.3（TYER）
                if (audio is MP3File) {
                    audio.setID3v2Tag(audio.iD3v2TagAsv24?.let { ID3v23Tag(it) } ?: ID3v23Tag())
                }
                val tag = audio.tagOrCreateAndSetDefault
                for ((name, value) in fields) {
                    val key = keys[name] ?: continue
                    if (value.isEmpty()) tag.deleteField(key) else tag.setField(key, value)
                }
                if (artPath != null) {
                    tag.deleteArtworkField()
                    tag.setField(ArtworkFactory.createArtworkFromFile(File(artPath)))
                }
                audio.commit()
                written.add(path)
            } catch (e: Exception) {
                android.util.Log.w("AudioFiles", "write failed: $path", e)
                failed.add(path)
            }
        }
        scan(context, written)
        return failed
    }

    /** 回傳刪除失敗的檔案路徑。 */
    fun delete(context: Context, paths: List<String>): List<String> {
        val (deleted, failed) = paths.partition { File(it).delete() }
        scan(context, deleted)
        return failed
    }

    /** 等系統把變更寫進 MediaStore，之後 Dart 端重新掃描才看得到。 */
    private fun scan(context: Context, paths: List<String>) {
        if (paths.isEmpty()) return
        val latch = CountDownLatch(paths.size)
        MediaScannerConnection.scanFile(context, paths.toTypedArray(), null) { _, _ -> latch.countDown() }
        latch.await(30, TimeUnit.SECONDS)
    }
}
