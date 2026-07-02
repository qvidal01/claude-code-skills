---
name: watsonx-vision-toolkit-dev
description: "Develop, test, lint, and run the watsonx-vision-toolkit Python package (vision document analysis, fraud detection, decision engines). TRIGGER WHEN: 'work on watsonx-vision-toolkit', 'run the watsonx-vision tests', 'add a fraud detection check to watsonx-vision', 'run the watsonx-vision CLI to classify a document', 'release a new version of watsonx-vision-toolkit'."
---

# Watsonx Vision Toolkit Dev

You are working on watsonx-vision-toolkit, a published Python package (PyPI: watsonx-vision-toolkit, current version 0.2.0) for vision-based document analysis using IBM Watsonx AI or Ollama. It provides document classification, information extraction, fraud detection, cross-validation, and a multi-criteria decision engine. Build backend is hatchling; the source package is watsonx_vision/.

Setup:
1. cd /aidata/projects/watsonx-vision-toolkit
2. Editable dev install with all providers and dev tools: `pip install -e ".[all,dev]"`. If PEP 668 blocks it on this host, add `--break-system-packages`. The `[all]` extra pulls in watsonx (langchain-ibm, ibm-watson-machine-learning), ollama (langchain-ollama), and cli (click). The `[dev]` extra adds pytest, pytest-cov, pytest-asyncio, ruff, mypy, black.

Testing (config lives in pyproject.toml [tool.pytest.ini_options], testpaths=tests, addopts='-v --tb=short'):
3. Run the full suite: `pytest`
4. With coverage: `pytest --cov=watsonx_vision --cov-report=html`
5. A single file, e.g.: `pytest tests/test_vision_llm.py`. Available test files: test_vision_llm.py, test_fraud_detector.py, test_cross_validator.py, test_decision_engine.py, test_cache.py, test_retry.py, test_async.py, test_cli.py, test_config_env.py, test_exceptions.py. Tests mock the LLM providers, so no live API keys are needed to run them.

Lint / format / type-check (all configured in pyproject.toml, line-length 100, target py39):
6. `ruff check watsonx_vision tests`
7. `black --check watsonx_vision tests` (drop --check to auto-format)
8. `mypy watsonx_vision`

CLI (entrypoint `watsonx-vision`, defined as watsonx_vision.cli:main). Real subcommands: classify, extract, validate, fraud, analyze, config. Examples:
9. `watsonx-vision config --show` and `watsonx-vision config --env` to inspect configuration and environment variables.
10. `watsonx-vision classify document.png`
11. `watsonx-vision extract passport.jpg --output json`
12. `watsonx-vision fraud invoice.png --provider ollama`
13. `watsonx-vision analyze image.png "your prompt"`

Provider configuration via environment variables (or pass directly in VisionLLMConfig):
- IBM Watsonx: WATSONX_APIKEY, WATSONX_URL (e.g. https://us-south.ml.cloud.ibm.com), WATSONX_PROJECT_ID
- Ollama (local): OLLAMA_URL (default http://localhost:11434)
Default Watsonx vision model is meta-llama/llama-4-maverick-17b-128e-instruct-fp8; a common Ollama vision model is llava:13b.

Runnable examples (no install path tricks needed after editable install) live in examples/: basic_classification.py, information_extraction.py, fraud_detection.py, cross_validation.py, environment_config.py, response_caching.py, retry_configuration.py, complete_workflow.py. Run with `python examples/basic_classification.py` (these expect a configured provider; use Ollama locally to avoid IBM Cloud costs).

Docs: mkdocs (mkdocs.yml present). Install docs extra `pip install -e ".[docs]"` then `mkdocs serve` (default port 8000) for live preview, or `mkdocs build`.

When making changes, follow this loop: edit code in watsonx_vision/, add or update the matching tests/test_*.py, then run `ruff check`, `black`, `mypy watsonx_vision`, and `pytest`. Success = pytest reports all tests passing, ruff and mypy report no errors, and black reports nothing to reformat. Bump the version in pyproject.toml and update CHANGELOG.md before any release/publish.

Do not invent commands or scripts. Use only the commands above, all of which are backed by pyproject.toml, the CLI, and the README.
