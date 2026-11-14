package com.musicbalance.music_balance

import com.ryanheise.audioservice.AudioServiceActivity

// 繼承 AudioServiceActivity，讓背景播放服務和畫面共用同一個 Flutter 引擎。
// 原生端的 channel 在 packages/balance_native（plugin），每個引擎都會自動註冊。
class MainActivity : AudioServiceActivity()
