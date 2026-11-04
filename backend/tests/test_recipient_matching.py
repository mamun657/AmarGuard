import pytest

from app.recipient_matching import resolve_recipient


CONTACTS = [
    {
        "recipient_uid": "father-uid",
        "display_name": "father",
        "alias": "Abbu",
        "relationship": "parent",
    },
    {
        "recipient_uid": "son-uid",
        "display_name": "Son",
        "alias": "",
        "relationship": "child",
    },
    {
        "recipient_uid": "mother-uid",
        "display_name": "mother",
        "alias": "",
        "relationship": "parent",
    },
]


@pytest.mark.parametrize(
    ("text", "expected_uid"),
    [
        ("আমার বাবা হারিয়ে গেছি", "father-uid"),
        ("আব্বু আমাকে সাহায্য করো", "father-uid"),
        ("Please contact my father", "father-uid"),
        ("আমার মা যেন আমাকে ফোন করেন", "mother-uid"),
        ("আম্মু আমাকে সাহায্য করো", "mother-uid"),
        ("Please contact my mother", "mother-uid"),
        ("আমার ছেলে যেন আমাকে ফোন করে", "son-uid"),
        ("Please ask my son to call", "son-uid"),
    ],
)
def test_bangla_and_english_relationship_phrases_match_saved_contacts(
    text: str,
    expected_uid: str,
):
    uid, status = resolve_recipient(text, CONTACTS)
    assert uid == expected_uid
    assert status == "matched"


def test_ai_suggestion_cannot_override_a_conflicting_spoken_recipient():
    uid, status = resolve_recipient(
        "Please ask my son to call",
        CONTACTS,
        ai_suggestion="father",
    )
    assert uid is None
    assert status == "manual_selection"


def test_ambiguous_relationship_requires_manual_selection():
    contacts = CONTACTS + [
        {
            "recipient_uid": "second-father-uid",
            "display_name": "Abba",
            "alias": "",
            "relationship": "parent",
        }
    ]
    uid, status = resolve_recipient("আমার বাবা", contacts)
    assert uid is None
    assert status == "manual_selection"


@pytest.mark.parametrize("text", ["আমাকে সাহায্য করুন", "Call my family"])
def test_missing_recipient_requires_manual_selection(text: str):
    uid, status = resolve_recipient(text, CONTACTS, ai_suggestion="father")
    assert uid is None
    assert status == "manual_selection"


def test_contact_name_or_saved_alias_resolves_to_real_uid():
    uid, status = resolve_recipient("Abbu, please help", CONTACTS)
    assert uid == "father-uid"
    assert status == "matched"
