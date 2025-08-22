#!/bin/bash

# 本地测试脚本：将图片转换为base64并发送到RunPod endpoint
# 使用方法：./test_local.sh <图片路径>

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
    echo "使用方法: $0 <图片路径>"
    echo "示例: $0 ./test_image.jpg"
    exit 1
fi

IMAGE_PATH="$1"

# 检查文件是否存在
if [ ! -f "$IMAGE_PATH" ]; then
    echo "错误：文件 $IMAGE_PATH 不存在"
    exit 1
fi

# 检查文件扩展名
FILE_EXT="${IMAGE_PATH##*.}"
VALID_EXTENSIONS="jpg jpeg png bmp tiff tif webp"
FILE_EXT_LOWER=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')
if [[ ! " $VALID_EXTENSIONS " =~ " $FILE_EXT_LOWER " ]]; then
    echo "警告：文件扩展名 .$FILE_EXT 可能不是支持的图片格式"
    echo "支持的格式: $VALID_EXTENSIONS"
fi

echo "🖼️  正在处理图片: $IMAGE_PATH"

# 转换为base64
echo "正在转换图片为base64..."
IMG_BASE64=$(base64 -i "$IMAGE_PATH" | tr -d '\n')

if [ $? -ne 0 ]; then
    echo "❌ 图片转换失败"
    exit 1
fi

echo "✅ 图片已转换为base64，长度: ${#IMG_BASE64} 字符"

# 选择请求方式
echo ""
echo "请选择请求方式:"
echo "1. 同步请求 (runsync) - 等待结果返回"
echo "2. 异步请求 (run) - 提交任务"
read -p "请输入选择 (1 或 2，默认为1): " choice

choice=${choice:-1}

if [ "$choice" = "2" ]; then
    echo "正在发送异步请求..."
    curl -X POST "${BASE_URL}/run" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "{
            \"input\": {
                \"image_base64\": \"${IMG_BASE64}\",
                \"prompt_type\": \"layout_parsing\"
            }
        }"
else
    echo "正在发送同步请求..."
    curl -X POST "${BASE_URL}/runsync" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "{
            \"input\": {
                \"image_base64\": \"${IMG_BASE64}\",
                \"prompt_type\": \"layout_parsing\"
            }
        }"
fi

echo ""
echo "✅ 请求完成！"
