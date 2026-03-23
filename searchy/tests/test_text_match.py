def text_match_score(query: str, ocr_text: str) -> float:
    """Pure copy of text_match_score from similarity_search.py for testing without heavy deps."""
    if not ocr_text or not query:
        return 0.0

    query_lower = query.lower()
    ocr_lower = ocr_text.lower()

    if query_lower in ocr_lower:
        return 1.0

    query_words = set(query_lower.split())
    ocr_words = set(ocr_lower.split())

    if not query_words:
        return 0.0

    matches = len(query_words & ocr_words)
    return matches / len(query_words)


def test_exact_substring_match():
    assert text_match_score("invoice 2024", "Payment invoice 2024 received") == 1.0


def test_case_insensitive():
    assert text_match_score("HELLO", "hello world") == 1.0


def test_word_level_partial():
    # 1 of 2 query words match
    assert text_match_score("red car", "blue car") == 0.5


def test_no_match():
    assert text_match_score("sunset", "spreadsheet data") == 0.0


def test_empty_query():
    assert text_match_score("", "some text") == 0.0


def test_empty_ocr():
    assert text_match_score("hello", "") == 0.0


def test_both_empty():
    assert text_match_score("", "") == 0.0


def test_all_words_match():
    assert text_match_score("hello world", "world hello foo") == 1.0
