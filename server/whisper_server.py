"""Local speech-to-text server for the Ledger app.

Run:  pip install fastapi uvicorn faster-whisper python-multipart
      python whisper_server.py
Listens on 0.0.0.0:8765 so an Android phone on the same LAN can reach it.
POST /transcribe  (multipart field "file") -> {"text": "..."}
"""
import os
import tempfile

import uvicorn
from fastapi import FastAPI, File, UploadFile
from faster_whisper import WhisperModel

MODEL_SIZE = os.environ.get("WHISPER_MODEL", "small")  # small / medium / large-v3
DEVICE = os.environ.get("WHISPER_DEVICE", "auto")      # auto / cuda / cpu

app = FastAPI()
model = WhisperModel(MODEL_SIZE, device=DEVICE)


@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    suffix = os.path.splitext(file.filename or "")[1] or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        path = tmp.name
    try:
        # Mandarin prompt nudges output toward Traditional Chinese.
        segments, _ = model.transcribe(
            path, language="zh", initial_prompt="以下是繁體中文的記帳語音。", vad_filter=True
        )
        text = "".join(s.text for s in segments).strip()
    finally:
        os.remove(path)
    return {"text": text}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8765)
