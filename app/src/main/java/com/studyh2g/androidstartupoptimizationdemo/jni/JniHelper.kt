package com.studyh2g.androidstartupoptimizationdemo.jni

class JniHelper {
    companion object {
        @JvmStatic
        external fun getMaxFreqCpuIndex() : Int

        @JvmStatic
        external fun bindToCore(coreIndex : Int)

        @JvmStatic
        external fun getBoundCores() : String
    }
}