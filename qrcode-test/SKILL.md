---
name: qrcode-test
description: "Run the QR Builder pytest suite with coverage at ~/projects/qrcode (core generation, image embedding, restyle, API endpoints, validation; target 90%+). TRIGGER WHEN: 'run the qrcode tests', 'test the QR builder', 'check QR builder coverage'. DO NOT USE WHEN: starting the QR Builder API server (use qrcode-api)."
---

# Qrcode Test

Run tests for the QR Builder project located at ~/projects/qrcode.

Steps:
1. Navigate to ~/projects/qrcode
2. Activate virtual environment: source .venv/bin/activate
3. Run tests with coverage: pytest --cov=qr_builder --cov-report=term-missing
4. Show test summary and coverage report
5. Highlight any failing tests or areas with low coverage

Test coverage includes:
- Core QR generation functions
- Image embedding with position calculations
- QR restyle functionality with data preservation
- API endpoints (health, qr, embed, batch, restyle)
- Input validation and error handling

Target coverage: 90%+ for core functionality
