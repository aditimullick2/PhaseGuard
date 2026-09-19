# PhaseGuard Voice Cloning (Scambaiter) - Camber Server

This folder contains the Voice Cloning API for the Scambaiter feature of PhaseGuard.
It is designed to run on a Cloud GPU (like the NVIDIA L4 provided by Camber via the GitHub Student Developer Pack).

## How to run on Camber
1. Clone this repository onto your Camber GPU instance.
2. Navigate to this directory: `cd apps/camber_xtts_server`
3. Install the requirements (preferably in a virtual environment):
   ```bash
   pip install -r requirements.txt
   ```
4. Run the FastAPI server:
   ```bash
   python main.py
   ```
   *(Note: The first time you run this, it will download the XTTS-v2 model which is ~2-3 GB. It will take a few minutes).*

5. The server will run on `http://0.0.0.0:8000`. Camber will provide you with a public URL (e.g. `https://xxxx-camber.dev`).
6. **Send that URL back to us!** We will put it in the Flutter App/Backend to call the `/clone_voice` endpoint.

## API Endpoint Reference

**`POST /clone_voice`**

Accepts `multipart/form-data`:
- `text` (string): The text that you want the AI to speak.
- `reference_audio` (file): A short (3-10 sec) `.wav` or `.mp3` audio file of the User's voice.

**Response:**
Returns a `.wav` file of the synthesized audio in the exact cloned voice of the user.
