# =========================
# Role 1 – Prompt Decomposition Engine (Backend)
# =========================

import re
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional, Tuple


# ---------- Data ----------
@dataclass
class Step:
    id: int
    text: str
    source_span: Optional[str] = None


ALLOWED_VERBS = (
    "Define", "Compare", "Identify", "Outline", "Explain", "List", "Provide",
    "Summarize", "State", "Verify", "Extract", "Clarify", "Distinguish"
)


# ---------- Utilities ----------
def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip())


def starts_with_allowed_verb(step: str) -> bool:
    return any(step.startswith(v + " ") or step == v for v in ALLOWED_VERBS)


def extract_constraints(prompt: str) -> Dict[str, object]:
    p = prompt.lower()
    constraints: Dict[str, object] = {}

    if re.search(r"\barabic\b|بالعربي|باللغة العربية", p):
        constraints["language"] = "Arabic"
    if re.search(r"\benglish\b|باللغة الانجليزية", p):
        constraints["language"] = "English"

    if re.search(r"\bsimple|easy|بسيط", p):
        constraints["style"] = "simple"

    if re.search(r"\bbeginner|مبتدئ", p):
        constraints["audience"] = "beginner"

    return constraints


# ---------- Clause splitting ----------
def split_clauses(prompt: str) -> List[str]:
    """
    Conservative splitting: sentences + soft connectors
    """
    p = _norm(prompt)
    p = re.sub(r"[?!]+", ".", p)
    p = re.sub(r"\s*\.\s*", ". ", p)

    sentences = [s.strip() for s in p.split(".") if s.strip()]
    return sentences


# ---------- Atomic split ----------
def atomic_split(step: str) -> List[str]:
    """
    Ensures no orphan fragments.
    """
    step = _norm(step)

    if step.lower().startswith("define "):
        tail = step[len("Define "):]
        if " and " in tail.lower():
            parts = [p.strip() for p in re.split(r"\band\b", tail, flags=re.I)]
            return [f"Define {p}" for p in parts if p]
        return [step]

    return [step]


# ---------- Clause expansion (CORE LOGIC) ----------
def expand_clause(clause: str) -> List[str]:
    """
    Converts one clause into multiple reasoning steps.
    """
    c = _norm(clause)
    lc = c.lower()

    # 🔥 HIGH PRIORITY: explanatory + comparative (WHY + DIFFERENCE)
    if re.search(r"\bwhy\b", lc) and re.search(r"\bdiffer|difference|compare|contrast\b", lc):
        return [
            "Identify the primary phenomenon being explained",
            "Explain the underlying physical or causal mechanism",
            "Identify the secondary phenomenon used for comparison",
            "Explain how the mechanism changes in the secondary case",
            "Compare the two mechanisms and highlight key differences"
        ]

    # WHY questions (causal reasoning)
    if re.search(r"\bwhy\b", lc):
        return [
            "Identify the phenomenon in question",
            "Explain the underlying physical or causal mechanism",
            "Identify the key factors influencing the phenomenon",
            "Distinguish this explanation from common misconceptions"
        ]

    # Comparison
    if re.search(r"\bcompare\b|\bcontrast\b|\bdifference\b|\bvs\b", lc):
        entities = [e.strip() for e in re.split(r"\bvs\b|\band\b", c, flags=re.I) if e.strip()]
        if len(entities) >= 2:
            return [
                f"Define {entities[0]}",
                f"Define {entities[1]}",
                f"Compare {entities[0]} and {entities[1]} across key aspects"
            ]
        return [
            "Identify the items to be compared",
            "Define each item",
            "Compare the items across key aspects"
        ]

    # HOW TO
    if re.search(r"\bhow to\b", lc):
        goal = re.sub(r".*how to", "", c, flags=re.I).strip()
        return [
            f"Identify the goal: {goal}",
            "Outline the required steps in order",
            "Explain the purpose of each step",
            "Identify potential failure points or edge cases"
        ]

    # DEFINE
    if re.search(r"\bdefine\b|\bwhat is\b", lc):
        term = re.sub(r".*(define|what is)", "", c, flags=re.I).strip(" ?.")
        return [f"Define {term}"]

    # FALLBACK (still meaningful)
    return [
        f"Clarify the intent of the request: '{c}'",
        "Determine the scope and depth of explanation required"
    ]


# ---------- Core Decomposer ----------
def decompose_prompt_baseline(prompt: str) -> Dict[str, object]:
    prompt = _norm(prompt)
    if not prompt:
        return {"steps": [], "constraints": {}}

    constraints = extract_constraints(prompt)
    clauses = split_clauses(prompt)

    steps_text: List[Tuple[str, str]] = []

    for clause in clauses:
        expanded = expand_clause(clause)
        for st in expanded:
            for piece in atomic_split(st):
                steps_text.append((piece, clause))

    seen = set()
    final_steps: List[Step] = []
    sid = 1

    for text, span in steps_text:
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        final_steps.append(
            Step(id=sid, text=text, source_span=span)
        )
        sid += 1

    return {
        "steps": [asdict(s) for s in final_steps],
        "constraints": constraints
    }


# ---------- Quality ----------
def quality_score(prompt: str, steps: List[Dict[str, object]]) -> Dict[str, float]:
    if not steps:
        return {"score": 0.0, "atomicity": 0.0, "verb_rate": 0.0, "redundancy": 0.0}

    verb_ok = sum(1 for s in steps if starts_with_allowed_verb(s["text"]))
    verb_rate = verb_ok / len(steps)

    return {
        "score": round(verb_rate, 2),
        "atomicity": 1.0,
        "verb_rate": round(verb_rate, 2),
        "redundancy": 1.0
    }


# ---------- Backend Entry Point ----------
def decompose_prompt(prompt: str) -> Dict[str, object]:
    """
    Backend-safe wrapper.
    Called ONLY after prompt is ALLOW.
    """
    result = decompose_prompt_baseline(prompt)
    quality = quality_score(prompt, result["steps"])

    return {
        "steps": result["steps"],
        "constraints": result["constraints"],
        "quality": quality
    }
