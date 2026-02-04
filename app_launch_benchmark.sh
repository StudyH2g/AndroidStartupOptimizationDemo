# 文件名：app_launch_benchmark.sh
# 描述：安卓App启动时间测试工具

# ============================================
# 使用方式
# ============================================
# ./app_launch_benchmark.sh                     # 使用默认配置测试
# ./app_launch_benchmark.sh -n 5      # 测试5次
# ./app_launch_benchmark.sh -c xxx.cfg -n 5 # 自定义配置，测试5次

# ============================================
# 内置默认配置（原 app_config.cfg）
# ============================================
DEFAULT_CONFIG_CONTENT=$(cat << 'EOF'
# App启动时间测试配置文件
# 格式：包名|Activity类名|显示名称|启动类型|备注

# 系统应用 - 冷启动测试
# com.android.settings|com.android.settings.Settings|系统设置|cold|冷启动测试
# com.android.dialer|com.android.dialer.main.impl.MainActivity|拨号器|cold|冷启动测试

# 第三方应用
# com.tencent.mm|com.tencent.mm.ui.LauncherUI|微信|cold|社交应用冷启动
# com.taobao.taobao|com.taobao.tao.homepage.MainActivity3|淘宝|warm|电商应用温启动
com.studyh2g.androidstartupoptimizationdemo|com.studyh2g.androidstartupoptimizationdemo.MainActivity|androidstartupoptimizationdemo|cold|示例应用冷启动

# 测试参数
WAIT_TIME=3
COLD_WAIT_TIME=5
FORCE_STOP=true
CLEAR_DATA=false
TEST_MODE=all
EOF
)

# ============================================
# 自定义配置部分，需要新建app_config.cfg文件
# ============================================
DEFAULT_CONFIG="app_config.cfg"
DEFAULT_ITERATIONS=3
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ============================================
# 报告输出文件夹
# ============================================
REPORT_DIR="start_up_reports"
if [[ ! -d "$REPORT_DIR" ]]; then
    mkdir -p "$REPORT_DIR"
fi
REPORT_FILE="${REPORT_DIR}/launch_report_${TIMESTAMP}.txt"


# ============================================
# 颜色定义
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ============================================
# 工具函数
# ============================================

print_msg() {
    local msg="$1"
    local color="$2"
    echo -e "${color}${msg}${NC}"
    # 同时写入报告文件（去掉颜色代码）
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$REPORT_FILE"
}

print_to_report() {
    echo "$1" >> "$REPORT_FILE"
}

print_to_both() {
    local msg="$1"
    local color="$2"
    echo -e "${color}${msg}${NC}"
    echo "$msg" >> "$REPORT_FILE"
}

# ============================================
# 核心函数
# ============================================

