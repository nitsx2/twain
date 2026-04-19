"""Qubrid Whisper client.

Gotcha mirrored from Stryng Doctor: Qubrid's transcribe endpoint is
POST /audio/transcribe (singular). The OpenAI SDK's .audio.transcriptions.create()
hits /audio/transcriptions (plural) and returns 404 — so we use raw httpx here.
"""
from __future__ import annotations

import asyncio
import logging

import httpx

from app.config import get_settings

log = logging.getLogger("twain.qubrid")
_settings = get_settings()


class QubridClient:
    def __init__(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        whisper_model: str | None = None,
    ) -> None:
        key = api_key or _settings.qubrid_api_key
        if not key:
            raise RuntimeError("QUBRID_API_KEY is not set")
        self._api_key = key
        self._base_url = (base_url or _settings.qubrid_base_url).rstrip("/")
        self._model = whisper_model or _settings.qubrid_whisper_model

    async def transcribe(
        self,
        audio_bytes: bytes,
        *,
        filename: str = "audio.webm",
        mime_type: str = "audio/webm",
        language: str = "en",
    ) -> dict:
        url = f"{self._base_url}/audio/transcribe"
        headers = {"Authorization": f"Bearer {self._api_key}"}
        async with httpx.AsyncClient(timeout=180.0) as client:
            resp = await client.post(
                url,
                headers=headers,
                files={"file": (filename, audio_bytes, mime_type)},
                data={"model": self._model, "language": language},
            )
            if resp.status_code >= 400:
                log.error("Qubrid %s: %s", resp.status_code, resp.text[:500])
            resp.raise_for_status()
            return resp.json()


_singleton: QubridClient | None = None


def get_qubrid() -> QubridClient:
    global _singleton
    if _singleton is None:
        _singleton = QubridClient()
    return _singleton
