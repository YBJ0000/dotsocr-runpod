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

# --- begin: robust DotsOCR init ---
import inspect

# 让 huggingface/transformers 优先命中你打包进镜像的权重目录
os.environ.setdefault("HF_HOME", "/weights")
os.environ.setdefault("TRANSFORMERS_CACHE", "/weights")

# 允许常见的环境变量别名
MODEL_DIR = (
    os.getenv("HF_MODEL_PATH")
    or os.getenv("MODEL_PATH")
    or os.getenv("hf_model_path")
    or "/weights/DotsOCR"
)

_PARSER = None

def _make_parser():
    # 优先用高阶 API（通常 README 推荐）
    try:
        from dots_ocr import DotsOCR
        logger.info("Using DotsOCR()")
        return DotsOCR()           # 不传任何路径参数
    except Exception as e1:
        logger.warning(f"DotsOCR() init failed: {e1}. Try DotsOCRParser...")

    # 退回到 Parser：只在确实有匹配参数时才传入 MODEL_DIR
    from dots_ocr import DotsOCRParser
    sig = inspect.signature(DotsOCRParser.__init__)
    logger.info(f"DotsOCRParser.__init__ signature: {sig}")

    # 根据README指示，设置use_hf=True来使用transformers
    init_kwargs = {"use_hf": True}
    
    for key in ("model_dir", "model_root", "pretrained_model_name_or_path", "weights_dir", "cache_dir"):
        if key in sig.parameters:
            logger.info(f"Initializing DotsOCRParser with {key}={MODEL_DIR}")
            init_kwargs[key] = MODEL_DIR
            break

    logger.info(f"Initializing DotsOCRParser with kwargs: {init_kwargs}")
    return DotsOCRParser(**init_kwargs)

def _get_parser():
    global _PARSER
    if _PARSER is None:
        _PARSER = _make_parser()
    return _PARSER
# --- end: robust DotsOCR init ---

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
            # 使用robust的初始化逻辑
            parser = _get_parser()
            logger.info("DotsOCR parser initialized successfully!")
            
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
                    result = parser.parse_file(temp_image_path, prompt_mode="prompt_layout_all_en")
                elif prompt_type == "layout_detection":
                    # 仅布局检测
                    result = parser.parse_file(temp_image_path, prompt_mode="prompt_layout_only_en")
                elif prompt_type == "text_only":
                    # 仅文本识别，排除页眉页脚
                    result = parser.parse_file(temp_image_path, prompt_mode="prompt_ocr")
                else:
                    # 默认使用布局解析
                    result = parser.parse_file(temp_image_path, prompt_mode="prompt_layout_all_en")
                
                # 添加详细的调试信息
                logger.info(f"Raw result type: {type(result)}")
                logger.info(f"Raw result: {result}")
                
                # 尝试不同的结果解析方法
                markdown_content = ""
                layout_data = []
                
                if isinstance(result, list) and len(result) > 0:
                    logger.info(f"Result is a list with {len(result)} items")
                    first_result = result[0]
                    logger.info(f"First result type: {type(first_result)}")
                    logger.info(f"First result: {first_result}")
                    
                    # 尝试不同的键名
                    if isinstance(first_result, dict):
                        # 尝试常见的键名
                        for key in ['markdown', 'markdown_content', 'content', 'text', 'result']:
                            if key in first_result:
                                markdown_content = first_result[key]
                                logger.info(f"Found markdown content in key '{key}': {len(str(markdown_content))} chars")
                                break
                        
                        # 尝试常见的布局键名
                        for key in ['layout', 'layout_data', 'data', 'elements', 'boxes']:
                            if key in first_result:
                                layout_data = first_result[key]
                                logger.info(f"Found layout data in key '{key}': {len(layout_data)} items")
                                break
                    else:
                        # 如果不是字典，直接转换为字符串
                        markdown_content = str(first_result)
                        logger.info(f"First result is not dict, converting to string: {len(markdown_content)} chars")
                elif isinstance(result, dict):
                    logger.info("Result is a dict")
                    # 尝试常见的键名
                    for key in ['markdown', 'markdown_content', 'content', 'text', 'result']:
                        if key in result:
                            markdown_content = result[key]
                            logger.info(f"Found markdown content in key '{key}': {len(str(markdown_content))} chars")
                            break
                    
                    for key in ['layout', 'layout_data', 'data', 'elements', 'boxes']:
                        if key in result:
                            layout_data = result[key]
                            logger.info(f"Found layout data in key '{key}': {len(layout_data)} items")
                            break
                else:
                    # 其他类型，直接转换为字符串
                    markdown_content = str(result)
                    logger.info(f"Result is other type, converting to string: {len(markdown_content)} chars")
                
                logger.info(f"Final markdown length: {len(markdown_content)}")
                logger.info(f"Final layout data items: {len(layout_data)}")
                
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