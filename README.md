# DotsOCR RunPod Serverless Worker

将 dots.ocr 模型集成到 RunPod Serverless Worker 中，实现 PDF/图片的 OCR 处理和 markdown 输出。

## 项目结构

- `rp_handler.py` - 主要处理逻辑
- `Dockerfile` - 容器环境配置
- `.github/workflows/docker-publish.yml` - GitHub Actions 配置、Docker Hub 集成
- `test_local.sh` - 本地测试脚本
- `load_env.sh` - 环境变量加载脚本

## 部署流程

本项目使用 GitHub Actions 自动构建和部署：

1. 推送代码到 GitHub
2. GitHub Actions 自动构建 Docker 镜像
3. 推送到 Docker Hub
4. RunPod 从 Docker Hub 导入镜像

## 本地测试

### 1. 环境配置

首先复制环境变量示例文件并填入真实配置：

```bash
cp env.example .env
```

编辑 `.env` 文件，填入以下配置：

```bash
# RunPod API Key
RUNPOD_API_KEY=your_runpod_api_key_here

# RunPod Endpoint ID  
RUNPOD_ENDPOINT_ID=your_endpoint_id_here

# 可选：RunPod API 基础URL
RUNPOD_BASE_URL=https://api.runpod.ai/v2
```

**获取配置值：**
- **API Key**: 访问 [RunPod Console Settings](https://runpod.io/console/user/settings) 获取
- **Endpoint ID**: 从你的 RunPod Serverless 端点获取

### 2. 加载环境变量

使用以下命令加载环境变量到当前 shell：

```bash
source ./load_env.sh
```

或者使用简写形式：

```bash
. ./load_env.sh
```

### 3. 执行测试

运行测试脚本，传入图片路径：

```bash
./test_local.sh <image_path>
```

**示例：**
```bash
./test_local.sh ./HeyJude.png
```

## 测试策略

### 第一次测试（冷启动）

由于 RunPod 的冷启动机制，建议按以下顺序测试：

1. **先发送异步请求** - 选择选项 2，提交任务到队列
2. **等待异步任务完成** - 在 [RunPod Console](https://console.runpod.io/serverless/user/endpoint/{endpoint_id}?tab=requests) 查看任务状态
3. **再发送同步请求** - 选择选项 1，直接等待结果返回

### 异步请求监控

异步请求的状态可以在 RunPod Console 中查看：
```
https://console.runpod.io/serverless/user/endpoint/{endpoint_id}?tab=requests
```

将 `{endpoint_id}` 替换为你的实际 endpoint ID。

## 请求类型

### 同步请求 (runsync)
- 等待结果直接返回
- 适合小图片和快速处理
- 有超时限制

### 异步请求 (run)
- 提交任务到队列
- 适合大图片和复杂处理
- 可以在 Console 中监控状态

## 故障排除

### 环境变量未设置
如果遇到环境变量未设置的错误，请检查：
1. 是否正确复制了 `env.example` 到 `.env`
2. 是否在 `.env` 文件中填入了正确的值
3. 是否执行了 `source ./load_env.sh`

### 权限问题
确保测试脚本有执行权限：
```bash
chmod +x test_local.sh
chmod +x load_env.sh
```

### API 错误
- 检查 API Key 是否正确
- 检查 Endpoint ID 是否存在
- 确认 RunPod 端点是否正常运行

## 注意事项

- `.env` 文件包含敏感信息，已添加到 `.gitignore`，不会被提交到版本控制
- 首次部署到 RunPod 可能需要几分钟时间
- 冷启动后，后续请求会更快
- 建议先用小图片测试，确认配置正确后再处理大文件
