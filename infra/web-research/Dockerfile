# syntax=docker/dockerfile:1
# Web-research backend image: pinned upstream source plus our auth + SSRF-guarded HTTP launcher.
FROM python:3.14-slim

COPY --from=ghcr.io/astral-sh/uv:0.12.1 /uv /uvx /bin/

WORKDIR /app

# Upstream install steps (from its Dockerfile), sourced from the pinned `upstream` build context.
COPY --from=upstream requirements.txt pyproject.toml ./
RUN uv pip install --system --no-cache -r requirements.txt

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN playwright install --with-deps chromium

COPY --from=upstream src/ ./src/
RUN uv pip install --system --no-cache --no-deps .

ENV SEARXNG_BASE_URL="http://searxng:8080/search" \
    SEARXNG_DEFAULT_CATEGORY="general" \
    SEARXNG_DEFAULT_RESULTS="5" \
    SEARXNG_MAX_RESULTS="10" \
    SEARXNG_CRAWL_MAX_CHARS="12000" \
    MCP_MAX_RESPONSE_CHARS="30000" \
    SEARXNG_MCP_USER_AGENT="web-research-assistant/0.4.0"

RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin wra \
    && mkdir -p /app/data \
    && chown -R wra:wra /ms-playwright /app/data

COPY serve_http.py test_serve_http.py /app/

USER wra

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8765/healthz', timeout=5).status == 200 else 1)"

CMD ["python", "/app/serve_http.py"]
