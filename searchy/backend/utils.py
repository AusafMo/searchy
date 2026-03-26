"""Shared utility functions for the Searchy project."""

import os
import pickle
import re

from constants import SKIP_DIRS, IMAGE_EXTENSIONS


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


def is_image_file(filename: str) -> bool:
    """Check if filename has a recognized image extension."""
    return os.path.splitext(filename.lower())[1] in IMAGE_EXTENSIONS


def load_image_index(data_dir: str):
    """Load image index from data_dir. Returns dict or None if missing/invalid."""
    filename = os.path.join(data_dir, 'image_index.bin')
    if not os.path.exists(filename):
        return None
    with open(filename, 'rb') as f:
        data = pickle.load(f)
    if not isinstance(data, dict) or 'embeddings' not in data or 'image_paths' not in data:
        return None
    return data


class UnionFind:
    """Disjoint-set / union-find with path compression."""

    def __init__(self, n: int):
        self.parent = list(range(n))

    def find(self, x: int) -> int:
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])
        return self.parent[x]

    def union(self, x: int, y: int):
        px, py = self.find(x), self.find(y)
        if px != py:
            self.parent[px] = py
