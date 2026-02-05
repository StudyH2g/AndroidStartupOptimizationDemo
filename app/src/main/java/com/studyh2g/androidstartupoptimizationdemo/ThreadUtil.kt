package com.studyh2g.androidstartupoptimizationdemo

import android.os.Process
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import kotlin.let
import kotlin.text.contains
import kotlin.text.isNotEmpty
import kotlin.text.split
import kotlin.text.toInt

/**
 * 获取渲染线程（RenderThread）的线程 ID（TID）
 *
 * 通过读取 /proc/{pid}/task/{tid}/stat 文件来查找名为 "RenderThread" 的线程。
 * 渲染线程负责 UI 渲染工作，提高其优先级可以加快首帧显示速度。
 *
 * @return RenderThread 的线程 ID，如果未找到则返回 -1
 */
fun getRenderThreadTid() : Int {
    // 获取当前进程的所有线程目录路径：/proc/{pid}/task/
    val taskParentDir = File("/proc/" + Process.myPid() + "/task/")
    if (taskParentDir.isDirectory()) {
        // 列出所有线程目录
        val taskFiles = taskParentDir.listFiles()
        taskFiles?.let {
            for (taskFile in it) {
                var br : BufferedReader? = null
                var line: String?
                try {
                    // 读取线程的 stat 文件，格式：{tid} ({线程名}) ...
                    br = BufferedReader(FileReader(taskFile.getPath() + "/stat"), 100)
                    line = br.readLine()
                    if (line.isNotEmpty()) {
                        // stat 文件内容按空格分割，第1个字段是 TID，第2个字段是线程名（用括号包裹）
                        val param = line.split(" ")
                        if (param.size < 2) {
                            continue
                        }
                        val threadName: String = param[1]
                        // 检查是否是渲染线程（线程名包含 "RenderThread"）
                        if (threadName.contains("RenderThread")) {
                            // 返回 RenderThread 的 TID
                            return param[0].toInt()
                        }
                    }
                } catch (e : Exception) {
                    // 读取失败，继续下一个线程
                } finally {
                    br?.close()
                }
            }
        }
    }
    // 未找到 RenderThread
    return -1
}
