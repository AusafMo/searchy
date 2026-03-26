"""Face recognition routes: all /face-* endpoints."""

import os
import json
import logging
import pickle
from typing import List
from threading import Thread
from fastapi import APIRouter

from constants import DEFAULT_DATA_DIR, FACE_REASSIGN_THRESHOLD
from face_recognition_service import get_face_service
from utils import is_user_image

router = APIRouter()
logger = logging.getLogger(__name__)


# ── Pinned clusters helpers ──────────────────────────────

def _pinned_file(data_dir: str) -> str:
    return os.path.join(data_dir, 'pinned_clusters.json')


def _load_pinned(data_dir: str) -> List[str]:
    filepath = _pinned_file(data_dir)
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r') as f:
                return json.load(f).get('pinned', [])
        except Exception:
            pass
    return []


def _save_pinned(data_dir: str, pinned: List[str]):
    with open(_pinned_file(data_dir), 'w') as f:
        json.dump({'pinned': pinned}, f)


# ── Hidden clusters helpers ──────────────────────────────

def _hidden_file(data_dir: str) -> str:
    return os.path.join(data_dir, 'hidden_clusters.json')


def _load_hidden(data_dir: str) -> List[str]:
    filepath = _hidden_file(data_dir)
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r') as f:
                return json.load(f).get('hidden', [])
        except Exception:
            pass
    return []


def _save_hidden(data_dir: str, hidden: List[str]):
    with open(_hidden_file(data_dir), 'w') as f:
        json.dump({'hidden': hidden}, f)


# ── Groups/tags helpers ──────────────────────────────────

def _groups_file(data_dir: str) -> str:
    return os.path.join(data_dir, "cluster_groups.json")


def _load_groups(data_dir: str) -> dict:
    filepath = _groups_file(data_dir)
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r') as f:
                return json.load(f)
        except Exception:
            pass
    return {"groups": [], "assignments": {}}


def _save_groups(data_dir: str, data: dict):
    with open(_groups_file(data_dir), 'w') as f:
        json.dump(data, f)


# ── Pydantic models ──────────────────────────────────────

from pydantic import BaseModel


class FaceScanRequest(BaseModel):
    data_dir: str = DEFAULT_DATA_DIR
    incremental: bool = True
    limit: int = 0


# ── Routes ───────────────────────────────────────────────

@router.post("/face-scan")
def start_face_scan(request: FaceScanRequest):
    """Start face scanning on indexed images."""
    try:
        face_service = get_face_service(request.data_dir)

        if face_service.is_scanning:
            return {"status": "already_scanning", "message": "Face scan already in progress"}

        filename = os.path.join(request.data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"status": "error", "message": "No images indexed yet"}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        image_paths = [p for p in data.get('image_paths', []) if is_user_image(p)]

        if not image_paths:
            return {"status": "error", "message": "No images to scan"}

        def run_scan():
            face_service.scan_images(image_paths, incremental=request.incremental, limit=request.limit)

        thread = Thread(target=run_scan, daemon=True)
        thread.start()

        new_count = face_service.get_new_images_count(image_paths) if request.incremental else len(image_paths)
        scan_count = min(new_count, request.limit) if request.limit > 0 else new_count

        return {
            "status": "started",
            "total_images": len(image_paths),
            "new_images": new_count,
            "will_scan": scan_count
        }
    except Exception as e:
        logger.error(f"Error starting face scan: {e}")
        return {"status": "error", "message": str(e)}


@router.get("/face-scan-status")
def get_face_scan_status(data_dir: str = DEFAULT_DATA_DIR):
    """Get current face scan status."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.get_scan_status()
    except Exception as e:
        logger.error(f"Error getting face scan status: {e}")
        return {"error": str(e)}


@router.get("/face-clusters")
def get_face_clusters(data_dir: str = DEFAULT_DATA_DIR):
    """Get all face clusters (people)."""
    try:
        face_service = get_face_service(data_dir)
        clusters = face_service.get_clusters()
        return {
            "clusters": clusters,
            "total_clusters": len(clusters),
            "total_faces": len(face_service.faces)
        }
    except Exception as e:
        logger.error(f"Error getting face clusters: {e}")
        return {"error": str(e)}


@router.post("/face-rename")
def rename_face_cluster(cluster_id: str, name: str, data_dir: str = DEFAULT_DATA_DIR):
    """Rename a face cluster with a custom name."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.rename_cluster(cluster_id, name)
    except Exception as e:
        logger.error(f"Error renaming cluster: {e}")
        return {"error": str(e)}


