#!/bin/bash

# 本地测试脚本：将PDF文件转换为base64并发送到RunPod endpoint
# 使用方法：./test_pdf_local.sh <PDF文件路径>

# RunPod配置 - 从环境变量读取
if [ -z "$RUNPOD_ENDPOINT_ID" ]; then
    echo "错误：请设置环境变量 RUNPOD_ENDPOINT_ID"
    echo "使用方法：export RUNPOD_ENDPOINT_ID='your_endpoint_id_here'"
    echo "或者使用 'source ./load_env.sh' 来加载环境变量"
    exit 1
fi
ENDPOINT_ID="$RUNPOD_ENDPOINT_ID"

# 从环境变量读取API Key
if [ -z "$RUNPOD_API_KEY" ]; then
    echo "错误：请设置环境变量 RUNPOD_API_KEY"
    echo "使用方法：export RUNPOD_API_KEY='your_api_key_here'"
    echo "或者使用 'source ./load_env.sh' 来加载环境变量"
    exit 1
fi
API_KEY="$RUNPOD_API_KEY"
BASE_URL="https://api.runpod.ai/v2/${ENDPOINT_ID}"

# 检查参数
if [ $# -ne 1 ]; then
    echo "使用方法: $0 <PDF文件路径>"
    echo "示例: $0 ./test_document.pdf"
    exit 1
fi

PDF_PATH="$1"

# 检查文件是否存在
if [ ! -f "$PDF_PATH" ]; then
    echo "错误：文件 $PDF_PATH 不存在"
    exit 1
fi

# 检查文件扩展名
FILE_EXT="${PDF_PATH##*.}"
FILE_EXT_LOWER=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')
if [ "$FILE_EXT_LOWER" != "pdf" ]; then
    echo "警告：文件扩展名 .$FILE_EXT 不是PDF格式"
    echo "建议使用 .pdf 扩展名的文件"
fi

echo "📄 正在处理PDF文件: $PDF_PATH"

# 转换为base64
echo "正在转换PDF为base64..."
PDF_BASE64=$(base64 -i "$PDF_PATH" | tr -d '\n')

if [ $? -ne 0 ]; then
    echo "❌ PDF转换失败"
    exit 1
fi

echo "✅ PDF已转换为base64，长度: ${#PDF_BASE64} 字符"

# 选择请求方式
echo ""
echo "请选择请求方式:"
echo "1. 同步请求 (runsync) - 等待结果返回"
echo "2. 异步请求 (run) - 提交任务"
read -p "请输入选择 (1 或 2，默认为1): " choice

choice=${choice:-1}

# 选择prompt类型
echo ""
echo "请选择处理模式:"
echo "1. layout_parsing - 解析所有布局信息，包括检测和识别（推荐）"
echo "2. layout_detection - 仅布局检测"
echo "3. text_only - 仅文本识别，排除页眉页脚"
read -p "请输入选择 (1、2 或 3，默认为1): " prompt_choice

case $prompt_choice in
    2)
        PROMPT_TYPE="layout_detection"
        ;;
    3)
        PROMPT_TYPE="text_only"
        ;;
    *)
        PROMPT_TYPE="layout_parsing"
        ;;
esac

echo "使用处理模式: $PROMPT_TYPE"

if [ "$choice" = "2" ]; then
    echo "正在发送异步请求..."
    curl -X POST "${BASE_URL}/run" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "{
            \"input\": {
                \"pdf_base64\": \"${PDF_BASE64}\",
                \"prompt_type\": \"${PROMPT_TYPE}\"
            }
        }"
else
    echo "正在发送同步请求..."
    curl -X POST "${BASE_URL}/runsync" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "{
            \"input\": {
                \"pdf_base64\": \"${PDF_BASE64}\",
                \"prompt_type\": \"${PROMPT_TYPE}\"
            }
        }"
fi

echo ""
echo "✅ 请求完成！"
