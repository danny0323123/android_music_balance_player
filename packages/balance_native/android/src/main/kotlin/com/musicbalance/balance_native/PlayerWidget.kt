package com.musicbalance.balance_native

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.widget.RemoteViews
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** 桌面小工具：封面、歌名、上一首／播放暫停／下一首。 */
class PlayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        PlayerWidget.render(context)
    }
}

/** Dart 端（lib/platform/home_widget.dart）在切歌、播放暫停時通知這裡更新小工具。 */
class WidgetChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "music_balance/widget").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "update" -> {
                PlayerWidget.save(
                    context,
                    title = call.argument<String>("title"),
                    subtitle = call.argument<String>("subtitle"),
                    playing = call.argument<Boolean>("playing") ?: false,
                    albumId = call.argument<Number>("albumId")?.toLong(),
                    songId = call.argument<Number>("songId")?.toLong(),
                    modified = call.argument<Number>("modified")?.toLong(),
                )
                PlayerWidget.renderAsync(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}

object PlayerWidget {
    private const val PREFS = "player_widget"

    /** audio_service 背景播放用的引擎 id（AudioServicePlugin 的預設值）。 */
    private const val ENGINE_ID = "audio_service_engine"

    /** 按鈕送的媒體按鍵和通知欄、耳機按鍵走同一條路，由 audio_service 處理。 */
    private const val MEDIA_BUTTON_RECEIVER = "com.ryanheise.audioservice.MediaButtonReceiver"

    private val executor = Executors.newSingleThreadExecutor()
    private var cachedArtKey: String? = null
    private var cachedArt: Bitmap? = null

    fun save(
        context: Context,
        title: String?,
        subtitle: String?,
        playing: Boolean,
        albumId: Long?,
        songId: Long?,
        modified: Long?,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("title", title)
            .putString("subtitle", subtitle)
            .putBoolean("playing", playing)
            .putLong("albumId", albumId ?: -1)
            .putLong("songId", songId ?: -1)
            .putLong("modified", modified ?: 0)
            .apply()
    }

    fun renderAsync(context: Context) = executor.execute { render(context) }

    @Synchronized
    fun render(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, PlayerWidgetProvider::class.java)
        if (manager.getAppWidgetIds(component).isEmpty()) return

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString("title", null)
        val hasSong = title != null
        // 程序剛啟動（例如重新開機後）還沒有在播放，不能沿用上次存的狀態
        val playing = prefs.getBoolean("playing", false) &&
            FlutterEngineCache.getInstance().contains(ENGINE_ID)

        val views = RemoteViews(context.packageName, R.layout.player_widget)
        views.setTextViewText(R.id.widget_title, title ?: context.getString(R.string.widget_empty_title))
        views.setTextViewText(
            R.id.widget_subtitle,
            if (hasSong) prefs.getString("subtitle", "") else context.getString(R.string.widget_empty_subtitle),
        )
        val art = if (hasSong) {
            art(context, prefs.getLong("albumId", -1), prefs.getLong("songId", -1), prefs.getLong("modified", 0))
        } else {
            null
        }
        if (art != null) {
            views.setImageViewBitmap(R.id.widget_art, art)
        } else {
            views.setImageViewResource(R.id.widget_art, R.drawable.widget_art_placeholder)
        }
        views.setImageViewResource(R.id.widget_play, if (playing) R.drawable.widget_pause else R.drawable.widget_play)
        views.setContentDescription(
            R.id.widget_play,
            context.getString(if (playing) R.string.widget_pause else R.string.widget_play),
        )

        val open = openApp(context)
        views.setOnClickPendingIntent(R.id.widget_art, open)
        views.setOnClickPendingIntent(R.id.widget_info, open)
        // 還沒播過任何歌時佇列是空的，按鈕也改成打開 app
        views.setOnClickPendingIntent(
            R.id.widget_prev,
            if (hasSong) mediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS) else open,
        )
        views.setOnClickPendingIntent(
            R.id.widget_play,
            if (hasSong) mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE) else open,
        )
        views.setOnClickPendingIntent(
            R.id.widget_next,
            if (hasSong) mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT) else open,
        )
        manager.updateAppWidget(component, views)
    }

    /** 小工具的圖片有大小限制，用 512 的快取縮成 256。 */
    private fun art(context: Context, albumId: Long, songId: Long, modified: Long): Bitmap? {
        if (songId < 0) return null
        val key = "$songId-$modified"
        if (cachedArtKey == key) return cachedArt
        val file = AlbumArt.file(context, albumId, songId, modified)
        val bitmap = file?.let {
            BitmapFactory.decodeFile(it.path, BitmapFactory.Options().apply { inSampleSize = 2 })
        }
        cachedArtKey = key
        cachedArt = bitmap
        return bitmap
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)!!
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun mediaButton(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
            .setComponent(ComponentName(context.packageName, MEDIA_BUTTON_RECEIVER))
            .putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        // 和 audio_service 通知欄按鈕的 requestCode（= keyCode）錯開
        return PendingIntent.getBroadcast(
            context, 1000 + keyCode, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