@router.post("/face-pin")
def pin_face_cluster(cluster_id: str, data_dir: str = DEFAULT_DATA_DIR):
    """Pin a face cluster to show it first."""
    try:
        pinned = _load_pinned(data_dir)
        if cluster_id not in pinned:
            pinned.append(cluster_id)
            _save_pinned(data_dir, pinned)
        return {"status": "success", "pinned": pinned}
    except Exception as e:
        logger.error(f"Error pinning cluster: {e}")
        return {"error": str(e)}


@router.post("/face-unpin")
def unpin_face_cluster(cluster_id: str, data_dir: str = DEFAULT_DATA_DIR):
    """Unpin a face cluster."""
    try:
        pinned = _load_pinned(data_dir)
        if cluster_id in pinned:
            pinned.remove(cluster_id)
            _save_pinned(data_dir, pinned)
        return {"status": "success", "pinned": pinned}
    except Exception as e:
        logger.error(f"Error unpinning cluster: {e}")
        return {"error": str(e)}


@router.get("/face-pinned")
def get_pinned_clusters(data_dir: str = DEFAULT_DATA_DIR):
    """Get list of pinned cluster IDs."""
    try:
        return {"pinned": _load_pinned(data_dir)}
    except Exception as e:
        logger.error(f"Error getting pinned clusters: {e}")
        return {"error": str(e)}


@router.post("/face-hide")
def hide_face_cluster(cluster_id: str, data_dir: str = DEFAULT_DATA_DIR):
    """Hide a face cluster from the main view."""
    try:
        hidden = _load_hidden(data_dir)
        if cluster_id not in hidden:
            hidden.append(cluster_id)
            _save_hidden(data_dir, hidden)
        return {"status": "success", "hidden": hidden}
    except Exception as e:
        logger.error(f"Error hiding cluster: {e}")
        return {"error": str(e)}


@router.post("/face-unhide")
def unhide_face_cluster(cluster_id: str, data_dir: str = DEFAULT_DATA_DIR):
    """Unhide a face cluster."""
    try:
        hidden = _load_hidden(data_dir)
        if cluster_id in hidden:
            hidden.remove(cluster_id)
            _save_hidden(data_dir, hidden)
        return {"status": "success", "hidden": hidden}
    except Exception as e:
        logger.error(f"Error unhiding cluster: {e}")
        return {"error": str(e)}


@router.get("/face-hidden")
def get_hidden_clusters(data_dir: str = DEFAULT_DATA_DIR):
    """Get list of hidden cluster IDs."""
    try:
        hidden = _load_hidden(data_dir)
        return {"hidden": hidden, "count": len(hidden)}
    except Exception as e:
        logger.error(f"Error getting hidden clusters: {e}")
        return {"error": str(e)}


@router.get("/face-groups")
def get_face_groups(data_dir: str = DEFAULT_DATA_DIR):
    """Get all groups and their assignments."""
    try:
        return _load_groups(data_dir)
    except Exception as e:
        logger.error(f"Error getting groups: {e}")
        return {"error": str(e)}


@router.post("/face-group-create")
def create_face_group(name: str, data_dir: str = DEFAULT_DATA_DIR):
    """Create a new group."""
    try:
        data = _load_groups(data_dir)
        if name not in data["groups"]:
            data["groups"].append(name)
            _save_groups(data_dir, data)
        return {"status": "success", "groups": data["groups"]}
    except Exception as e:
        logger.error(f"Error creating group: {e}")
        return {"error": str(e)}


@router.post("/face-group-assign")
def assign_face_group(cluster_id: str, group: str, data_dir: str = DEFAULT_DATA_DIR):
    """Assign a cluster to a group."""
    try:
        data = _load_groups(data_dir)
        if cluster_id not in data["assignments"]:
            data["assignments"][cluster_id] = []
        if group not in data["assignments"][cluster_id]:
            data["assignments"][cluster_id].append(group)
            _save_groups(data_dir, data)
        return {"status": "success", "assignments": data["assignments"].get(cluster_id, [])}
    except Exception as e:
        logger.error(f"Error assigning group: {e}")
        return {"error": str(e)}


