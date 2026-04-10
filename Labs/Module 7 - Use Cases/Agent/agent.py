# =============================================================================
# agent.py — Maintenance Assessment Agent
# Agent as a Service  |  Pentaho Academy
#
# Single endpoint: POST /assess
# Receives: log_id, asset_id, log_text, history (list of {logged_at, log_text})
# Returns:  priority, fault_type, pattern, assessment, confidence
#
# Run:
#   source agent-venv/bin/activate          # Linux / macOS
#   .\agent-venv\Scripts\Activate.ps1       # Windows PowerShell
#   uvicorn agent:app --host 0.0.0.0 --port 8000
# =============================================================================

import os
import json
import logging
import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ── Configuration ─────────────────────────────────────────────────────────────
MODEL_URL   = os.getenv("AGENT_MODEL_URL",   "http://localhost:11434/api/generate")
MODEL_NAME  = os.getenv("AGENT_MODEL_NAME",  "llama3.1:8b")
TEMPERATURE = float(os.getenv("AGENT_TEMPERATURE", "0.1"))
TIMEOUT     = int(os.getenv("AGENT_TIMEOUT",       "120"))
MAX_RETRIES = int(os.getenv("AGENT_MAX_RETRIES",   "2"))

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("maintenance-agent")

app = FastAPI(title="Maintenance Assessment Agent", version="1.0.0")


# ── Pydantic models ───────────────────────────────────────────────────────────
class HistoryEntry(BaseModel):
    logged_at: str
    log_text:  str

class AssessRequest(BaseModel):
    log_id:   str
    asset_id: str
    log_text: str
    history:  list[HistoryEntry]

class AssessResponse(BaseModel):
    log_id:     str
    asset_id:   str
    priority:   str   # CRITICAL | HIGH | MEDIUM | LOW
    fault_type: str   # descriptive snake_case label
    pattern:    str   # RECURRENCE | ESCALATION | NEW_FAULT | NORMAL_VARIATION
    assessment: str   # one-to-two sentence explanation
    confidence: int   # 0-100


# ── Prompt builder ────────────────────────────────────────────────────────────
def build_prompt(req: AssessRequest) -> str:
    """
    Build the assessment prompt.

    History is presented BEFORE the current entry, oldest first.

    Key prompt design decisions:
    - JSON schema uses concrete examples for fault_type to prevent the model
      returning the placeholder text literally.
    - pattern field specifies "exactly one of" to prevent pipe-separated
      multi-value responses.
    - Priority rules use ANY-condition CRITICAL with explicit numeric example.
    - HIGH rule includes explicit symptom-type equivalences.
    """
    if req.history:
        hist_lines = []
        for i, h in enumerate(req.history, 1):
            hist_lines.append(f"  {i}. [{h.logged_at}] {h.log_text}")
        history_block = (
            f"Prior history for {req.asset_id} (oldest first):\n"
            + "\n".join(hist_lines)
        )
    else:
        history_block = (
            f"Prior history for {req.asset_id}: "
            "none (first recorded entry for this asset)"
        )

    return f"""You are a maintenance engineer assistant.
Assess the current log entry for asset {req.asset_id} given its history.
Return ONLY valid JSON, no other text:
{{
  "priority":   "CRITICAL or HIGH or MEDIUM or LOW",
  "fault_type": "descriptive_snake_case_label (e.g. bearing_degradation, high_temperature_alarm, valve_sticking, normal_variation)",
  "pattern":    "exactly one of: RECURRENCE, ESCALATION, NEW_FAULT, NORMAL_VARIATION",
  "assessment": "one or two sentences explaining your reasoning",
  "confidence": 0-100
}}

Priority rules - check CRITICAL first, then HIGH, then MEDIUM, then LOW:
- CRITICAL: apply if ANY of these are true:
    * a numeric reading exceeds a stated limit (e.g. 94C when limit is 85C)
    * an alarm has been triggered
    * the engineer states the fault is getting worse during the current shift
- HIGH: apply if the current symptom is the same TYPE as any prior history entry,
    even if the exact wording differs. Use these equivalences:
    * vibration on startup = vibration under load = rumble = rougher than usual = same type
    * temperature high = temperature alarm = temperature drift = same type
    * sticking = binding = resistance = same type
    Apply HIGH especially when a repair or replacement appears in the history
    and the same symptom type is now returning.
- MEDIUM: novel symptom with no history entry of the same symptom type,
    requires investigation within 48 hours
- LOW: engineer explicitly states the observation is within normal range
    and no action is needed

Pattern rules - return exactly one value:
- RECURRENCE: the current symptom TYPE matches any prior history entry for this asset
- ESCALATION: the fault is worsening within the current shift
    (same day entries for the same asset, second entry is more severe)
- NEW_FAULT: no prior history entry of the same symptom type exists
- NORMAL_VARIATION: engineer explicitly states normal, no concern raised

{history_block}

Current entry [{req.asset_id}]: {req.log_text}"""


