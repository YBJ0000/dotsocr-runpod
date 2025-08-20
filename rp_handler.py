import runpod
import base64
import io
import os
import sys
from PIL import Image
import tempfile
import logging

# 根据README指示设置正确的Python路径
# 1. 添加模型权重目录到Python路径（目录名不要带点）
weights_dir = os.getenv("hf_model_path", "/weights/DotsOCR")
if weights_dir not in sys.path:
    sys.path.insert(0, weights_dir)

# 2. 添加源码目录到Python路径
src_dir = "/opt/dots_ocr_src"
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def handler(event):
    """
    This function processes incoming requests to your Serverless endpoint.
    
    Args:
        event (dict): Contains the input data and request metadata
        Expected input format:
        {
            "input": {
                "image_base64": "base64_encoded_image_string",
                "prompt_type": "layout_parsing"  # optional, defaults to layout_parsing
            }
        }
       
    Returns:
        dict: The result containing markdown and layout data
    """
    
    try:
        logger.info("Worker Start - DotsOCR Handler")
        input_data = event['input']
        
        # Get base64 image data
        image_base64 = input_data.get('image_base64')
        prompt_type = input_data.get('prompt_type', 'layout_parsing')
        
        if not image_base64:
            return {"error": "No image_base64 provided in input"}
        
        logger.info(f"Processing image with prompt type: {prompt_type}")
        
        # Try to import and use dots.ocr
        try:
            # 根据README指示，使用正确的导入方式
            from dots_ocr import DotsOCRParser
            logger.info("DotsOCRParser imported successfully!")
            
            # Get model path from environment variable
            hf_model_path = os.getenv("hf_model_path", "/weights/DotsOCR")
            logger.info(f"Using model path: {hf_model_path}")
            
            # Initialize the parser with model path
            logger.info("Initializing DotsOCR parser...")
            parser = DotsOCRParser(model_path=hf_model_path)
            
            # Decode base64 image
            try:
                image_data = base64.b64decode(image_base64)
                image = Image.open(io.BytesIO(image_data))
                logger.info(f"Image loaded successfully, size: {image.size}")
            except Exception as e:
                logger.error(f"Failed to decode image: {e}")
                return {"error": f"Failed to decode image: {str(e)}"}
            
            # Save image to temporary file for processing
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp_file:
                image.save(tmp_file.name, 'PNG')
                temp_image_path = tmp_file.name
            
            try:
                # Process the image with DotsOCR
                logger.info("Processing image with DotsOCR...")
                
                # 根据README指示，使用正确的解析方法
                if prompt_type == "layout_parsing":
                    # 解析所有布局信息，包括检测和识别
                    result = parser.parse(temp_image_path)
                elif prompt_type == "layout_detection":
                    # 仅布局检测
                    result = parser.parse(temp_image_path, prompt="prompt_layout_only_en")
                elif prompt_type == "text_only":
                    # 仅文本识别，排除页眉页脚
                    result = parser.parse(temp_image_path, prompt="prompt_ocr")
                else:
                    # 默认使用布局解析
                    result = parser.parse(temp_image_path)
                
                # Extract results
                markdown_content = result.get('markdown', '')
                layout_data = result.get('layout', [])
                
                logger.info(f"Processing completed. Markdown length: {len(markdown_content)}")
                
                return {
                    "markdown": markdown_content,
                    "layout_data": layout_data,
                    "status": "success"
                }
                
            finally:
                # Clean up temporary file
                if os.path.exists(temp_image_path):
                    os.unlink(temp_image_path)
                    
        except ImportError as e:
            logger.error(f"Failed to import DotsOCR: {e}")
            # Fallback to mock response
            logger.info("Falling back to mock response")
            image_data = base64.b64decode(image_base64)
            image = Image.open(io.BytesIO(image_data))
            return {
                "markdown": "# Mock OCR Result\n\nDotsOCR import failed: {}\n\nImage size: {}x{}".format(str(e), image.size[0], image.size[1]),
                "layout_data": [{"type": "text", "content": "Mock content"}],
                "status": "import_failed",
                "error": str(e)
            }
                
    except Exception as e:
        logger.error(f"Error in handler: {str(e)}")
        return {"error": f"Processing failed: {str(e)}"} 

# Start the Serverless function when the script is run
if __name__ == '__main__':
    runpod.serverless.start({'handler': handler })