@router.post("/face-group-remove")
def remove_face_group(cluster_id: str, group: str, data_dir: str = DEFAULT_DATA_DIR):
    """Remove a cluster from a group."""
    try:
        data = _load_groups(data_dir)
        if cluster_id in data["assignments"] and group in data["assignments"][cluster_id]:
            data["assignments"][cluster_id].remove(group)
            if not data["assignments"][cluster_id]:
                del data["assignments"][cluster_id]
            _save_groups(data_dir, data)
        return {"status": "success", "assignments": data["assignments"].get(cluster_id, [])}
    except Exception as e:
        logger.error(f"Error removing group: {e}")
        return {"error": str(e)}


@router.delete("/face-group-delete")
def delete_face_group(name: str, data_dir: str = DEFAULT_DATA_DIR):
    """Delete a group and remove all assignments."""
    try:
        data = _load_groups(data_dir)
        if name in data["groups"]:
            data["groups"].remove(name)
            for cluster_id in list(data["assignments"].keys()):
                if name in data["assignments"][cluster_id]:
                    data["assignments"][cluster_id].remove(name)
                    if not data["assignments"][cluster_id]:
                        del data["assignments"][cluster_id]
            _save_groups(data_dir, data)
        return {"status": "success", "groups": data["groups"]}
    except Exception as e:
        logger.error(f"Error deleting group: {e}")
        return {"error": str(e)}


@router.post("/face-merge")
def merge_face_clusters(source_cluster_id: str, target_cluster_id: str, data_dir: str = DEFAULT_DATA_DIR):
    """Merge source cluster into target cluster."""
    try:
        face_service = get_face_service(data_dir)
        result = face_service.merge_clusters(source_cluster_id, target_cluster_id)

        if result.get("status") == "success":
            pinned = _load_pinned(data_dir)
            if source_cluster_id in pinned:
                pinned.remove(source_cluster_id)
                _save_pinned(data_dir, pinned)

            hidden = _load_hidden(data_dir)
            if source_cluster_id in hidden:
                hidden.remove(source_cluster_id)
                _save_hidden(data_dir, hidden)

        return result
    except Exception as e:
        logger.error(f"Error merging clusters: {e}")
        return {"error": str(e)}


@router.post("/face-verify")
def verify_face(face_id: str, cluster_id: str, is_correct: bool, data_dir: str = DEFAULT_DATA_DIR):
    """Mark a face as verified or remove it from the cluster."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.verify_face(face_id, cluster_id, is_correct)
    except Exception as e:
        logger.error(f"Error verifying face: {e}")
        return {"error": str(e)}


@router.post("/face-recluster")
def recluster_faces(data_dir: str = DEFAULT_DATA_DIR, similarity_threshold: float = FACE_REASSIGN_THRESHOLD):
    """Smart re-clustering that uses verified faces as anchors."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.recluster_with_constraints(similarity_threshold)
    except Exception as e:
        logger.error(f"Error re-clustering faces: {e}")
        return {"error": str(e)}


@router.get("/face-orphans")
def get_orphaned_faces(data_dir: str = DEFAULT_DATA_DIR):
    """Get list of orphaned faces that couldn't be assigned to any cluster."""
    try:
        face_service = get_face_service(data_dir)
        orphans = face_service.get_orphaned_faces()
        return {"orphans": orphans, "count": len(orphans)}
    except Exception as e:
        logger.error(f"Error getting orphaned faces: {e}")
        return {"error": str(e)}


@router.get("/face-new-count")
def get_new_face_count(data_dir: str = DEFAULT_DATA_DIR):
    """Get count of images not yet scanned for faces."""
    try:
        face_service = get_face_service(data_dir)

        filename = os.path.join(data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"new_count": 0, "total_indexed": 0}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        image_paths = [p for p in data.get('image_paths', []) if is_user_image(p)]
        new_count = face_service.get_new_images_count(image_paths)

        return {
            "new_count": new_count,
            "total_indexed": len(image_paths),
            "already_scanned": len(image_paths) - new_count
        }
    except Exception as e:
        logger.error(f"Error getting new face count: {e}")
        return {"error": str(e)}


@router.post("/face-clear")
def clear_face_data(data_dir: str = DEFAULT_DATA_DIR):
    """Clear all face data."""
    try:
        face_service = get_face_service(data_dir)
        return face_service.clear_all()
    except Exception as e:
        logger.error(f"Error clearing face data: {e}")
        return {"error": str(e)}


@router.post("/face-stop")
def stop_face_scan(data_dir: str = DEFAULT_DATA_DIR):
    """Stop the current face scan."""
    try:
        face_service = get_face_service(data_dir)
        face_service.stop_scan = True
        return {"status": "stopping"}
    except Exception as e:
        logger.error(f"Error stopping face scan: {e}")
        return {"error": str(e)}
