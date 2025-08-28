import runpod
import base64
import io
import os
import sys
from PIL import Image
import tempfile
import logging
import fitz  # PyMuPDF for PDF processing

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
                "image_base64": "base64_encoded_image_string",  # for images
                "pdf_base64": "base64_encoded_pdf_string",      # for PDFs
                "prompt_type": "layout_parsing"  # optional, defaults to layout_parsing
            }
        }
       
    Returns:
        dict: The result containing markdown and layout data
    """
    
    try:
        logger.info("Worker Start - DotsOCR Handler")
        input_data = event['input']
        
        # Get base64 data and determine input type
        image_base64 = input_data.get('image_base64')
        pdf_base64 = input_data.get('pdf_base64')
        prompt_type = input_data.get('prompt_type', 'layout_parsing')
        
        if not image_base64 and not pdf_base64:
            return {"error": "No image_base64 or pdf_base64 provided in input"}
        
        if image_base64 and pdf_base64:
            return {"error": "Both image_base64 and pdf_base64 provided. Please provide only one."}
        
        # Determine input type
        is_pdf = pdf_base64 is not None
        input_base64 = pdf_base64 if is_pdf else image_base64
        
        logger.info(f"Processing {'PDF' if is_pdf else 'image'} with prompt type: {prompt_type}")
        
        # Try to import and use dots.ocr
        try:
            # 使用robust的初始化逻辑
            parser = _get_parser()
            logger.info("DotsOCR parser initialized successfully!")
            
            if is_pdf:
                # Process PDF
                return process_pdf_with_dotsocr(parser, pdf_base64, prompt_type)
            else:
                # Process image
                return process_image_with_dotsocr(parser, image_base64, prompt_type)
                    
        except ImportError as e:
            logger.error(f"Failed to import DotsOCR: {e}")
            # Fallback to mock response
            logger.info("Falling back to mock response")
            if is_pdf:
                return {
                    "markdown": "# Mock PDF OCR Result\n\nDotsOCR import failed: {}\n\nInput type: PDF".format(str(e)),
                    "layout_data": [{"type": "text", "content": "Mock PDF content"}],
                    "status": "import_failed",
                    "error": str(e)
                }
            else:
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

def process_pdf_with_dotsocr(parser, pdf_base64, prompt_type):
    """Process PDF with DotsOCR and return markdown and layout data"""
    try:
        # Decode base64 PDF
        pdf_bytes = base64.b64decode(pdf_base64)
        pdf_stream = io.BytesIO(pdf_bytes)
        
        # Save PDF to temporary file for processing
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as tmp_file:
            tmp_file.write(pdf_bytes)
            temp_pdf_path = tmp_file.name
        
        try:
            # Process the PDF with DotsOCR
            logger.info("Processing PDF with DotsOCR...")
            
            # 根据README指示，使用正确的解析方法
            if prompt_type == "layout_parsing":
                # 解析所有布局信息，包括检测和识别
                result = parser.parse_file(temp_pdf_path, prompt_mode="prompt_layout_all_en")
            elif prompt_type == "layout_detection":
                # 仅布局检测
                result = parser.parse_file(temp_pdf_path, prompt_mode="prompt_layout_only_en")
            elif prompt_type == "text_only":
                # 仅文本识别，排除页眉页脚
                result = parser.parse_file(temp_pdf_path, prompt_mode="prompt_ocr")
            else:
                # 默认使用布局解析
                result = parser.parse_file(temp_pdf_path, prompt_mode="prompt_layout_all_en")
            
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
                
                # 根据日志发现，parse_file返回的是文件路径，不是直接内容
                if isinstance(first_result, dict):
                    # 检查是否有markdown文件路径
                    if 'md_content_path' in first_result:
                        md_file_path = first_result['md_content_path']
                        logger.info(f"Found markdown file path: {md_file_path}")
                        
                        # 读取markdown文件内容
                        try:
                            if os.path.exists(md_file_path):
                                with open(md_file_path, 'r', encoding='utf-8') as f:
                                    markdown_content = f.read()
                                logger.info(f"Successfully read markdown file: {len(markdown_content)} chars")
                            else:
                                logger.warning(f"Markdown file not found: {md_file_path}")
                        except Exception as e:
                            logger.error(f"Failed to read markdown file: {e}")
                    
                    # 检查是否有布局信息文件路径
                    if 'layout_info_path' in first_result:
                        layout_file_path = first_result['layout_info_path']
                        logger.info(f"Found layout info file path: {layout_file_path}")
                        
                        # 读取布局信息JSON文件
                        try:
                            if os.path.exists(layout_file_path):
                                import json
                                with open(layout_file_path, 'r', encoding='utf-8') as f:
                                    layout_data = json.load(f)
                                logger.info(f"Successfully read layout info file: {len(layout_data)} items")
                            else:
                                logger.warning(f"Layout info file not found: {layout_file_path}")
                        except Exception as e:
                            logger.error(f"Failed to read layout info file: {e}")
                    
                    # 如果没有文件路径，尝试其他键名（向后兼容）
                    if not markdown_content:
                        for key in ['markdown', 'markdown_content', 'content', 'text', 'result']:
                            if key in first_result:
                                markdown_content = first_result[key]
                                logger.info(f"Found markdown content in key '{key}': {len(str(markdown_content))} chars")
                                break
                    
                    if not layout_data:
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
                "status": "success",
                "input_type": "pdf"
            }
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_pdf_path):
                os.unlink(temp_pdf_path)
                
    except Exception as e:
        logger.error(f"Error processing PDF: {str(e)}")
        return {"error": f"PDF processing failed: {str(e)}"}

def process_image_with_dotsocr(parser, image_base64, prompt_type):
    """Process image with DotsOCR and return markdown and layout data"""
    try:
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
                
                # 根据日志发现，parse_file返回的是文件路径，不是直接内容
                if isinstance(first_result, dict):
                    # 检查是否有markdown文件路径
                    if 'md_content_path' in first_result:
                        md_file_path = first_result['md_content_path']
                        logger.info(f"Found markdown file path: {md_file_path}")
                        
                        # 读取markdown文件内容
                        try:
                            if os.path.exists(md_file_path):
                                with open(md_file_path, 'r', encoding='utf-8') as f:
                                    markdown_content = f.read()
                                logger.info(f"Successfully read markdown file: {len(markdown_content)} chars")
                            else:
                                logger.warning(f"Markdown file not found: {md_file_path}")
                        except Exception as e:
                            logger.error(f"Failed to read markdown file: {e}")
                    
                    # 检查是否有布局信息文件路径
                    if 'layout_info_path' in first_result:
                        layout_file_path = first_result['layout_info_path']
                        logger.info(f"Found layout info file path: {layout_file_path}")
                        
                        # 读取布局信息JSON文件
                        try:
                            if os.path.exists(layout_file_path):
                                import json
                                with open(layout_file_path, 'r', encoding='utf-8') as f:
                                    layout_data = json.load(f)
                                logger.info(f"Successfully read layout info file: {len(layout_data)} items")
                            else:
                                logger.warning(f"Layout info file not found: {layout_file_path}")
                        except Exception as e:
                            logger.error(f"Failed to read layout info file: {e}")
                    
                    # 如果没有文件路径，尝试其他键名（向后兼容）
                    if not markdown_content:
                        for key in ['markdown', 'markdown_content', 'content', 'text', 'result']:
                            if key in first_result:
                                markdown_content = first_result[key]
                                logger.info(f"Found markdown content in key '{key}': {len(str(markdown_content))} chars")
                                break
                    
                    if not layout_data:
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
                "status": "success",
                "input_type": "image"
            }
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_image_path):
                os.unlink(temp_image_path)
                
    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        return {"error": f"Image processing failed: {str(e)}"}

# Start the Serverless function when the script is run
if __name__ == '__main__':
    runpod.serverless.start({'handler': handler })