import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from generate_embeddings import matches_filter


def test_all_filter():
    assert matches_filter("photo.jpg", "all", "anything") is True


def test_no_filter_value():
    assert matches_filter("photo.jpg", "starts-with", "") is True
    assert matches_filter("photo.jpg", "contains", None) is True


def test_starts_with():
    assert matches_filter("IMG_001.jpg", "starts-with", "IMG") is True
    assert matches_filter("IMG_001.jpg", "starts-with", "img") is True  # case insensitive
    assert matches_filter("photo.jpg", "starts-with", "IMG") is False


def test_ends_with():
    assert matches_filter("photo.png", "ends-with", ".png") is True
    assert matches_filter("photo.PNG", "ends-with", ".png") is True
    assert matches_filter("photo.jpg", "ends-with", ".png") is False


def test_contains():
    assert matches_filter("vacation_2024_beach.jpg", "contains", "2024") is True
    assert matches_filter("vacation_2024_beach.jpg", "contains", "mountain") is False


def test_regex():
    assert matches_filter("IMG_0042.jpg", "regex", r"IMG_\d{4}") is True
    assert matches_filter("photo.jpg", "regex", r"IMG_\d{4}") is False


def test_regex_invalid():
    assert matches_filter("photo.jpg", "regex", "[invalid") is False


def test_unknown_filter_type():
    assert matches_filter("photo.jpg", "unknown-type", "val") is True
