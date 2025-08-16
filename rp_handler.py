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
        
        # Import DotsOCR here to avoid loading model during container startup
        try:
            from dots_ocr import DotsOCRParser
        except ImportError as e:
            logger.error(f"Failed to import DotsOCRParser: {e}")
            return {"error": "DotsOCR library not available"}
        
        # Initialize the parser
        logger.info("Initializing DotsOCR parser...")
        parser = DotsOCRParser()
        
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
            result = parser.parse(temp_image_path, prompt_type=prompt_type)
            
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
                
    except Exception as e:
        logger.error(f"Error in handler: {str(e)}")
        return {"error": f"Processing failed: {str(e)}"} 

# Start the Serverless function when the script is run
if __name__ == '__main__':
    runpod.serverless.start({'handler': handler })