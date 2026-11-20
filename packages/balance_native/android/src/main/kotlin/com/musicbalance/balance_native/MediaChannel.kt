package com.musicbalance.balance_native

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** 給 Dart 端（lib/platform/media_store.dart）使用：查詢 MediaStore、讀取專輯封面。 */
class MediaChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private val executor = Executors.newFixedThreadPool(2)

    // 響度分析：時間主要卡在 MediaCodec 每次呼叫的固定開銷，而不是 CPU，
    // 所以背景同時分析 3 首；正在播放的歌走另一條執行緒，不用排在背景後面。
    private val analysisExecutor = Executors.newFixedThreadPool(ANALYSIS_THREADS)
    private val priorityAnalysisExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        /** 要和 Dart 端 LoudnessService.backgroundWorkers 一致。 */
        const val ANALYSIS_THREADS = 3
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "music_balance/media").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "queryAudio" -> {
                // 已經有指紋、且檔案沒改過的歌：id → dateModified，不用重算
                val known = call.argument<Map<Number, Number>>("known").orEmpty()
                    .entries.associate { it.key.toLong() to it.value.toLong() }
                runAsync(result) { queryAudio(known) }
            }
            "albumArt" -> {
                val albumId = call.argument<Number>("albumId")!!.toLong()
                val songId = call.argument<Number>("songId")!!.toLong()
                val modified = call.argument<Number>("modified")!!.toLong()
                val size = call.argument<Int>("size") ?: AlbumArt.SIZE
                runAsync(result) { AlbumArt.file(context, albumId, songId, modified, size)?.path }
            }
            "writeTags" -> {
                val paths = call.argument<List<String>>("paths")!!
                val fields = call.argument<Map<String, String>>("fields").orEmpty()
                val art = call.argument<String>("artPath")
                runAsync(result) { AudioFiles.writeTags(context, paths, fields, art) }
            }
            "deleteFiles" -> {
                val paths = call.argument<List<String>>("paths")!!
                runAsync(result) { AudioFiles.delete(context, paths) }
            }
            "analyzeLoudness" -> {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                val priority = call.argument<Boolean>("priority") ?: false
                runAsync(result, if (priority) priorityAnalysisExecutor else analysisExecutor) {
                    LoudnessAnalyzer.analyze(context, uri)?.let {
                        mapOf("lufs" to it.lufs, "peakDb" to it.peakDb)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(
        result: MethodChannel.Result,
        executor: java.util.concurrent.Executor = this.executor,
        block: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("MEDIA_ERROR", e.message, null) }
            }
        }
    }

    private fun queryAudio(known: Map<Long, Long>): List<Map<String, Any?>> {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        // 曲風、專輯演出者欄位 Android 11 起才公開
        val hasGenre = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.YEAR,
        ) + if (hasGenre) arrayOf(MediaStore.Audio.Media.GENRE, MediaStore.Audio.Media.ALBUM_ARTIST) else emptyArray()
        // 排除鈴聲、通知音、鬧鐘音；其他太短的檔案由 Dart 端依設定過濾。
        // 用 IS NOT 1 而不是 = 0：小米等系統這些欄位是 NULL，= 0 會把所有歌都濾掉
        val selection = "${MediaStore.Audio.Media.IS_RINGTONE} IS NOT 1 AND " +
            "${MediaStore.Audio.Media.IS_NOTIFICATION} IS NOT 1 AND " +
            "${MediaStore.Audio.Media.IS_ALARM} IS NOT 1"

        val songs = mutableListOf<MutableMap<String, Any?>>()
        context.contentResolver.query(collection, projection, selection, null, null)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durationCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val trackCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val addedCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val modifiedCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
            val dataCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val yearCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
            val genreCol = if (hasGenre) c.getColumnIndexOrThrow(MediaStore.Audio.Media.GENRE) else -1
            val albumArtistCol = if (hasGenre) c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ARTIST) else -1

            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val path = c.getString(dataCol) ?: continue
                val file = File(path)
                songs.add(
                    mutableMapOf(
                        "id" to id,
                        "uri" to ContentUris.withAppendedId(collection, id).toString(),
                        "path" to path,
                        "folder" to (file.parent ?: ""),
                        "title" to (c.getString(titleCol)?.takeIf { it.isNotBlank() }
                            ?: file.nameWithoutExtension),
                        "artist" to c.getString(artistCol).orUnknownNull(),
                        "album" to c.getString(albumCol).orUnknownNull(),
                        "albumId" to c.getLong(albumIdCol),
                        "duration" to c.getLong(durationCol),
                        "track" to c.getInt(trackCol),
                        "dateAdded" to c.getLong(addedCol),
                        "dateModified" to c.getLong(modifiedCol),
                        "year" to c.getInt(yearCol).takeIf { it > 0 },
                        "genre" to (if (genreCol >= 0) c.getString(genreCol).orUnknownNull() else null),
                        "albumArtist" to (if (albumArtistCol >= 0) c.getString(albumArtistCol).orUnknownNull() else null),
                    )
                )
            }
        }

        // 新加入或改過的檔案才算指紋，同時讀 4 個檔案
        val pool = Executors.newFixedThreadPool(4)
        try {
            songs.filter { known[it["id"] as Long] != it["dateModified"] as Long }
                .map { song ->
                    pool.submit {
                        song["fingerprint"] = Fingerprint.of(context, Uri.parse(song["uri"] as String))
                    }
                }
                .forEach { it.get() }
        } finally {
            pool.shutdown()
        }
        return songs
    }

    /** MediaStore 對缺少的資訊會回傳 "<unknown>"，統一轉成 null 讓 Dart 端顯示在地化文字。 */
    private fun String?.orUnknownNull(): String? =
        this?.takeIf { it.isNotBlank() && it != MediaStore.UNKNOWN_STRING }

}

/** 歌曲封面快取，app 畫面、桌面小工具、Android Auto（[ArtProvider]）共用。 */
object AlbumArt {
    const val SIZE = 512

    /**
     * 把封面縮圖存到 cache 資料夾並回傳檔案；沒有封面時回傳 null。
     * 檔名含修改時間：在 app 裡換了封面後，自動改用新的快取。
     */
    fun file(context: Context, albumId: Long, songId: Long, modified: Long, size: Int = SIZE): File? {
        val dir = File(context.cacheDir, "art").apply { mkdirs() }
        val file = File(dir, "$songId-$modified-$size.jpg")
        if (file.exists()) return file

        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val songUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId
                )
                context.contentResolver.loadThumbnail(songUri, Size(size, size), null)
            } else {
                val artUri = Uri.parse("content://media/external/audio/albumart/$albumId")
                context.contentResolver.openInputStream(artUri)?.use {
                    BitmapFactory.decodeStream(it)
                }
            }
        } catch (e: Exception) {
            null
        } ?: return null

        // 先寫到暫存檔再改名，避免同時讀取的人拿到寫一半的檔案
        val tmp = File(dir, "${file.name}.${Thread.currentThread().id}.tmp")
        tmp.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        tmp.renameTo(file)
        return file
    }
}
