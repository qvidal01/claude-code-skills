---
name: qrcode-api
description: "Start the QR Builder FastAPI server at ~/projects/qrcode \u2014 QR generation, image embedding, batch processing, and restyle (change appearance while preserving data). TRIGGER WHEN: 'start the QR builder API', 'run the qrcode server', 'work on the QR builder', 'generate or embed a QR code via the API'. DO NOT USE WHEN: running the QR Builder test suite (use qrcode-test) or doing generic QR work outside this repo."
---

# Qrcode Api

Start the QR Builder API server located at ~/projects/qrcode. This is a FastAPI service for QR code generation and image embedding.

Steps:
1. Navigate to ~/projects/qrcode
2. Check if server is already running on port 8000
3. Activate virtual environment: source .venv/bin/activate
4. Start API server: qr-builder-api (or uvicorn qr_builder.api:app --reload)
5. Confirm server started
6. Show API documentation URL: http://localhost:8000/docs

Available endpoints:
- GET /health - Health check
- POST /qr - Generate standalone QR code (returns PNG)
- POST /embed - Embed QR into uploaded image (returns PNG)
- POST /batch/embed - Batch process multiple images (returns ZIP)
- POST /qr/restyle - Restyle QR with new appearance while preserving data

Key features:
- QR code generation with custom colors and sizes
- Embed QR codes into images at various positions
- Restyle existing QR codes (change colors/style without changing data)
- Batch processing for multiple images
