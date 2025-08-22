# DotsOCR RunPod Serverless Worker

Integrate the dots.ocr model into RunPod Serverless Worker to implement OCR processing of PDFs/images and markdown output.

## Project Structure

- `rp_handler.py` - Main processing logic
- `Dockerfile` - Container environment configuration
- `.github/workflows/docker-publish.yml` - GitHub Actions configuration, Docker Hub integration
- `test_local.sh` - Local testing script
- `load_env.sh` - Environment variable loading script

## Deployment Process

This project uses GitHub Actions for automated building and deployment:

1. Push code to GitHub
2. GitHub Actions automatically builds Docker image
3. Push to Docker Hub
4. RunPod imports image from Docker Hub

## Local Testing

### 1. Environment Configuration

First, copy the environment variable example file and fill in the real configuration:

```bash
cp env.example .env
```

Edit the `.env` file and fill in the following configuration:

```bash
# RunPod API Key
RUNPOD_API_KEY=your_runpod_api_key_here

# RunPod Endpoint ID  
RUNPOD_ENDPOINT_ID=your_endpoint_id_here

# Optional: RunPod API Base URL
RUNPOD_BASE_URL=https://api.runpod.ai/v2
```

**Get Configuration Values:**
- **API Key**: Visit [RunPod Console Settings](https://runpod.io/console/user/settings) to obtain
- **Endpoint ID**: Get from your RunPod Serverless endpoint

### 2. Load Environment Variables

Use the following command to load environment variables into the current shell:

```bash
source ./load_env.sh
```

Or use the shorthand form:

```bash
. ./load_env.sh
```

### 3. Execute Testing

Run the test script, passing in the image path:

```bash
./test_local.sh <image_path>
```

**Example:**
```bash
./test_local.sh ./HeyJude.png
```

## Testing Strategy

### First Test (Cold Start)

Due to RunPod's cold start mechanism, it's recommended to test in the following order:

1. **Send Async Request First** - Choose option 2, submit task to queue
2. **Wait for Async Task Completion** - Check task status in [RunPod Console](https://console.runpod.io/serverless/user/endpoint/{endpoint_id}?tab=requests)
3. **Then Send Sync Request** - Choose option 1, wait for result to return directly

### Async Request Monitoring

Async request status can be viewed in RunPod Console:
```
https://console.runpod.io/serverless/user/endpoint/{endpoint_id}?tab=requests
```

Replace `{endpoint_id}` with your actual endpoint ID.

## Request Types

### Sync Request (runsync)
- Wait for result to return directly
- Suitable for small images and fast processing
- Has timeout limits

### Async Request (run)
- Submit task to queue
- Suitable for large images and complex processing
- Can monitor status in Console

## Troubleshooting

### Environment Variables Not Set
If you encounter errors about environment variables not being set, please check:
1. Whether you correctly copied `env.example` to `.env`
2. Whether you filled in correct values in the `.env` file
3. Whether you executed `source ./load_env.sh`

### Permission Issues
Ensure test scripts have execution permissions:
```bash
chmod +x test_local.sh
chmod +x load_env.sh
```

### API Errors
- Check if API Key is correct
- Check if Endpoint ID exists
- Confirm if RunPod endpoint is running normally

## Notes

- `.env` file contains sensitive information and has been added to `.gitignore`, won't be committed to version control
- First deployment to RunPod may take several minutes
- After cold start, subsequent requests will be faster
- It's recommended to test with small images first, confirm configuration is correct before processing large files
