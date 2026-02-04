package com.studyh2g.androidstartupoptimizationdemo.initializer

import android.app.Application
import android.content.Context
import androidx.startup.Initializer
import com.appsflyer.AppsFlyerLib
import com.studyh2g.androidstartupoptimizationdemo.constants.CommonConstant

/**
 * AppsFlyer SDK 初始化器
 *
 * AppsFlyer 用于归因分析和营销数据追踪
 * 在应用启动时初始化并开始会话追踪
 */
class AppsFlyerInitializer : Initializer<Unit> {

    override fun create(context: Context) {
        AppsFlyerLib.getInstance().init(CommonConstant.APPS_FLYER_KEY, null, context as Application)
        AppsFlyerLib.getInstance().start(context as Application)
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}