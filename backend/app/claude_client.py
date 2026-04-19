"""Claude client — streaming with extended thinking, effort tiers.

Mirrors the Stryng Doctor pattern: always stream, explicitly drain the event
loop before calling get_final_message(). The drain is required on anthropic-py
>= 0.45 because get_final_message() can hang on long Opus + extended-thinking
outputs without an explicit consumption pass.
"""
from __future__ import annotations

import asyncio
import json
import logging
import re
from typing import Any

import anthropic

from app.config import get_settings

log = logging.getLogger("twain.claude")
_settings = get_settings()

# Effort tier → extended-thinking budget_tokens.
# `low` (our default) disables thinking entirely to keep token cost minimal.
_THINKING_BUDGETS: dict[str, int] = {
    "low": 0,
    "medium": 4096,
    "high": 12288,
    "xhigh": 20480,
    "max": 32768,
}


class ClaudeClient:
    def __init__(
        self,
        *,
        api_key: str | None = None,
        model: str | None = None,
        effort: str | None = None,
    ) -> None:
        key = api_key or _settings.anthropic_api_key
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY is not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model or _settings.claude_chat_model
        self._effort = effort or _settings.claude_effort

    def _thinking_param(self) -> dict | None:
        budget = _THINKING_BUDGETS.get(self._effort, 0)
        if budget <= 0:
            return None
        return {"type": "enabled", "budget_tokens": budget}

    def _chat_sync(
        self,
        messages: list[dict[str, str]],
        *,
        system: str | None = None,
        max_tokens: int = 2048,
    ) -> str:
        kwargs: dict[str, Any] = {
            "model": self._model,
            "max_tokens": max_tokens,
            "messages": messages,
        }
        thinking = self._thinking_param()
        if thinking:
            kwargs["thinking"] = thinking
            kwargs["temperature"] = 1.0
            kwargs["max_tokens"] = max(
                max_tokens, thinking["budget_tokens"] + max_tokens
            )
        else:
            kwargs["temperature"] = 0.3

        if system:
            kwargs["system"] = [
                {
                    "type": "text",
                    "text": system,
                    "cache_control": {"type": "ephemeral"},
                }
            ]

        with self._client.messages.stream(**kwargs) as stream:
            for _ in stream:
                pass
            final = stream.get_final_message()

        parts: list[str] = []
        for block in final.content:
            if getattr(block, "type", None) == "text":
                parts.append(block.text)
        return "\n".join(parts).strip()

    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        system: str | None = None,
        max_tokens: int = 2048,
    ) -> str:
        """Run a chat completion in a worker thread and return the text."""
        return await asyncio.to_thread(
            self._chat_sync,
            messages,
            system=system,
            max_tokens=max_tokens,
        )

    async def chat_json(
        self,
        messages: list[dict[str, str]],
        *,
        system: str | None = None,
        max_tokens: int = 2048,
    ) -> dict:
        """Chat that returns a JSON object (parsed)."""
        text = await self.chat(
            messages, system=system, max_tokens=max_tokens
        )
        return _extract_json(text)


def _extract_json(text: str) -> dict:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError(f"No JSON object in Claude response: {text[:200]}")
    return json.loads(text[start : end + 1])


_singleton: ClaudeClient | None = None


def get_claude() -> ClaudeClient:
    global _singleton
    if _singleton is None:
        _singleton = ClaudeClient()
    return _singleton
