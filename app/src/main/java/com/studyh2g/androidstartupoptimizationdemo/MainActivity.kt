package com.studyh2g.androidstartupoptimizationdemo

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import android.view.ViewTreeObserver
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.studyh2g.androidstartupoptimizationdemo.ui.theme.AndroidStartupOptimizationDemoTheme

class MainActivity : ComponentActivity() {
    private val tag = "startupOptimization"
    private var startupPriority = -4 // 可尝试测试值：-2, -4, -8, -19
    private var attemptTimes = 8
    private val handler = Handler(Looper.getMainLooper())
    private var renderThreadSetupAttempt = 0
    private var renderThreadPrioritySet = false

    /**
     * 方案选择开关
     *
     * 方案1（useAttemptSetPriority = true）：
     *   在 onCreate 中主动多次尝试查找 RenderThread，找到后立即设置优先级
     *   优点：更早设置，可能更早生效
     *   缺点：需要多次重试，可能增加启动耗时
     *
     * 方案2（useAttemptSetPriority = false）：
     *   在 onWindowFocusChanged 中被动等待窗口获得焦点后，通过 OnPreDrawListener
     *   确保 RenderThread 已创建后再设置优先级
     *   优点：时机更可靠，不占用主线程时间
     *   缺点：设置时机较晚，可能错过部分渲染优化机会
     */
    private var useAttemptSetPriority = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AndroidStartupOptimizationDemoTheme {
                // 方案1：在 Compose 首次渲染时尝试设置 RenderThread 优先级
                if (useAttemptSetPriority) {
                    LaunchedEffect(Unit) {
                        trySetupRenderThreadPriority()
                    }
                }
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    ContentScreen(
                        modifier = Modifier.padding(innerPadding)

                    )
                }
            }
        }
    }

    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(newBase)
        Process.setThreadPriority(startupPriority)
    }

    /**
     * 方案2：通过窗口焦点变化来设置 RenderThread 优先级
     * 当窗口获得焦点时，使用 OnPreDrawListener 确保 RenderThread 已创建
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // 方案2：仅在 useAttemptSetPriority 为 false 时执行
        if (!useAttemptSetPriority && hasFocus && !renderThreadPrioritySet) {
            // 使用 OnPreDrawListener 确保 RenderThread 已创建后再设置优先级
            window.decorView.viewTreeObserver.addOnPreDrawListener(
                object : ViewTreeObserver.OnPreDrawListener {
                    override fun onPreDraw(): Boolean {
                        if (!renderThreadPrioritySet) {
                            setRenderThreadPriority(startupPriority)
                            renderThreadPrioritySet = true

                            // 启动完成后恢复默认优先级
                            handler.postDelayed({ safelyResetPriority() }, 5000)
                        }
                        window.decorView.viewTreeObserver.removeOnPreDrawListener(this)
                        return true
                    }
                }
            )
        }
    }

    /**
     * 方案1：通过多次尝试主动查找 RenderThread 来设置优先级
     * 在 RenderThread 创建之前的任何时机都可能调用，如果找不到就定时重试
     */
    private fun trySetupRenderThreadPriority() {
        // 条件：最多尝试x次，且未设置成功
        if (renderThreadSetupAttempt++ < attemptTimes && !renderThreadPrioritySet) {
            try {
                val tid = getRenderThreadTid()
                if (tid != -1) {
                    Process.setThreadPriority(tid, startupPriority)
                    renderThreadPrioritySet = true
                    Log.d(tag, "方案1：成功设置渲染线程优先级: $startupPriority (第${renderThreadSetupAttempt}次尝试)")
                    // 成功设置后，可设置一个较晚的兜底恢复（如5秒后），确保系统健康
                    handler.postDelayed({ safelyResetPriority() }, 5000)
                } else {
                    // 如果没找到，16ms后重试（约一帧时间）
                    handler.postDelayed(::trySetupRenderThreadPriority, 16)
                    Log.d(tag, "方案1：第${renderThreadSetupAttempt}次尝试：未找到渲染线程，稍后重试")
                }
            } catch (e: Exception) {
                Log.e(tag, "方案1：设置渲染线程优先级时发生异常", e)
            }
        } else if (!renderThreadPrioritySet) {
            Log.w(tag, "方案1：已达到最大尝试次数，未能设置渲染线程优先级")
        }
    }

    /**
     * 安全的恢复优先级方法
     */
    private fun safelyResetPriority() {
        try {
            // 恢复主线程优先级
            Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT)
            Log.d(tag, "主线程优先级已恢复")

            // 恢复渲染线程优先级
            val tid = getRenderThreadTid()
            if (tid != -1) {
                Process.setThreadPriority(tid, Process.THREAD_PRIORITY_DEFAULT)
                Log.d(tag, "渲染线程优先级已恢复")
            }

        } catch (e: Exception) {
            Log.e(tag, "恢复线程优先级失败", e)
        } finally {
            handler.removeCallbacksAndMessages(null)
        }
    }

    /**
     * 设置 RenderThread 的优先级
     */
    private fun setRenderThreadPriority(priority: Int) {
        val renderThreadTid = getRenderThreadTid()
        if (renderThreadTid != -1) {
            Process.setThreadPriority(renderThreadTid, priority)
            Log.d("ThreadPriority", "RenderThread($renderThreadTid) priority set to $priority")
        } else {
            Log.d("ThreadPriority", "RenderThread not found yet")
        }
    }
}

@Composable
fun ContentScreen(modifier: Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Filled.DateRange,
            contentDescription = "App Logo",
            modifier = Modifier.size(80.dp),
            tint = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = "Startup Optimization Demo",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Current startup time: 380ms (P50)",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Optimization target: < 320ms (-15.8%)",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(32.dp))
        Button(
            onClick = {  },
            modifier = Modifier.fillMaxWidth(),
            elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp)
        ) {
            Text("View Optimization Details")
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "© 2026 Startup Optimization Demo",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    AndroidStartupOptimizationDemoTheme {
        ContentScreen(modifier = Modifier)
    }
}