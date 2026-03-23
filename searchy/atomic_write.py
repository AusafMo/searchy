"""Atomic file write helper — write to temp file, fsync, then rename."""

import os
import pickle
import tempfile


def atomic_pickle_dump(data, filepath):
    """Write data to filepath atomically using pickle.

    Writes to a temp file in the same directory, fsyncs to disk,
    then renames over the target. Rename is atomic on POSIX,
    so the file is never in a half-written state.
    """
    dirpath = os.path.dirname(filepath)
    fd, tmp_path = tempfile.mkstemp(dir=dirpath, suffix='.tmp')
    try:
        with os.fdopen(fd, 'wb') as f:
            pickle.dump(data, f)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, filepath)
    except BaseException:
        # Clean up temp file on any failure
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise
