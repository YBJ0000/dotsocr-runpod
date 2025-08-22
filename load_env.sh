#!/bin/bash

# 环境变量加载脚本
# 使用方法：source ./load_env.sh 或 . ./load_env.sh

# 检查.env文件是否存在
if [ ! -f ".env" ]; then
    echo "❌ 错误：.env 文件不存在"
    echo "请先复制 env.example 为 .env 并填入正确的配置值"
    echo "命令：cp env.example .env"
    exit 1
fi

# 加载.env文件中的环境变量
echo "🔄 正在加载环境变量..."

# 读取.env文件并导出环境变量
while IFS= read -r line || [ -n "$line" ]; do
    # 跳过空行和注释行
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # 跳过不包含等号的行
    if [[ ! "$line" =~ = ]]; then
        continue
    fi
    
    # 导出环境变量
    export "$line"
    echo "✅ 已加载: ${line%%=*}"
done < .env

echo ""
echo "🎉 环境变量加载完成！"
echo "当前已加载的环境变量："
echo "  RUNPOD_API_KEY: ${RUNPOD_API_KEY:+已设置}"
echo "  RUNPOD_ENDPOINT_ID: ${RUNPOD_ENDPOINT_ID:+已设置}"
echo ""

# 验证必要的环境变量
if [ -z "$RUNPOD_API_KEY" ]; then
    echo "⚠️  警告：RUNPOD_API_KEY 未设置"
fi

if [ -z "$RUNPOD_ENDPOINT_ID" ]; then
    echo "⚠️  警告：RUNPOD_ENDPOINT_ID 未设置"
fi


