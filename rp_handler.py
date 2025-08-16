import runpod
import base64
import io
import os
from PIL import Image
import tempfile
import logging

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
        
        # For now, return a mock response since dots.ocr is not installed yet
        logger.info("DotsOCR not yet installed - returning mock response")
        
        # Decode base64 image to validate input
        try:
            image_data = base64.b64decode(image_base64)
            image = Image.open(io.BytesIO(image_data))
            logger.info(f"Image loaded successfully, size: {image.size}")
        except Exception as e:
            logger.error(f"Failed to decode image: {e}")
            return {"error": f"Failed to decode image: {str(e)}"}
        
        # Return mock response for now
        return {
            "markdown": "# Mock OCR Result\n\nThis is a placeholder response while dots.ocr is being integrated.\n\nImage size: {}x{}".format(image.size[0], image.size[1]),
            "layout_data": [{"type": "text", "content": "Mock content"}],
            "status": "mock_response",
            "note": "dots.ocr integration in progress"
        }
                
    except Exception as e:
        logger.error(f"Error in handler: {str(e)}")
        return {"error": f"Processing failed: {str(e)}"} 

# Start the Serverless function when the script is run
if __name__ == '__main__':
    runpod.serverless.start({'handler': handler })