import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from similarity_search import text_match_score


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
