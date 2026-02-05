package com.studyh2g.androidstartupoptimizationdemo

import android.content.Context
import android.os.Bundle
import android.util.Log
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.studyh2g.androidstartupoptimizationdemo.jni.JniHelper
import com.studyh2g.androidstartupoptimizationdemo.ui.theme.AndroidStartupOptimizationDemoTheme

class MainActivity : ComponentActivity() {
    private val tag = "startupOptimization"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AndroidStartupOptimizationDemoTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    ContentScreen(
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }

    /**
     * 在应用启动的最早时机将主线程绑定到 CPU 大核
     *
     * attachBaseContext 是 Activity 生命周期中最早执行的回调，此时主线程还未开始执行繁重的初始化工作。
     * 将主线程绑定到大核可以充分利用大核的高性能，减少启动耗时。
     *
     * @param newBase 新的 Context 基对象
     */
    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(newBase)
        // 打印绑定前的 CPU 核心列表（用于验证）
        Log.d(tag, "attachBaseContext before: ${JniHelper.getBoundCores()}")
        // 获取最高频率的 CPU 核心索引（大核）
        val maxFreqCpuIndex = JniHelper.getMaxFreqCpuIndex()
        if (maxFreqCpuIndex != -1) {
            // 将主线程绑定到大核
            JniHelper.bindToCore(maxFreqCpuIndex)
            // 打印绑定后的 CPU 核心列表（用于验证绑定是否成功）
            Log.d(tag, "attachBaseContext after: ${JniHelper.getBoundCores()}")
        }
    }

    companion object {
        // Used to load the 'androidstartupoptimizationdemo' library on application startup.
        init {
            System.loadLibrary("androidstartupoptimizationdemo")
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