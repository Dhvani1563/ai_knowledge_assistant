"""Step 6: the LLM. One function, three interchangeable providers.

Switch with LLM_PROVIDER in .env — no code changes:
  gemini    -> google-genai SDK   (free tier available; best for ₹0 dev)
  openai    -> openai SDK         (paid)
  anthropic -> anthropic SDK      (paid)
Clients are created lazily so the API boots even if a key is missing.
"""
from tenacity import retry, stop_after_attempt, wait_exponential

from ..core.config import settings


class LLMError(Exception):
    """Raised when the model call fails; the route turns it into a clean 502."""


def generate_answer(system_prompt: str, user_prompt: str, max_tokens: int = 1024) -> str:
    provider = settings.llm_provider.lower().strip()
    try:
        if provider == "gemini":
            return _gemini(system_prompt, user_prompt, max_tokens)
        if provider == "openai":
            return _openai(system_prompt, user_prompt, max_tokens)
        if provider == "anthropic":
            return _anthropic(system_prompt, user_prompt, max_tokens)
    except Exception as exc:  # noqa: BLE001
        raise LLMError(f"{provider} request failed: {exc}") from exc
    raise LLMError(f"Unknown LLM_PROVIDER '{settings.llm_provider}'. Use gemini, openai or anthropic.")


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=8), reraise=True)
def _gemini(system: str, user: str, max_tokens: int) -> str:
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=settings.gemini_api_key)
    response = client.models.generate_content(
        model=settings.gemini_model,
        contents=user,
        config=types.GenerateContentConfig(
            system_instruction=system, max_output_tokens=max_tokens, temperature=0.2,
        ),
    )
    return (response.text or "").strip()


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=8), reraise=True)
def _openai(system: str, user: str, max_tokens: int) -> str:
    from openai import OpenAI

    client = OpenAI(api_key=settings.openai_api_key)
    response = client.chat.completions.create(
        model=settings.openai_model,
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
        max_completion_tokens=max_tokens,
        temperature=0.2,
    )
    return (response.choices[0].message.content or "").strip()


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=8), reraise=True)
def _anthropic(system: str, user: str, max_tokens: int) -> str:
    from anthropic import Anthropic

    client = Anthropic(api_key=settings.anthropic_api_key)
    response = client.messages.create(  # type: ignore[reportCallIssue]
        model=settings.anthropic_model, max_tokens=max_tokens, temperature=0.2,
        system=system, messages=[{"role": "user", "content": user}],
    )
    return "".join(b.text for b in response.content if b.type == "text").strip()
    messages=[{"role": "user", "content": user}],  # type: ignore[arg-type]
