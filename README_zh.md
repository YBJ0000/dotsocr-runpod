# DotsOCR RunPod Serverless Worker

将 dots.ocr 模型集成到 RunPod Serverless Worker 中，实现 PDF/图片的 OCR 处理和 markdown 输出。

## 项目结构

- `rp_handler.py` - 主要处理逻辑
- `Dockerfile` - 容器环境配置
- `.github/workflows/docker-publish.yml` - GitHub Actions 配置、Docker Hub 集成
- `test_local.sh` - 本地测试图片脚本
- `test_pdf_local.sh` - 本地测试PDF脚本
- `load_env.sh` - 环境变量加载脚本
- `.env` - 环境变量文件(可用 `cp env.example .env` 生成)
- `env.example` - 环境变量示例文件
- `.gitignore` - 忽略环境变量和系统文件
- `.dockerignore` - 忽略本地虚拟环境和无关文件


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

### 3. 执行测试

运行测试脚本，传入图片或者 PDF 路径：

```bash
# 图片
./test_local.sh <image_path>
# PDF
./test_pdf_local.sh <pdf_path>
```

**示例：**
```bash
# 图片
./test_local.sh ./HeyJude.png
# PDF
./test_pdf_local.sh ./HeyJude.pdf
```

**冷启动**：因为 RunPod 的冷启动机制，首次测试建议选择异步方法，否则终端会一直等待结果。

### 4. 查看异步测试结果

使用 curl 命令监控异步测试状态：
```bash
curl -X GET "https://api.runpod.ai/v2/${RUNPOD_ENDPOINT_ID}/status/{id}" \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -H "Content-Type: application/json"
```

> `RUNPOD_ENDPOINT_ID` 和 `RUNPOD_API_KEY` 在 `.env` 文件中配置，所以要先执行`source ./load_env.sh`才行。

`{id}` 在异步请求结束返回的 JSON 中可以找到，例如：
```json
{
    "id": "97dcf8ec-647f-49f9-aeb4-6d75c2ee79d4-e2",
    "status": "IN_PROGRESS"
}
```

## 故障排除

### 环境变量未设置
如果遇到环境变量未设置的错误，请检查：
1. 是否正确复制了 `env.example` 到 `.env`
2. 是否在 `.env` 文件中填入了正确的值
3. 是否执行了 `source ./load_env.sh`

### 权限问题
确保测试脚本有执行权限：
```bash
chmod +x load_env.sh
chmod +x test_local.sh
chmod +x test_pdf_local.sh
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
