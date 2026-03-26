import re


def matches_filter(filename, filter_type, filter_value):
    """Pure copy of the filter function from generate_embeddings.py for testing without heavy deps."""
    if not filter_value or filter_type == "all":
        return True

    filename_lower = filename.lower()
    filter_lower = filter_value.lower()

    if filter_type == "starts-with":
        return filename_lower.startswith(filter_lower)
    elif filter_type == "ends-with":
        return filename_lower.endswith(filter_lower)
    elif filter_type == "contains":
        return filter_lower in filename_lower
    elif filter_type == "regex":
        try:
            return bool(re.search(filter_value, filename, re.IGNORECASE))
        except re.error:
            return False
    return True


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
