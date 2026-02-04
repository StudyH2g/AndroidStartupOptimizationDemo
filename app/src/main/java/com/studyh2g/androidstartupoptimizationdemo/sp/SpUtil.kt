package com.studyh2g.androidstartupoptimizationdemo.sp

import android.content.Context
import com.studyh2g.androidstartupoptimizationdemo.App
import androidx.core.content.edit

object SpUtil {
    private val sp = App.instance.getSharedPreferences("plus", Context.MODE_PRIVATE)

    fun saveStringData(key: String, value: String) {
        sp.edit { putString(key, value) }
    }
}