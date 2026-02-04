package com.studyh2g.androidstartupoptimizationdemo.initializer

import android.app.Application
import android.content.Context
import androidx.startup.Initializer
import com.facebook.appevents.AppEventsLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Facebook SDK 初始化器
 * Facebook SDK 通过 ContentProvider 自动初始化（已在 Manifest 中移除默认 Provider）
 * 这里只需要激活 App Events
 */
class FacebookManualInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        // FacebookSdk.sdkInitialize() 在新版本中已过时，会通过 ContentProvider 自动初始化
        // 我们已在 Manifest 中移除了 FacebookInitProvider，改用 Startup 手动控制

        // 使用协程在后台线程激活 App Events，避免阻塞
        CoroutineScope(Dispatchers.IO).launch {
            try {
                AppEventsLogger.activateApp(context as Application)
            } catch (e: Exception) {
                // 忽略初始化失败，避免影响启动
            }
        }
    }

    override fun dependencies(): List<Class<out Initializer<*>?>?> = emptyList()
}