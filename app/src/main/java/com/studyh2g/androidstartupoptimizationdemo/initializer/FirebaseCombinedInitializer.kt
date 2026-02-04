package com.studyh2g.androidstartupoptimizationdemo.initializer

import android.content.Context
import androidx.startup.Initializer
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.studyh2g.androidstartupoptimizationdemo.constants.CommonConstant
import com.studyh2g.androidstartupoptimizationdemo.sp.SpUtil
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import timber.log.Timber

/**
 * Firebase SDK 初始化器
 *
 * Firebase 原本通过 FirebaseInitProvider 自动初始化（已在 Manifest 中移除）
 *
 * 优化策略：内部异步化
 * - FirebaseApp.initializeApp()：轻量操作，主线程执行
 * - 获取 appInstanceId：后台协程处理，不阻塞主线程
 */
class FirebaseCombinedInitializer : Initializer<Unit> {

    override fun create(context: Context) {
        // 初始化 FirebaseApp（轻量操作，主线程执行）
        val firebaseApp = FirebaseApp.initializeApp(context)
        if (firebaseApp == null) {
            Timber.tag("FirebaseInit").w("Firebase 未初始化（可能未配置 google‑services.json）")
        } else {
            Timber.tag("FirebaseInit").i("Firebase 初始化成功")
        }

        // 异步获取 appInstanceId，不阻塞主线程
        CoroutineScope(Dispatchers.IO).launch {
            try {
                FirebaseAnalytics.getInstance(context).appInstanceId
                    .addOnCompleteListener { task ->
                        task.result?.let { id ->
                            SpUtil.saveStringData(CommonConstant.FIREBASE_ID, id)
                            Timber.tag("FirebaseInit").i("Firebase appInstanceId 保存成功")
                        }
                    }
            } catch (e: Exception) {
                Timber.tag("FirebaseInit").e(e, "获取 appInstanceId 失败")
            }
        }
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
