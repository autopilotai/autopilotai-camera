from typing import Union

from fastapi import FastAPI
from arlo import Arlo
import base64
import logging
import tempfile
import os

USERNAME = os.getenv('ARLO_USERNAME')
PASSWORD = os.getenv('ARLO_PASSWORD')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

@app.get("/")
def read_root():
    return {"AutopilotAI": "Camera"}

@app.get("/snapshot/{device_id}")
def get_snapshot(device_id:int):
    try:
        logger.info("Starting snapshot process")
        # Instantiating the Arlo object automatically calls Login(), which returns an oAuth token that gets cached.
        # Subsequent successful calls to login will update the oAuth token.
        arlo = Arlo(USERNAME, PASSWORD, '/app/config/gmail.credentials')
        # Get the list of devices and filter on device type to only get the basestation.
        # This will return an array which includes all of the basestation's associated metadata.
        basestations = arlo.GetDevices('basestation')
        # Get the list of devices and filter on device type to only get the cameras.
        # This will return an array of cameras, including all of the cameras' associated metadata.
        cameras = arlo.GetDevices('camera')
        # Trigger the snapshot.
        url = arlo.TriggerFullFrameSnapshot(basestations[0], cameras[device_id]);
        logger.info(f"Snapshot URL: {url}")
        # Download snapshot.
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
            snapshot_path = temp_file.name
            arlo.DownloadSnapshot(url, snapshot_path)
        with open(snapshot_path, "rb") as image_file:
            encoded_string = base64.b64encode(image_file.read())
        logger.info("Snapshot process completed successfully")
        return {"image": encoded_string}
    except Exception as e:
        logger.error(f"Error during snapshot process: {e}")
        return {"error": str(e)}