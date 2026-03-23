import os
import pickle
import tempfile
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from atomic_write import atomic_pickle_dump


def test_round_trip(tmp_path):
    filepath = tmp_path / "test.bin"
    data = {"key": [1, 2, 3], "nested": {"a": True}}
    atomic_pickle_dump(data, str(filepath))

    with open(filepath, "rb") as f:
        loaded = pickle.load(f)
    assert loaded == data


def test_overwrites_existing(tmp_path):
    filepath = tmp_path / "test.bin"
    atomic_pickle_dump({"v": 1}, str(filepath))
    atomic_pickle_dump({"v": 2}, str(filepath))

    with open(filepath, "rb") as f:
        assert pickle.load(f)["v"] == 2


def test_no_temp_file_left(tmp_path):
    filepath = tmp_path / "test.bin"
    atomic_pickle_dump("hello", str(filepath))
    files = os.listdir(tmp_path)
    assert files == ["test.bin"]


def test_cleanup_on_failure(tmp_path):
    filepath = tmp_path / "test.bin"
    # Write valid data first
    atomic_pickle_dump({"ok": True}, str(filepath))

    # Try to write unpicklable data — should fail but preserve original
    try:
        atomic_pickle_dump(lambda: None, str(filepath))
    except Exception:
        pass

    with open(filepath, "rb") as f:
        assert pickle.load(f) == {"ok": True}

    # No temp files left behind
    assert os.listdir(tmp_path) == ["test.bin"]
