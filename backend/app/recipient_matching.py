import re
import unicodedata
from typing import Any


_RELATION_TERMS = {
    "father": (
        "father",
        "dad",
        "daddy",
        "papa",
        "baba",
        "abba",
        "abbu",
        "বাবা",
        "আব্বু",
        "আব্বা",
    ),
    "mother": (
        "mother",
        "mom",
        "mommy",
        "ma",
        "amma",
        "ammu",
        "মা",
        "আম্মু",
        "আম্মা",
    ),
    "son": ("son", "ছেলে", "পুত্র"),
    "daughter": ("daughter", "মেয়ে", "মেয়ে", "কন্যা"),
    "brother": ("brother", "ভাই"),
    "sister": ("sister", "বোন"),
}

def resolve_recipient(
    transcript: str,
    contacts: list[dict[str, Any]],
    ai_suggestion: str | None = None,
) -> tuple[str | None, str]:
    matches = {
        str(contact.get("recipient_uid") or "")
        for contact in contacts
        if contact.get("recipient_uid")
        and _contact_matches(transcript, contact)
    }
    matches.discard("")
    if len(matches) != 1:
        return None, "manual_selection"

    match_uid = next(iter(matches))
    if ai_suggestion and _suggested_contact_uid(ai_suggestion, contacts) != match_uid:
        return None, "manual_selection"
    return match_uid, "matched"


def _contact_matches(text: str, contact: dict[str, Any]) -> bool:
    normalized_text = _normalize(text)
    names = (
        contact.get("display_name"),
        contact.get("alias"),
        contact.get("relationship"),
    )
    for name in names:
        normalized_name = _normalize(str(name or ""))
        if normalized_name and _contains_term(normalized_text, normalized_name):
            return True

    roles = set()
    for name in names:
        normalized_name = _normalize(str(name or ""))
        roles.update(
            role
            for role, terms in _RELATION_TERMS.items()
            if any(_contains_term(normalized_name, term) for term in terms)
        )
    return any(
        _contains_term(normalized_text, term)
        for role in roles
        for term in _RELATION_TERMS[role]
    )


def _suggested_contact_uid(
    suggestion: str,
    contacts: list[dict[str, Any]],
) -> str | None:
    normalized = _normalize(suggestion)
    matches = {
        str(contact.get("recipient_uid") or "")
        for contact in contacts
        if contact.get("recipient_uid")
        and _contact_matches(normalized, contact)
    }
    matches.discard("")
    return next(iter(matches)) if len(matches) == 1 else None


def _contains_term(text: str, term: str) -> bool:
    if any("\u0980" <= character <= "\u09ff" for character in term):
        return (
            re.search(
                rf"(?<![\u0980-\u09ff]){re.escape(term)}"
                rf"(?:কে|র|এর)?(?![\u0980-\u09ff])",
                text,
            )
            is not None
        )
    return re.search(rf"(?<!\w){re.escape(term)}(?!\w)", text) is not None


def _normalize(value: str) -> str:
    return " ".join(
        unicodedata.normalize("NFKC", value).casefold().strip().split()
    )
