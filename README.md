[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/paperless-ai?utm_medium=integration&utm_source=button&utm_campaign=paperless-ai)

# Paperless-AI on Railway

One-click [Paperless-AI](https://github.com/clusterzx/paperless-ai) **4.5.1** for [Railway](https://railway.com). Paperless-AI reads your documents and fills in title, tags, correspondent, document type and date with an LLM. It also answers questions about your whole archive ("Ask your archive"), citing its sources. It works as a companion to an existing [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) or on its own with its built-in archive.

## What the template deploys

| Service | What it does | State |
|---|---|---|
| **Paperless-AI** (public) | Web interface, REST API, Paperless-ngx compatible API, MCP server for AI agents (`/mcp`), document processing and "Ask your archive" | Railway volume at `/app/data` (SQLite database, settings, search index, built-in archive files, downloaded models) |

- It's built from this repo: the [`Dockerfile`](Dockerfile) pins the official image `clusterzx/paperless-ai:4.5.1` by digest and adds a small start wrapper in [`railway/`](railway/).
- Health check: `GET /health`. Restart policy: on failure. The wrapper exits non-zero if the app stops on its own, so Railway restarts it.
- Behind Railway's proxy: `TRUST_PROXY=1` (real client IPs for the login rate limit, secure cookies).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `LLM_API_KEY` | *(you enter it)* | The only prompt. An API key for OpenAI or any OpenAI-compatible provider (OpenRouter, DeepSeek, Groq, LiteLLM …). |
| `LLM_BASE_URL` | `https://api.openai.com/v1` | Base URL of the OpenAI-compatible API. |
| `LLM_MODEL` | `gpt-5-mini` | Chat model used for analysis and answers. |
| `ADMIN_USERNAME` | `admin` | Admin account created on the first boot. |
| `ADMIN_PASSWORD` | generated (`secret(24)`) | Password of that account. It's only read on the first boot; change it later in the web interface. |
| `PORT` | `8080` | Port the app listens on (the public domain targets it). |

The LLM variables are passed to Paperless-AI as its "OpenAI-compatible (custom)" provider. Values set by environment variables are locked in the web interface; to use Anthropic, Azure or Ollama instead, delete `LLM_API_KEY` and pick the provider in the settings.

## After deploying

1. Open the service's Railway URL and sign in as `admin` with the `ADMIN_PASSWORD` shown in the service's **Variables** tab.
2. The setup wizard asks where your documents live:
   - **Paperless-ngx:** enter its URL (for a Paperless-ngx on Railway, its public `https://…` URL or `http://<service>.railway.internal:8000`) and the API token of a dedicated user that may *view* and *change* documents, tags, correspondents, document types and custom fields (Paperless-ngx → *Profile → API Auth Token*).
   - **Built-in archive:** upload documents in the browser, or use WebDAV, e-mail or the Paperless-ngx mobile apps.
3. Optional, for instant processing: in Paperless-ngx add a workflow with trigger *Document Added* and a *Webhook* action to `https://YOUR-DOMAIN/api/webhook/document` (body parameter `url` = `{doc_url}`, header `x-api-key` = the key from *Settings → API & webhooks*). Without it, new documents are picked up by the scan every 30 minutes.

## Memory

The app itself needs about 120 MB. Two optional features run ONNX models on the CPU and need more:

- **OCR** of scans without a text layer (PaddleOCR): about 600 MB.
- **Local embeddings** for "Ask your archive" (`multilingual-e5-small`, downloaded once to the volume): about 550 MB while indexing.

When the service has less than 900 MB of memory (for example on Railway's Free or Trial plan, 0.5 GB), the start script locks OCR off and makes "Ask your archive" use keyword search, so the app isn't killed on the first document. To use either feature, raise the service's memory limit to **1 GB or more** and redeploy; both unlock on their own. On any plan you can instead set `RAG_EMBEDDING_PROVIDER=custom` to use your LLM provider's embeddings API (`text-embedding-3-small` by default).

## MCP server for AI agents

Create a key in *Settings → API keys* (for example "AI agent, reading") and add the server to your client:

```json
{
  "mcpServers": {
    "paperless-ai": {
      "type": "http",
      "url": "https://YOUR-DOMAIN/mcp",
      "headers": { "Authorization": "Bearer pai_…" }
    }
  }
}
```

## Updates

Railway tells you when this repo's `main` branch changes. Each update bumps the pinned upstream image and is described in [`CHANGELOG.md`](CHANGELOG.md), breaking changes first. Applying it rebuilds the image; the volume (accounts, settings, documents, index) is kept.

## Licence

Paperless-AI is MIT-licensed by clusterzx. This wrapper is MIT-licensed too.
