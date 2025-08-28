# DotsOCR RunPod Serverless Worker

Integrate the dots.ocr model into RunPod Serverless Worker to implement OCR processing of PDFs/images and markdown output.

## Project Structure

- `rp_handler.py` - Main processing logic
- `Dockerfile` - Container environment configuration
- `.github/workflows/docker-publish.yml` - GitHub Actions configuration, Docker Hub integration
- `test_local.sh` - Local testing script for images
- `test_pdf_local.sh` - Local testing script for PDFs
- `load_env.sh` - Environment variable loading script
- `.env` - Environment variables file (generate with `cp env.example .env`)
- `env.example` - Environment variables example file
- `.gitignore` - Ignore environment variables and system files
- `.dockerignore` - Ignore local virtual environment and irrelevant files

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

### 3. Execute Testing

Run the test script, passing in the image or PDF path:

```bash
# For images
./test_local.sh <image_path>
# For PDFs
./test_pdf_local.sh <pdf_path>
```

**Examples:**
```bash
# For images
./test_local.sh ./HeyJude.png
# For PDFs
./test_pdf_local.sh ./HeyJude.pdf
```

**Cold Start**: Due to RunPod's cold start mechanism, it's recommended to choose the async method for the first test, otherwise the terminal will wait indefinitely for results.

### 4. View Async Test Results

Use curl command to monitor async test status:
```bash
curl -X GET "https://api.runpod.ai/v2/${RUNPOD_ENDPOINT_ID}/status/{id}" \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -H "Content-Type: application/json"
```

> `RUNPOD_ENDPOINT_ID` and `RUNPOD_API_KEY` are configured in the `.env` file, so you need to execute `source ./load_env.sh` first.

`{id}` can be found in the JSON returned after the async request completes, for example:
```json
{
    "id": "97dcf8ec-647f-49f9-aeb4-6d75c2ee79d4-e2",
    "status": "IN_PROGRESS"
}
```

## Troubleshooting

### Environment Variables Not Set
If you encounter errors about environment variables not being set, please check:
1. Whether you correctly copied `env.example` to `.env`
2. Whether you filled in correct values in the `.env` file
3. Whether you executed `source ./load_env.sh`

### Permission Issues
Ensure test scripts have execution permissions:
```bash
chmod +x load_env.sh
chmod +x test_local.sh
chmod +x test_pdf_local.sh
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