# ── LLM call ──────────────────────────────────────────────────────────────────
async def call_llm(prompt: str) -> str:
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        r = await client.post(MODEL_URL, json={
            "model":   MODEL_NAME,
            "prompt":  prompt,
            "stream":  False,
            "format":  "json",
            "options": {
                "temperature": TEMPERATURE,
                "num_predict": 300
            }
        })
        r.raise_for_status()
        return r.json()["response"]


def extract_json(text: str) -> dict:
    s = text.find("{")
    e = text.rfind("}") + 1
    if s < 0 or e <= s:
        raise ValueError(f"No JSON object found in response: {text[:150]!r}")
    return json.loads(text[s:e])


def sanitise_pattern(value: str) -> str:
    """
    Guard against the model returning pipe-separated values like
    'ESCALATION|NEW_FAULT'. Extract the first valid token.
    """
    valid = {"RECURRENCE", "ESCALATION", "NEW_FAULT", "NORMAL_VARIATION"}
    # Split on pipe, comma, or slash and take the first recognised value
    for token in value.replace(",", "|").replace("/", "|").split("|"):
        token = token.strip().upper()
        if token in valid:
            return token
    return "NEW_FAULT"


def sanitise_priority(value: str) -> str:
    """
    Guard against unexpected priority values.
    """
    valid = {"CRITICAL", "HIGH", "MEDIUM", "LOW"}
    v = value.strip().upper()
    return v if v in valid else "MEDIUM"


# ── Endpoints ─────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "model": MODEL_NAME}


@app.post("/assess", response_model=AssessResponse)
async def assess(req: AssessRequest):
    log.info(
        f"Assessing {req.log_id} for {req.asset_id} "
        f"({len(req.history)} history entries)"
    )

    prompt     = build_prompt(req)
    last_error = None

    for attempt in range(MAX_RETRIES + 1):
        try:
            raw  = await call_llm(prompt)
            data = extract_json(raw)

            priority   = sanitise_priority(str(data.get("priority",   "MEDIUM")))
            fault_type = str(data.get("fault_type", "unknown"))
            pattern    = sanitise_pattern(str(data.get("pattern",    "NEW_FAULT")))
            assessment = str(data.get("assessment", ""))
            confidence = int(data.get("confidence", 50))
            confidence = max(0, min(100, confidence))

            # Guard: if fault_type still contains the placeholder text,
            # replace it with a generic label so it is at least useful
            if "snake_case" in fault_type.lower() or "label" in fault_type.lower():
                fault_type = "unclassified_fault"

            return AssessResponse(
                log_id     = req.log_id,
                asset_id   = req.asset_id,
                priority   = priority,
                fault_type = fault_type,
                pattern    = pattern,
                assessment = assessment,
                confidence = confidence,
            )

        except (ValueError, KeyError, json.JSONDecodeError) as e:
            last_error = e
            log.warning(f"Attempt {attempt + 1} failed for {req.log_id}: {e}")
            # On retry prepend a stricter instruction
            prompt = (
                "You must return ONLY a raw JSON object. "
                "No markdown, no explanation, no code fences.\n\n"
                + build_prompt(req)
            )

        except httpx.HTTPError as e:
            log.error(f"LLM backend error for {req.log_id}: {e}")
            raise HTTPException(
                status_code=502,
                detail=f"LLM backend unavailable: {e}"
            )

    log.error(
        f"All {MAX_RETRIES + 1} attempts failed for {req.log_id}: {last_error}"
    )
    raise HTTPException(
        status_code=500,
        detail=f"Failed after {MAX_RETRIES + 1} attempts: {last_error}"
    )
