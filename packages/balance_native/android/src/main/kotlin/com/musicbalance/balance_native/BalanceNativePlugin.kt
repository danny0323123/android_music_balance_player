package com.musicbalance.balance_native

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Flutter 每建立一個引擎都會自動註冊這個 plugin，包括 audio_service 在背景建立的引擎
 * （Android Auto 連線或按桌面小工具時，app 畫面不一定開著）。
 */
class BalanceNativePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        media(binding.applicationContext).register(messenger)
        effects.register(messenger)
        WidgetChannel(binding.applicationContext).register(messenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        effects.releaseAll()
    }

    companion object {
        // 引擎可能被銷毀後重建，執行緒池和音效設定跟著程序活，不要每次重建
        private var media: MediaChannel? = null
        private val effects = AudioEffectsChannel()

        @Synchronized
        private fun media(context: Context): MediaChannel =
            media ?: MediaChannel(context).also { media = it }
    }
}
