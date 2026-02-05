#include <jni.h>
#include <string>
#include <dirent.h>
#include <fstream>
#include <sched.h>
#include <unistd.h>

/**
 * 获取最高频率的 CPU 核心索引（大核）
 * 通过读取 /sys/devices/system/cpu/cpu/cpufreq/cpuinfo_max_freq 文件来比较每个核心的最大频率
 *
 * @param env JNI 环境
 * @param clazz Java 类对象
 * @return 最高频率核心的索引, 如果获取失败则返回 -1
 */
extern "C" JNIEXPORT jint JNICALL
Java_com_studyh2g_androidstartupoptimizationdemo_jni_JniHelper_getMaxFreqCpuIndex(
        JNIEnv* env,
        jclass clazz) {
    // 统计 CPU 核心数量
    int cores = 0;
    DIR *dir;
    struct dirent *ent;
    if((dir = opendir("/sys/devices/system/cpu")) != NULL) {
        while((ent = readdir(dir)) != NULL) {
            std::string path = ent->d_name;
            // 查找以 "cpu" 开头的目录
            if(path.find("cpu") == 0) {
                bool isCore = true;
                // 检查 "cpu" 后面是否全是数字（排除 cpufreq、cpuidle 等非核心目录）
                for(int i = 3; i < path.length(); i++) {
                    if(path[i] < '0' || path[i] > '9') {
                        isCore = false;
                        break;
                    }
                }
                if(isCore) {
                    cores++;
                }
            }
        }
        closedir(dir);
    }
    // 遍历所有核心，找出最高频率的核心
    int maxFreq = -1;
    int maxFreqCoreIndex = -1;
    if (cores != 0) {
        for (int i = 0; i < cores; i++) {
            // 读取每个核心的最大频率文件
            std::string filename = "/sys/devices/system/cpu/cpu" + std::to_string(i) + "/cpufreq/cpuinfo_max_freq";
            std::ifstream cpuInfoMaxFreqFile(filename);
            if (cpuInfoMaxFreqFile.is_open()) {
                std::string line;
                if (std::getline(cpuInfoMaxFreqFile, line)) {
                    try {
                        int freqBound = std::stoi(line);
                        if (freqBound > maxFreq) {
                            maxFreq = freqBound;
                            maxFreqCoreIndex = i;
                        }
                    } catch (const std::invalid_argument& e) {
                        // 频率值解析失败，跳过
                    }
                }
                cpuInfoMaxFreqFile.close();
            }
        }
    }
    return maxFreqCoreIndex;
}

/**
 * 将当前线程绑定到指定的 CPU 核心
 * 绑定后，当前线程只会在指定的核心上运行，可以利用大核提升性能
 *
 * @param env JNI 环境
 * @param clazz Java 类对象
 * @param coreNum 要绑定的 CPU 核心索引
 */
extern "C" JNIEXPORT void JNICALL
Java_com_studyh2g_androidstartupoptimizationdemo_jni_JniHelper_bindToCore(
        JNIEnv* env,
        jclass clazz,
        jint coreNum) {
    cpu_set_t mask;
    // 清空 CPU 集合
    CPU_ZERO(&mask);
    // 将指定核心加入集合
    CPU_SET(coreNum, &mask);
    // 获取当前线程 ID
    pid_t tid = gettid();
    // 设置线程的 CPU 亲和性（绑定到指定核心）
    if (sched_setaffinity(tid, sizeof(mask), &mask) == -1) {
        // 绑定失败
    }
}

/**
 * 获取当前线程绑定的 CPU 核心列表
 * 返回当前线程允许运行的所有 CPU 核心
 *
 * @param env JNI 环境
 * @param clazz Java 类对象
 * @return CPU 核心列表的字符串，如 "Current CPU affinity: 0 1 2 3 4 5 6 7 "
 */
extern "C" JNIEXPORT jstring JNICALL
Java_com_studyh2g_androidstartupoptimizationdemo_jni_JniHelper_getBoundCores(
        JNIEnv* env,
        jclass clazz) {
    cpu_set_t mask;
    // 获取当前线程 ID
    pid_t tid = gettid();
    // 获取当前线程绑定的 CPU 核心列表（失败则返回错误）
    if (sched_getaffinity(tid, sizeof(mask), &mask) == -1) {
        return env->NewStringUTF("Failed to get affinity");
    }
    std::string result = "Current CPU affinity: ";
    // 遍历所有可能的 CPU 核心
    for (int i = 0; i < CPU_SETSIZE; i++) {
        // 检查该核心是否在绑定集合中
        if (CPU_ISSET(i, &mask)) {
            result += std::to_string(i) + " ";
        }
    }
    return env->NewStringUTF(result.c_str());
}
