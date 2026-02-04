package com.studyh2g.androidstartupoptimizationdemo

import android.app.Application
import com.appsflyer.AppsFlyerLib
import com.google.firebase.analytics.FirebaseAnalytics
import com.studyh2g.androidstartupoptimizationdemo.constants.CommonConstant
import com.studyh2g.androidstartupoptimizationdemo.sp.SpUtil

class App : Application() {
    companion object {
        lateinit var instance: App
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        AppsFlyerLib.getInstance().init(CommonConstant.APPS_FLYER_KEY, null, this)
        AppsFlyerLib.getInstance().start(this)
        FirebaseAnalytics.getInstance(this).appInstanceId.addOnCompleteListener {
            SpUtil.saveStringData(CommonConstant.FIREBASE_ID, it.result.orEmpty())
        }
    }
}