init_report() {
    # 清空并初始化报告文件
    echo "==========================================" > "$REPORT_FILE"
    echo "          APP启动时间测试报告" >> "$REPORT_FILE"
    echo "==========================================" >> "$REPORT_FILE"
    echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
    echo "配置文件: $CONFIG_FILE" >> "$REPORT_FILE"
    echo "测试次数: $ITERATIONS" >> "$REPORT_FILE"
    echo "设备信息: $(adb shell getprop ro.product.model 2>/dev/null || echo '未知')" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "测试详情" >> "$REPORT_FILE"
    echo "--------" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

check_adb() {
    print_msg "检查ADB连接..." "$BLUE"

    if ! adb devices | grep -q "device$"; then
        print_msg "错误：未找到已连接的Android设备" "$RED"
        exit 1
    fi

    print_msg "✓ ADB连接正常" "$GREEN"
}

create_config_template() {
    echo "$DEFAULT_CONFIG_CONTENT" > app_config_template.cfg
    print_msg "配置文件模板已创建：app_config_template.cfg" "$GREEN"
}

parse_config() {
    local config_file=$1

    if [[ ! -f "$config_file" ]]; then
        print_msg "错误：配置文件不存在: $config_file" "$RED"
        exit 1
    fi

    APPS=()
    : "${ITERATIONS:=$DEFAULT_ITERATIONS}"  # ← 只有 ITERATIONS 未定义才设置默认
    WAIT_TIME=2

    # 读取参数
    while IFS='=' read -r key value; do
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        case $key in
            ITERATIONS)
                if [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]]; then
                    ITERATIONS=$value
                fi
                ;;
            WAIT_TIME)
                if [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]]; then
                    WAIT_TIME=$value
                fi
                ;;
        esac
    done < "$config_file"

    # 读取App配置
    while IFS='|' read -r package activity name; do
        package=$(echo "$package" | xargs)
        activity=$(echo "$activity" | xargs)
        name=$(echo "$name" | xargs)

        [[ -z "$package" ]] && continue
        [[ "$package" == \#* ]] && continue
        [[ -z "$activity" ]] && continue
        [[ -z "$name" ]] && name="$package"

        APPS+=("$package|$activity|$name")
    done < <(grep -v -E "^(#|$|ITERATIONS|WAIT_TIME)" "$config_file")

    if [[ ${#APPS[@]} -eq 0 ]]; then
        print_msg "错误：配置文件中未找到有效的App配置" "$RED"
        exit 1
    fi

    print_msg "✓ 加载了 ${#APPS[@]} 个应用" "$GREEN"
    print_msg "测试次数: $ITERATIONS" "$CYAN"
    print_msg "等待时间: ${WAIT_TIME}秒" "$CYAN"

    # 记录到报告
    print_to_report "应用数量: ${#APPS[@]}"
    print_to_report "测试次数: $ITERATIONS"
    print_to_report "等待时间: ${WAIT_TIME}秒"
    print_to_report ""
}

stop_app() {
    local package=$1
    adb shell am force-stop "$package" > /dev/null 2>&1
    sleep 0.5
}

launch_and_measure() {
    local package=$1
    local activity=$2

    # 停止应用确保冷启动
    stop_app "$package"

    # 执行启动命令
    local output
    output=$(adb shell am start -n "$package/$activity" -W 2>&1)

    # 调试：输出原始结果
    # echo "DEBUG: $output"

    # 解析时间
    local total_time=0

    # 尝试多种方式提取TotalTime
    if echo "$output" | grep -q "TotalTime:"; then
        total_time=$(echo "$output" | grep "TotalTime:" | awk '{print $2}' | tr -d '\r')
    elif echo "$output" | grep -q "TotalTime"; then
        total_time=$(echo "$output" | tr ' ' '\n' | grep -A1 "TotalTime" | tail -1 | tr -d '\r')
    fi

    # 验证是否为数字
    if ! [[ "$total_time" =~ ^[0-9]+$ ]]; then
        total_time=0
    fi

    echo "$total_time"
}

test_single_app() {
    local package=$1
    local activity=$2
    local name=$3
    local app_num=$4
    local total_apps=$5

    print_to_both "" ""
    print_to_both "========================================" "$PURPLE"
    print_to_both "[$app_num/$total_apps] 测试应用: $name" "$YELLOW"
    print_to_both "包名: $package" "$CYAN"
    print_to_both "Activity: $activity" "$CYAN"
    print_to_both "----------------------------------------" "$PURPLE"

    local times=()
    local success_count=0

    for ((i=1; i<=ITERATIONS; i++)); do
        print_msg "  第 $i/$ITERATIONS 次测试..." "$BLUE"
        print_to_report "  第 $i 次测试:"

        local launch_time=$(launch_and_measure "$package" "$activity")

        if [[ "$launch_time" -gt 0 ]]; then
            times+=("$launch_time")
            success_count=$((success_count + 1))

            # 显示结果
            local status_msg="    耗时: ${launch_time}ms"
            if [[ "$launch_time" -lt 500 ]]; then
                print_msg "${status_msg} 🚀" "$GREEN"
            elif [[ "$launch_time" -lt 1000 ]]; then
                print_msg "${status_msg} ⚡" "$GREEN"
            elif [[ "$launch_time" -lt 2000 ]]; then
                print_msg "${status_msg}" "$YELLOW"
            else
                print_msg "${status_msg} 🐌" "$RED"
            fi

            # 记录到报告
            print_to_report "    结果: ${launch_time}ms"
        else
            print_msg "    ✗ 启动失败" "$RED"
            print_to_report "    结果: 启动失败"
        fi

        # 返回桌面，等待下一次测试
        adb shell input keyevent KEYCODE_HOME
        sleep "$WAIT_TIME"
    done

    # 显示和记录统计结果
    if [[ ${#times[@]} -gt 0 ]]; then
        calculate_and_record_stats "$name" times[@]
    else
        print_msg "  ✗ 所有测试均失败" "$RED"
        print_to_report "  统计结果: 所有测试均失败"
    fi

    print_to_both "" ""
}

calculate_and_record_stats() {
    local name=$1
    local times_array=("${!2}")

    local sum=0
    local count=${#times_array[@]}
    local min=999999
    local max=0

    for time in "${times_array[@]}"; do
        sum=$((sum + time))
        if [[ $time -lt $min ]]; then min=$time; fi
        if [[ $time -gt $max ]]; then max=$time; fi
    done

    local avg=$((sum / count))
    local result=$(calculate_percentiles "${times_array[@]}")
    local result=$(calculate_percentiles "${times_array[@]}")
    local p50=${result%%|*}
    local rest=${result#*|}
    local p90=${rest%%|*}
    local p95=${rest##*|}

    # 计算标准差
    local variance_sum=0
    for time in "${times_array[@]}"; do
        local diff=$((time - avg))
        variance_sum=$((variance_sum + diff * diff))
    done
    local std_dev=$(echo "scale=0; sqrt($variance_sum / $count)" | bc 2>/dev/null || echo 0)

    # 显示统计结果
    print_to_both "" ""
    print_to_both "========================================" "$PURPLE"
    print_to_both "              📊 统计结果:" "$YELLOW"
    print_to_both "    成功次数: $count/$ITERATIONS" "$CYAN"
    print_to_both "    中位数 (P50): ${p50}ms" "$CYAN"
    print_to_both "    P90 时间: ${p90}ms" "$CYAN"
    print_to_both "    P95 时间: ${p95}ms" "$CYAN"
    print_to_both "    平均时间: ${avg}ms" "$CYAN"
    print_to_both "    最短时间: ${min}ms" "$CYAN"
    print_to_both "    最长时间: ${max}ms" "$CYAN"

    if [[ "$std_dev" -gt 0 ]]; then
        print_to_both "    标准差: ${std_dev}ms" "$CYAN"
    fi

    # 评价
    local evaluation=""
    if [[ $p50 -lt 300 ]]; then
        evaluation="🚀 极快"
    elif [[ $p50 -lt 600 ]]; then
        evaluation="⚡ 快速"
    elif [[ $p50 -lt 1000 ]]; then
        evaluation="✅ 良好"
    elif [[ $p50 -lt 2000 ]]; then
        evaluation="⚠️ 一般"
    else
        evaluation="🐌 较慢"
    fi
    print_to_both "    评价: $evaluation" "$GREEN"

    # 输出当前设备信息
    print_device_info
}

print_device_info() {
      # 设备基础信息
      local manu=$(adb shell getprop ro.product.manufacturer 2>/dev/null)
      local model=$(adb shell getprop ro.product.model 2>/dev/null)
      local brand=$(adb shell getprop ro.product.brand 2>/dev/null)
      local product=$(adb shell getprop ro.product.name 2>/dev/null)
      local android_ver=$(adb shell getprop ro.build.version.release 2>/dev/null)
      local sdk_ver=$(adb shell getprop ro.build.version.sdk 2>/dev/null)
      local cpu_abi=$(adb shell getprop ro.product.cpu.abilist 2>/dev/null)

      print_to_both "" ""
      print_to_both "" ""
      print_to_both "========================================" "$PURPLE"
      print_to_both "              当前设备信息" "$YELLOW"
      print_to_both "设备制造商: $manu" "$CYAN"
      print_to_both "设备型号: $model" "$CYAN"
      print_to_both "设备品牌: $brand" "$CYAN"
      print_to_both "产品名: $product" "$CYAN"
      print_to_both "Android版本: $android_ver" "$CYAN"
      print_to_both "SDK版本: $sdk_ver" "$CYAN"
      print_to_both "CPU ABI: $cpu_abi" "$CYAN"

      # 电池状态
      local battery_info=$(adb shell dumpsys battery | sed -n '/level\|AC powered\|USB powered/p')
      print_to_both "电池状态: $battery_info" "$CYAN"

      # 屏幕信息
      local resolution=$(adb shell wm size | sed 's/Physical size: //')
      local density=$(adb shell wm density | sed 's/Physical density: //')
      print_to_both "屏幕分辨率: $resolution" "$CYAN"
      print_to_both "屏幕密度: $density" "$CYAN"

      # 内存信息（MB格式）
      local mem_total_kb=$(adb shell cat /proc/meminfo | awk '/MemTotal/ {print $2}')
      local mem_free_kb=$(adb shell cat /proc/meminfo | awk '/MemFree/ {print $2}')
      local mem_available_kb=$(adb shell cat /proc/meminfo | awk '/MemAvailable/ {print $2}')
      local mem_total_mb=$((mem_total_kb / 1024))
      local mem_free_mb=$((mem_free_kb / 1024))
      local mem_available_mb=$((mem_available_kb / 1024))
      print_to_both "内存总量: $mem_total_mb MB" "$CYAN"
      print_to_both "估算可用内存: $mem_available_mb MB" "$CYAN"
      print_to_both "当前未使用内存: $mem_free_mb MB" "$CYAN"
}

calculate_percentiles() {
    # stdin should be integers, one per line
    local percentile50=50
    local percentile90=90
    local percentile95=95
    local tmpfile
    tmpfile=$(mktemp)

    # 写入排序后的值
    printf "%s\n" "${times_array[@]}" | sort -n > "$tmpfile"

    # 总数
    local total
    total=$(wc -l < "$tmpfile")

    if (( total == 0 )); then
        echo "0|0|0"
        rm -f "$tmpfile"
        return
    fi

    # 计算 nearest rank 位置
    local idx50 idx90 idx95
    idx50=$(((total * percentile50 + 99) / 100))
    idx90=$(((total * percentile90 + 99) / 100))
    idx95=$(((total * percentile95 + 99) / 100))

    # 边界保护
    (( idx50 < 1 )) && idx50=1
    (( idx90 < 1 )) && idx90=1
    (( idx95 < 1 )) && idx95=1
    (( idx50 > total )) && idx50=$total
    (( idx90 > total )) && idx90=$total
    (( idx95 > total )) && idx95=$total

    # 提取对应行
    local p50 p90 p95
    p50=$(sed -n "${idx50}p" "$tmpfile")
    p90=$(sed -n "${idx90}p" "$tmpfile")
    p95=$(sed -n "${idx95}p" "$tmpfile")

    rm -f "$tmpfile"
    echo "$p50|$p90|$p95"
}

generate_summary() {
    print_to_both "" ""
    print_to_both "========================================" "$PURPLE"
    print_to_both "              测试总结" "$YELLOW"

    # 这里可以添加总结逻辑
    print_to_both "测试完成时间: $(date '+%Y-%m-%d %H:%M:%S')" "$CYAN"
    print_to_both "报告文件: $REPORT_FILE" "$GREEN"

    print_msg "" ""
    print_msg "提示: 查看详细结果请打开报告文件:" "$BLUE"
    print_msg "  cat $REPORT_FILE" "$CYAN"
    print_msg "  或" "$BLUE"
    print_msg "  less $REPORT_FILE" "$CYAN"
}

# ============================================
# 优化 ADB 启动测量：超时控制 + adb 重启
# ============================================

# 默认 adb am start -W 超时时间（秒）
START_TIMEOUT=25
# 每 N 次循环重启 adb server
ADB_RESTART_INTERVAL=50

# 使用 timeout 运行 adb start，并解析结果
launch_and_measure() {
    local package=$1
    local activity=$2

    # 停止应用确保冷启动
    adb shell am force-stop "$package" > /dev/null 2>&1
    sleep 0.5

    # 临时文件保存 adb 输出
    tmpfile=$(mktemp /tmp/adb_output_XXXX.txt)

    # 超时调用 adb start -W
    timeout $START_TIMEOUT adb shell am start -n "$package/$activity" -W > "$tmpfile" 2>&1
    local status=$?

    # 如果 adb start 被 timeout 或 出错
    if [[ $status -ne 0 ]]; then
        echo "ADB start -W 超时或错误 (code=$status)" >> "$tmpfile"
    fi

    # 解析启动时间（TotalTime/WaitTime/ThisTime）
    local total_time=0
    if grep -q "TotalTime" "$tmpfile"; then
        total_time=$(grep "TotalTime" "$tmpfile" | tail -n1 | awk '{print $NF}' | tr -d '\r')
    elif grep -q "ThisTime" "$tmpfile"; then
        total_time=$(grep "ThisTime" "$tmpfile" | tail -n1 | awk '{print $NF}' | tr -d '\r')
    fi

    # 清理
    rm -f "$tmpfile"

    # 确保返回数字
    if ! [[ "$total_time" =~ ^[0-9]+$ ]]; then
        total_time=0
    fi

    echo "$total_time"
}

# 修改 test loop 逻辑，合入 adb 重启
run_all_tests() {
    print_msg "开始测试..." "$YELLOW"
    print_msg "总共 ${#APPS[@]} 个应用，每个测试 $ITERATIONS 次" "$BLUE"
    echo ""

    init_report

    local app_index=1
    local total_apps=${#APPS[@]}
    local iteration_count=0

    for app_info in "${APPS[@]}"; do
        IFS='|' read -r package activity name <<< "$app_info"

        print_to_both "" ""
        print_to_both "========================================" "$PURPLE"
        print_to_both "[应用 $app_index/$total_apps] $name" "$YELLOW"
        print_to_both "包名: $package" "$CYAN"
        print_to_both "Activity: $activity" "$CYAN"
        print_to_both "----------------------------------------" "$PURPLE"

        local times=()
        local success_count=0

        for (( i=1; i<=ITERATIONS; i++ )); do
            ((iteration_count++))

            print_msg "  第 $i/$ITERATIONS 次测试..." "$BLUE"
            print_to_report "  第 $i 次测试:"

            local launch_time=$(launch_and_measure "$package" "$activity")
            if [[ "$launch_time" -gt 0 ]]; then
                times+=("$launch_time")
                success_count=$((success_count+1))
                print_msg "    耗时: ${launch_time}ms" "$GREEN"
                print_to_report "    结果: ${launch_time}ms"
            else
                print_msg "    ✗ 启动失败或超时" "$RED"
                print_to_report "    结果: 启动失败/超时"
            fi

            # 回到 HOME
            adb shell input keyevent KEYCODE_HOME

            # 每隔几次重启 adb 避免 adb daemon 堵塞
            if (( iteration_count % ADB_RESTART_INTERVAL == 0 )); then
                print_msg "    重启 adb server 提升稳定性" "$CYAN"
                adb kill-server
                adb start-server
            fi

            sleep "$WAIT_TIME"
        done

        if [[ ${#times[@]} -gt 0 ]]; then
            calculate_and_record_stats "$name" times[@]
        else
            print_msg "  ✗ 所有测试均失败" "$RED"
            print_to_report "  统计结果: 所有测试均失败"
        fi

        ((app_index++))
    done

    generate_summary

    print_msg "" ""
    print_msg "✓ 所有测试完成" "$GREEN"
    print_msg "详细报告已生成: $REPORT_FILE" "$CYAN"
}

test_command_format() {
    print_msg "测试命令格式..." "$CYAN"

    local test_package="com.android.deskclock"
    local test_activity="com.android.deskclock.DeskClock"

    print_msg "执行命令: adb shell am start -n $test_package/$test_activity -W" "$BLUE"

    local output
    output=$(adb shell am start -n "$test_package/$test_activity" -W 2>&1)

    echo "命令输出:"
    echo "$output"
    echo ""

    local total_time=$(echo "$output" | grep "TotalTime" | awk '{print $2}' 2>/dev/null)
    if [[ -n "$total_time" ]] && [[ "$total_time" =~ ^[0-9]+$ ]]; then
        print_msg "✓ 命令执行成功，获取到时间: ${total_time}ms" "$GREEN"
        return 0
    else
        print_msg "✗ 命令执行失败或格式不正确" "$RED"
        echo "建议:"
        echo "1. 检查包名和Activity是否正确"
        echo "2. 手动执行命令测试: adb shell am start -n com.android.deskclock/com.android.deskclock.DeskClock -W"
        return 1
    fi
}

# ============================================
# 主程序
# ============================================

show_help() {
    cat << EOF
App启动时间测试工具作者：AI+（千里马wx号：androidframework007） v2.0

用法: $0 [选项]

选项:
  -c, --config FILE     指定配置文件 (默认: app_config.cfg)
  -n, --iterations N    指定测试次数 (默认: 3)
  -t, --template        创建配置文件模板
  -T, --test            测试命令格式
  -h, --help            显示帮助信息

示例:
  $0                     # 使用默认配置测试
  $0 -c my_apps.cfg -n 5 # 自定义配置，测试5次
  $0 -T                  # 测试命令格式

报告文件:
  测试完成后会生成: ${REPORT_DIR}/launch_report_YYYYMMDD_HHMMSS.txt
EOF
}

# 参数解析
CONFIG_FILE="$DEFAULT_CONFIG"
ITERATIONS="$DEFAULT_ITERATIONS"
TEST_CMD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -n|--iterations)
            if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                ITERATIONS="$2"
            fi
            shift 2
            ;;
        -t|--template)
            create_config_template
            exit 0
            ;;
        -T|--test)
            TEST_CMD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_msg "未知参数: $1" "$RED"
            show_help
            exit 1
            ;;
    esac
done

# 主函数
main() {
    echo ""
    print_msg "========================================" "$PURPLE"
    print_msg "      APP启动时间测试工具 v2.0" "$YELLOW"
    print_msg "========================================" "$PURPLE"
    echo ""

    # 检查ADB
    check_adb

    if [[ "$TEST_CMD" == true ]]; then
        test_command_format
        exit 0
    fi

    if [[ "$CONFIG_FILE" == "$DEFAULT_CONFIG" ]] && [[ ! -f "$CONFIG_FILE" ]]; then
        TMP_CONFIG=$(mktemp /tmp/app_launch_config_XXXX.cfg)
        echo "$DEFAULT_CONFIG_CONTENT" > "$TMP_CONFIG"
        CONFIG_FILE="$TMP_CONFIG"
    fi

    # 解析配置
    parse_config "$CONFIG_FILE"

    # 运行测试
    run_all_tests

    # 清理临时配置文件
    [[ -n "$TMP_CONFIG" && -f "$TMP_CONFIG" ]] && rm -f "$TMP_CONFIG"
}

# 运行主函数
main