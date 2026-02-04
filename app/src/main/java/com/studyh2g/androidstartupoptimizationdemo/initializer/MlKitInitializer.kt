package com.studyh2g.androidstartupoptimizationdemo.initializer

import android.content.Context
import androidx.startup.Initializer
import com.google.mlkit.vision.face.FaceDetection
import timber.log.Timber

/**
 * MLKit 初始化器
 *
 * 说明：由于在 AndroidManifest.xml 中使用 tools:node="remove" 移除了
 * MlKitInitProvider 的自动初始化，因此需要手动触发 MLKit 的初始化。
 *
 * MlKitInitProvider 原本在应用启动时自动初始化 MLKit 内部组件。
 * 我们通过调用 FaceDetection.getClient() 来达到相同的效果。
 *
 * 注意：不调用 close()，让 GC 自然回收临时实例即可。
 */
class MlKitInitializer : Initializer<Unit> {

    override fun create(context: Context) {
        try {
            // 预加载 FaceDetection，触发 MLKit 内部组件初始化
            // 效果和原来的 MlKitInitProvider 一样
            FaceDetection.getClient()

            Timber.d("MLKit 预初始化完成")
        } catch (e: Exception) {
            Timber.e(e, "MLKit 初始化失败")
        }
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
