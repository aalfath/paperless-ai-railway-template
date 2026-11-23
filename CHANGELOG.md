# Changelog

## 4.5.1 (2026-11-23)

First release of the Railway template.

- Paperless-AI 4.5.1, official image `clusterzx/paperless-ai:4.5.1@sha256:770bce7654fcfa7e5611defea8ec70db3483f87da1a54d75ce418d6910ae7f30`.
- The admin account is created on the first boot from `ADMIN_USERNAME` / `ADMIN_PASSWORD`, so the setup wizard is never open to strangers.
- One OpenAI-compatible LLM connection from `LLM_API_KEY`, `LLM_BASE_URL` and `LLM_MODEL`.
- Under 900 MB of memory, OCR is locked off and "Ask your archive" uses keyword search (both need about 1 GB).
- Health check on `/health`; the start wrapper exits non-zero when the app stops on its own.
