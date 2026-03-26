"""Shared utility functions for the Searchy project."""

import os
import re

from constants import SKIP_DIRS


def matches_filter(filename: str, filter_type: str, filter_value: str) -> bool:
    """Check if filename matches the filter criteria."""
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


def is_user_image(path: str) -> bool:
    """Check if path is a user image (not system/package file)."""
    if not os.path.exists(path):
        return False
    if os.path.basename(path).startswith('.'):
        return False
    parts = path.split(os.sep)
    return not any(part in SKIP_DIRS for part in parts)
