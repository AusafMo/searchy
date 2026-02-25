"""
Face recognition service using DeepFace (SSD detector + ArcFace).
Two-phase pipeline:
  Phase 1: Detect faces in all images (SSD - TensorFlow compatible)
  Phase 2: Generate embeddings for all faces (batch GPU)
"""

import os
import json
import pickle
import logging
import numpy as np
from typing import List, Dict, Optional, Tuple
from datetime import datetime
from PIL import Image
import hashlib
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

logger = logging.getLogger(__name__)

# Lazy loaded DeepFace
_deepface = None

def get_deepface():
    """Lazy load DeepFace module."""
    global _deepface
    if _deepface is None:
        logger.info("Loading DeepFace...")
        from deepface import DeepFace
        _deepface = DeepFace
    return _deepface

def unload_models():
    """Unload models to free memory."""
    global _deepface
    logger.info("Unloading face recognition models...")
    _deepface = None
    try:
        import keras
        keras.backend.clear_session()
    except:
        pass
    try:
        import gc
        gc.collect()
    except:
        pass
    logger.info("Models unloaded")


class FaceData:
    """Represents a detected face with its embedding."""
    def __init__(self, face_id: str, image_path: str, embedding: List[float],
                 bbox: Dict, confidence: float, thumbnail_path: Optional[str] = None,
                 verified: bool = False, added_date: Optional[str] = None):
        self.face_id = face_id
        self.image_path = image_path
        self.embedding = embedding
        self.bbox = bbox  # {"x": int, "y": int, "w": int, "h": int}
        self.confidence = confidence
        self.thumbnail_path = thumbnail_path
        self.verified = verified
        self.added_date = added_date or datetime.now().isoformat()

    def to_dict(self) -> Dict:
        return {
            "face_id": self.face_id,
            "image_path": self.image_path,
            "embedding": self.embedding,
            "bbox": self.bbox,
            "confidence": self.confidence,
            "thumbnail_path": self.thumbnail_path,
            "verified": self.verified,
            "added_date": self.added_date
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'FaceData':
        return cls(
            face_id=data["face_id"],
            image_path=data["image_path"],
            embedding=data["embedding"],
            bbox=data["bbox"],
            confidence=data["confidence"],
            thumbnail_path=data.get("thumbnail_path"),
            verified=data.get("verified", False),
            added_date=data.get("added_date")
        )


class FaceCluster:
    """Represents a cluster of faces (a person)."""
    def __init__(self, cluster_id: str, name: str, faces: List[FaceData]):
        self.cluster_id = cluster_id
        self.name = name
        self.faces = faces

    @property
    def face_count(self) -> int:
        return len(self.faces)

    @property
    def unverified_count(self) -> int:
        return sum(1 for f in self.faces if not f.verified)

    @property
    def thumbnail_path(self) -> Optional[str]:
        # Return first face's thumbnail
        if self.faces and self.faces[0].thumbnail_path:
            return self.faces[0].thumbnail_path
        return None

    def to_dict(self) -> Dict:
        return {
            "cluster_id": self.cluster_id,
            "name": self.name,
            "face_count": self.face_count,
            "unverified_count": self.unverified_count,
            "thumbnail_path": self.thumbnail_path,
            "faces": [f.to_dict() for f in self.faces]
        }


class FaceRecognitionService:
    """Service for face detection, embedding, and clustering."""

    def __init__(self, data_dir: str):
        self.data_dir = data_dir
        self.faces_file = os.path.join(data_dir, "faces_index.bin")
        self.thumbnails_dir = os.path.join(data_dir, "face_thumbnails")
        self.scanned_paths_file = os.path.join(data_dir, "face_scanned_paths.bin")
        self.cluster_names_file = os.path.join(data_dir, "cluster_names.json")
        self.constraints_file = os.path.join(data_dir, "face_constraints.json")
        self.orphaned_faces_file = os.path.join(data_dir, "orphaned_faces.bin")

        # Ensure directories exist
        os.makedirs(self.thumbnails_dir, exist_ok=True)

        # In-memory state
        self.faces: List[FaceData] = []
        self.scanned_paths: set = set()
        self.clusters: List[FaceCluster] = []
        self.custom_names: Dict[str, str] = {}  # cluster_id -> custom name
        self.negative_constraints: Dict[str, List[str]] = {}  # face_id -> [cluster_ids it should NOT be in]
        self.orphaned_faces: List[FaceData] = []  # Faces rejected but not deleted

        # Scanning state
        self.is_scanning = False
        self.scan_progress = 0.0
        self.scan_status = ""
        self.total_to_scan = 0
        self.scanned_count = 0
        self.stop_scan = False

        # Load existing data
        self._load_faces()
        self._load_scanned_paths()
        self._load_custom_names()
        self._load_constraints()
        self._load_orphaned_faces()

    def _load_faces(self):
        """Load faces from disk."""
        if os.path.exists(self.faces_file):
            try:
                with open(self.faces_file, 'rb') as f:
                    data = pickle.load(f)
                self.faces = [FaceData.from_dict(d) for d in data]
                logger.info(f"Loaded {len(self.faces)} faces from disk")
            except Exception as e:
                logger.error(f"Error loading faces: {e}")
                self.faces = []

    def _save_faces(self):
        """Save faces to disk."""
        try:
            with open(self.faces_file, 'wb') as f:
                pickle.dump([f.to_dict() for f in self.faces], f)
            logger.info(f"Saved {len(self.faces)} faces to disk")
        except Exception as e:
            logger.error(f"Error saving faces: {e}")

    def _load_scanned_paths(self):
        """Load scanned paths from disk."""
        if os.path.exists(self.scanned_paths_file):
            try:
                with open(self.scanned_paths_file, 'rb') as f:
                    self.scanned_paths = pickle.load(f)
                logger.info(f"Loaded {len(self.scanned_paths)} scanned paths")
            except Exception as e:
                logger.error(f"Error loading scanned paths: {e}")
                self.scanned_paths = set()

    def _save_scanned_paths(self):
        """Save scanned paths to disk."""
        try:
            with open(self.scanned_paths_file, 'wb') as f:
                pickle.dump(self.scanned_paths, f)
        except Exception as e:
            logger.error(f"Error saving scanned paths: {e}")

    def _load_custom_names(self):
        """Load custom cluster names from disk."""
        if os.path.exists(self.cluster_names_file):
            try:
                with open(self.cluster_names_file, 'r') as f:
                    self.custom_names = json.load(f)
                logger.info(f"Loaded {len(self.custom_names)} custom names")
            except Exception as e:
                logger.error(f"Error loading custom names: {e}")
                self.custom_names = {}

    def _save_custom_names(self):
        """Save custom cluster names to disk."""
        try:
            with open(self.cluster_names_file, 'w') as f:
                json.dump(self.custom_names, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving custom names: {e}")

    def _load_constraints(self):
        """Load negative constraints from disk."""
        if os.path.exists(self.constraints_file):
            try:
                with open(self.constraints_file, 'r') as f:
                    self.negative_constraints = json.load(f)
                logger.info(f"Loaded {len(self.negative_constraints)} negative constraints")
            except Exception as e:
                logger.error(f"Error loading constraints: {e}")
                self.negative_constraints = {}

    def _save_constraints(self):
        """Save negative constraints to disk."""
        try:
            with open(self.constraints_file, 'w') as f:
                json.dump(self.negative_constraints, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving constraints: {e}")

    def _load_orphaned_faces(self):
        """Load orphaned faces from disk."""
        if os.path.exists(self.orphaned_faces_file):
            try:
                with open(self.orphaned_faces_file, 'rb') as f:
                    data = pickle.load(f)
                self.orphaned_faces = [FaceData.from_dict(d) for d in data]
                logger.info(f"Loaded {len(self.orphaned_faces)} orphaned faces")
            except Exception as e:
                logger.error(f"Error loading orphaned faces: {e}")
                self.orphaned_faces = []

    def _save_orphaned_faces(self):
        """Save orphaned faces to disk."""
        try:
            with open(self.orphaned_faces_file, 'wb') as f:
                pickle.dump([f.to_dict() for f in self.orphaned_faces], f)
        except Exception as e:
            logger.error(f"Error saving orphaned faces: {e}")

    def rename_cluster(self, cluster_id: str, new_name: str) -> Dict:
        """Rename a face cluster with a custom name."""
        # Ensure clusters are populated first
        if not self.clusters and self.faces:
            logger.info("Clusters not loaded, running cluster_faces first...")
            self.cluster_faces()

        # Find the cluster
        cluster = next((c for c in self.clusters if c.cluster_id == cluster_id), None)
        if not cluster:
            available = [c.cluster_id for c in self.clusters[:5]]
            logger.warning(f"Cluster {cluster_id} not found. Available clusters: {available}...")
            return {"error": f"Cluster {cluster_id} not found"}

        # Update in-memory
        cluster.name = new_name
        self.custom_names[cluster_id] = new_name

        # Persist to disk
        self._save_custom_names()

        logger.info(f"Renamed cluster {cluster_id} to '{new_name}'")
        return {"status": "success", "cluster_id": cluster_id, "name": new_name}

    def merge_clusters(self, source_cluster_id: str, target_cluster_id: str) -> Dict:
        """Merge source cluster into target cluster."""
        # Ensure clusters are populated first
        if not self.clusters and self.faces:
            logger.info("Clusters not loaded, running cluster_faces first...")
            self.cluster_faces()

        # Find both clusters
        source = next((c for c in self.clusters if c.cluster_id == source_cluster_id), None)
        target = next((c for c in self.clusters if c.cluster_id == target_cluster_id), None)

        if not source:
            return {"error": f"Source cluster {source_cluster_id} not found"}
        if not target:
            return {"error": f"Target cluster {target_cluster_id} not found"}
        if source_cluster_id == target_cluster_id:
            return {"error": "Cannot merge a cluster into itself"}

        # Move all faces from source to target
        target.faces.extend(source.faces)

        # Remove source cluster from clusters list
        self.clusters = [c for c in self.clusters if c.cluster_id != source_cluster_id]

        # Update custom names - remove source, keep target
        if source_cluster_id in self.custom_names:
            del self.custom_names[source_cluster_id]
        self._save_custom_names()

        # Save the updated face index
        self._save_faces()

        logger.info(f"Merged cluster {source_cluster_id} ({source.name}) into {target_cluster_id} ({target.name})")
        return {
            "status": "success",
            "target_cluster_id": target_cluster_id,
            "target_name": target.name,
            "total_faces": target.face_count,
            "merged_face_count": len(source.faces)
        }

    def verify_face(self, face_id: str, cluster_id: str, is_correct: bool) -> Dict:
        """Mark a face as verified or re-home it to a better cluster."""
        # Ensure clusters are populated
        if not self.clusters and self.faces:
            self.cluster_faces()

        # Find the cluster
        cluster = next((c for c in self.clusters if c.cluster_id == cluster_id), None)
        if not cluster:
            return {"error": f"Cluster {cluster_id} not found"}

        # Find the face in the cluster
        face = next((f for f in cluster.faces if f.face_id == face_id), None)
        if not face:
            return {"error": f"Face {face_id} not found in cluster {cluster_id}"}

        if is_correct:
            # Mark face as verified
            face.verified = True
            self._save_faces()
            logger.info(f"Face {face_id} verified in cluster {cluster_id}")
            return {
                "status": "verified",
                "face_id": face_id,
                "cluster_id": cluster_id,
                "remaining_unverified": cluster.unverified_count
            }
        else:
            # Store negative constraint: this face should NOT be in this cluster
            if face_id not in self.negative_constraints:
                self.negative_constraints[face_id] = []
            if cluster_id not in self.negative_constraints[face_id]:
                self.negative_constraints[face_id].append(cluster_id)
            self._save_constraints()

            # Remove face from current cluster
            cluster.faces = [f for f in cluster.faces if f.face_id != face_id]

            # Try to find a better home for this face
            new_cluster_id = self._find_best_cluster_for_face(face, exclude_cluster_ids=[cluster_id])

            result = {
                "status": "rejected",
                "face_id": face_id,
                "original_cluster_id": cluster_id,
                "cluster_empty": len(cluster.faces) == 0
            }

            if new_cluster_id:
                # Found a new home - move face there
                new_cluster = next((c for c in self.clusters if c.cluster_id == new_cluster_id), None)
                if new_cluster:
                    face.verified = False  # Reset verification in new cluster
                    new_cluster.faces.append(face)
                    result["new_cluster_id"] = new_cluster_id
                    result["new_cluster_name"] = new_cluster.name
                    logger.info(f"Face {face_id} re-homed from {cluster_id} to {new_cluster_id}")
            else:
                # No suitable cluster found - add to orphaned faces
                self.orphaned_faces.append(face)
                self._save_orphaned_faces()
                result["orphaned"] = True
                logger.info(f"Face {face_id} orphaned (no suitable cluster found)")

            # If original cluster is now empty, remove it
            if len(cluster.faces) == 0:
                self.clusters = [c for c in self.clusters if c.cluster_id != cluster_id]
                if cluster_id in self.custom_names:
                    del self.custom_names[cluster_id]
                    self._save_custom_names()
                logger.info(f"Cluster {cluster_id} removed (empty after rejection)")

            self._save_faces()
            return result

    def _find_best_cluster_for_face(self, face: FaceData, exclude_cluster_ids: List[str] = None,
                                     similarity_threshold: float = 0.60) -> Optional[str]:
        """
        Find the best matching cluster for a face, respecting negative constraints.
        Returns cluster_id or None if no suitable cluster found.
        """
        if not self.clusters:
            return None

        exclude_cluster_ids = exclude_cluster_ids or []

        # Get clusters this face is constrained from
        constrained_clusters = self.negative_constraints.get(face.face_id, [])

        face_embedding = np.array(face.embedding)
        face_embedding = face_embedding / np.linalg.norm(face_embedding)

        best_cluster_id = None
        best_similarity = similarity_threshold  # Minimum threshold

        for cluster in self.clusters:
            # Skip excluded and constrained clusters
            if cluster.cluster_id in exclude_cluster_ids:
                continue
            if cluster.cluster_id in constrained_clusters:
                continue

            # Compute centroid from verified faces if available, else all faces
            centroid = self._compute_cluster_centroid(cluster, prefer_verified=True)
            if centroid is None:
                continue

            # Compute cosine similarity
            similarity = float(np.dot(face_embedding, centroid))

            if similarity > best_similarity:
                best_similarity = similarity
                best_cluster_id = cluster.cluster_id

        return best_cluster_id

    def _compute_cluster_centroid(self, cluster: FaceCluster, prefer_verified: bool = True) -> Optional[np.ndarray]:
        """
        Compute the centroid of a cluster.
        If prefer_verified=True, uses only verified faces if available.
        """
        if not cluster.faces:
            return None

        # Get faces to use for centroid
        if prefer_verified:
            verified_faces = [f for f in cluster.faces if f.verified]
            faces_to_use = verified_faces if verified_faces else cluster.faces
        else:
            faces_to_use = cluster.faces

        # Compute mean embedding
        embeddings = np.array([f.embedding for f in faces_to_use])
        centroid = np.mean(embeddings, axis=0)

        # Normalize
        norm = np.linalg.norm(centroid)
        if norm > 0:
            centroid = centroid / norm

        return centroid

    def _generate_face_id(self, image_path: str, bbox: Dict) -> str:
        """Generate unique face ID from path and bounding box."""
        unique_str = f"{image_path}_{bbox['x']}_{bbox['y']}_{bbox['w']}_{bbox['h']}"
        return hashlib.md5(unique_str.encode()).hexdigest()[:16]

    def _create_thumbnail(self, image_path: str, bbox: Dict, face_id: str) -> Optional[str]:
        """Create and save a thumbnail for the face."""
        try:
            img = Image.open(image_path)

            # Add padding around face (20%)
            x, y, w, h = bbox['x'], bbox['y'], bbox['w'], bbox['h']
            pad_w, pad_h = int(w * 0.2), int(h * 0.2)

            left = max(0, x - pad_w)
            top = max(0, y - pad_h)
            right = min(img.width, x + w + pad_w)
            bottom = min(img.height, y + h + pad_h)

            face_img = img.crop((left, top, right, bottom))

            # Resize to thumbnail size
            face_img.thumbnail((150, 150), Image.Resampling.LANCZOS)

            # Save thumbnail
            thumbnail_path = os.path.join(self.thumbnails_dir, f"{face_id}.jpg")
            face_img.convert('RGB').save(thumbnail_path, "JPEG", quality=85)

            return thumbnail_path
        except Exception as e:
            logger.error(f"Error creating thumbnail for {image_path}: {e}")
            return None

    def _detect_faces_in_image(self, image_path: str) -> List[Dict]:
        """
        Phase 1: Detect faces in a single image using DeepFace.
        Returns list of face metadata (no embeddings yet).
        """
        detected = []

        # Skip unsupported formats
        ext = os.path.splitext(image_path)[1].lower()
        if ext in ['.gif', '.svg', '.bmp']:
            return []

        try:
            DeepFace = get_deepface()

            # Load image
            img = Image.open(image_path)

            # Skip animated images
            if hasattr(img, 'n_frames') and img.n_frames > 1:
                return []

            # Skip very small images
            if img.width < 50 or img.height < 50:
                return []

            # Skip very large images (resize first)
            max_dim = 1920
            if img.width > max_dim or img.height > max_dim:
                ratio = min(max_dim / img.width, max_dim / img.height)
                new_size = (int(img.width * ratio), int(img.height * ratio))
                img = img.resize(new_size, Image.Resampling.LANCZOS)

            if img.mode != 'RGB':
                img = img.convert('RGB')
            img_array = np.array(img)
            img_h, img_w = img_array.shape[:2]

            # Detect faces using SSD backend (TensorFlow/Keras 3 compatible)
            faces = DeepFace.extract_faces(
                img_path=img_array,
                detector_backend="ssd",  # GPU accelerated, Keras 3 compatible
                enforce_detection=False,
                align=True
            )

            if not faces:
                return []

            for face_data in faces:
                # Get bounding box
                facial_area = face_data.get("facial_area", {})
                bbox = {
                    "x": facial_area.get("x", 0),
                    "y": facial_area.get("y", 0),
                    "w": facial_area.get("w", 0),
                    "h": facial_area.get("h", 0)
                }

                # Skip invalid
                if bbox["w"] <= 0 or bbox["h"] <= 0:
                    continue

                # Skip low confidence
                confidence = face_data.get("confidence", 0)
                if confidence < 0.9:
                    continue

                # Skip very small faces
                if bbox["w"] < 40 or bbox["h"] < 40:
                    continue

                # Skip if face covers too much of image
                face_area_ratio = (bbox["w"] * bbox["h"]) / (img_w * img_h)
                if face_area_ratio > 0.8:
                    continue

                # Skip dark/low-contrast faces
                x, y, w, h = bbox["x"], bbox["y"], bbox["w"], bbox["h"]
                face_region = img_array[max(0,y):min(img_h,y+h), max(0,x):min(img_w,x+w)]
                if face_region.size > 0:
                    mean_brightness = np.mean(face_region)
                    std_brightness = np.std(face_region)
                    if mean_brightness < 30 or std_brightness < 20:
                        continue

                face_id = self._generate_face_id(image_path, bbox)

                # Skip if we already have this face
                if any(f.face_id == face_id for f in self.faces):
                    continue

                # Create thumbnail
                thumbnail_path = self._create_thumbnail(image_path, bbox, face_id)

                detected.append({
                    "face_id": face_id,
                    "image_path": image_path,
                    "bbox": bbox,
                    "confidence": confidence,
                    "thumbnail_path": thumbnail_path
                })

            if detected:
                logger.info(f"Detected {len(detected)} face(s) in {os.path.basename(image_path)}")

        except Exception as e:
            # Silently skip known edge cases
            err_str = str(e).lower()
            known_issues = ["face could not be detected", "vector", "negative dimensions",
                           "assertion failed", "invalid", "empty"]
            if not any(issue in err_str for issue in known_issues):
                logger.warning(f"Skipping {os.path.basename(image_path)}: {e}")

        return detected

    def _generate_embeddings_batch(self, face_detections: List[Dict], batch_size: int = 32) -> List[FaceData]:
        """
        Phase 2: Generate embeddings for detected faces in batches.
        Takes face detections (with thumbnails) and adds embeddings.
        """
        if not face_detections:
            return []

        DeepFace = get_deepface()

        faces_with_embeddings = []
        total = len(face_detections)

        # Process in batches
        for batch_start in range(0, total, batch_size):
            if self.stop_scan:
                break

            batch_end = min(batch_start + batch_size, total)
            batch = face_detections[batch_start:batch_end]

            self.scan_status = f"Generating embeddings {batch_start}/{total}"

            # Load face images for this batch
            face_images = []
            valid_detections = []

            for detection in batch:
                try:
                    # Load the thumbnail (already cropped face)
                    if detection["thumbnail_path"] and os.path.exists(detection["thumbnail_path"]):
                        img = Image.open(detection["thumbnail_path"])
                    else:
                        # Fall back to cropping from original
                        img = Image.open(detection["image_path"])
                        bbox = detection["bbox"]
                        x, y, w, h = bbox["x"], bbox["y"], bbox["w"], bbox["h"]
                        pad = int(max(w, h) * 0.2)
                        img = img.crop((
                            max(0, x - pad),
                            max(0, y - pad),
                            x + w + pad,
                            y + h + pad
                        ))

                    if img.mode != 'RGB':
                        img = img.convert('RGB')

                    # Resize to ArcFace input size (112x112)
                    img = img.resize((112, 112), Image.Resampling.LANCZOS)
                    face_images.append(np.array(img))
                    valid_detections.append(detection)

                except Exception as e:
                    logger.error(f"Error loading face image: {e}")
                    continue

            if not face_images:
                continue

            # Generate embeddings for batch
            try:
                for i, (img_array, detection) in enumerate(zip(face_images, valid_detections)):
                    # Use DeepFace to get embedding (handles preprocessing)
                    embedding_result = DeepFace.represent(
                        img_path=img_array,
                        model_name="ArcFace",
                        detector_backend="skip",  # Already cropped
                        enforce_detection=False
                    )

                    if embedding_result and len(embedding_result) > 0:
                        embedding = embedding_result[0]["embedding"]

                        face_data = FaceData(
                            face_id=detection["face_id"],
                            image_path=detection["image_path"],
                            embedding=embedding,
                            bbox=detection["bbox"],
                            confidence=detection["confidence"],
                            thumbnail_path=detection["thumbnail_path"]
                        )
                        faces_with_embeddings.append(face_data)

            except Exception as e:
                logger.error(f"Error generating embeddings for batch: {e}")
                import traceback
                traceback.print_exc()

        return faces_with_embeddings

    def scan_images(self, image_paths: List[str], incremental: bool = True, limit: int = 0) -> Dict:
        """
        Two-phase face scanning:
          Phase 1: Detect faces in all images (GPU batch detection)
          Phase 2: Generate embeddings for all faces (GPU batch inference)
        """
        if self.is_scanning:
            return {"error": "Scan already in progress"}

        self.is_scanning = True
        self.stop_scan = False
        self.scan_progress = 0.0
        self.scan_status = "Starting scan..."

        try:
            # Filter to only new images if incremental
            if incremental:
                paths_to_scan = [p for p in image_paths if p not in self.scanned_paths]
            else:
                paths_to_scan = image_paths
                self.faces = []
                self.scanned_paths = set()

            if limit > 0:
                paths_to_scan = paths_to_scan[:limit]

            self.total_to_scan = len(paths_to_scan)
            self.scanned_count = 0

            if self.total_to_scan == 0:
                self.scan_status = "No new images to scan"
                self.is_scanning = False
                return {
                    "status": "complete",
                    "new_faces": 0,
                    "total_faces": len(self.faces),
                    "message": "No new images to scan"
                }

            # ============ PHASE 1: FACE DETECTION ============
            # Single-threaded to avoid TensorFlow/GPU memory corruption
            self.scan_status = "Phase 1: Detecting faces..."
            all_detections = []

            for idx, path in enumerate(paths_to_scan):
                if self.stop_scan:
                    break

                try:
                    detections = self._detect_faces_in_image(path)
                    all_detections.extend(detections)
                    self.scanned_paths.add(path)
                except Exception as e:
                    logger.warning(f"Skipping {os.path.basename(path)}: {e}")

                self.scanned_count = idx + 1
                self.scan_progress = ((idx + 1) / self.total_to_scan) * 0.5
                self.scan_status = f"Phase 1: Detecting faces {idx + 1}/{self.total_to_scan}"

            if self.stop_scan:
                self.is_scanning = False
                self.scan_status = "Stopped"
                return {"status": "stopped", "new_faces": 0}

            logger.info(f"Phase 1 complete: {len(all_detections)} faces detected")

            # ============ PHASE 2: EMBEDDING GENERATION ============
            self.scan_status = f"Phase 2: Generating embeddings for {len(all_detections)} faces..."
            self.scan_progress = 0.5

            new_faces = self._generate_embeddings_batch(all_detections, batch_size=32)

            self.scan_progress = 0.9

            # Add new faces to collection
            self.faces.extend(new_faces)

            # Save to disk
            self._save_faces()
            self._save_scanned_paths()

            # Cluster faces
            self.scan_status = "Clustering faces..."
            self.cluster_faces()

            # Unload models to free memory
            unload_models()

            self.scan_status = f"Done! Found {len(new_faces)} new faces"
            self.scan_progress = 1.0
            self.is_scanning = False

            return {
                "status": "complete",
                "new_faces": len(new_faces),
                "total_faces": len(self.faces),
                "clusters": len(self.clusters)
            }

        except Exception as e:
            logger.error(f"Error during face scan: {e}")
            import traceback
            traceback.print_exc()
            unload_models()
            self.is_scanning = False
            self.scan_status = f"Error: {str(e)}"
            return {"error": str(e)}

    def cluster_faces(self, similarity_threshold: float = 0.65) -> List[FaceCluster]:
        """
        Cluster faces using Union-Find based on embedding similarity.
        0.65 works well for OpenCV+ArcFace combo.
        """
        if not self.faces:
            self.clusters = []
            return []

        n = len(self.faces)
        embeddings = np.array([f.embedding for f in self.faces])

        # Normalize embeddings for cosine similarity
        norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
        norms[norms == 0] = 1  # Avoid division by zero
        embeddings_normalized = embeddings / norms

        # Union-Find
        parent = list(range(n))

        def find(x):
            if parent[x] != x:
                parent[x] = find(parent[x])
            return parent[x]

        def union(x, y):
            px, py = find(x), find(y)
            if px != py:
                parent[px] = py

        # Compare faces (O(n^2) but necessary for clustering)
        # Process in batches for large datasets
        batch_size = 500
        for i in range(0, n, batch_size):
            end_i = min(i + batch_size, n)
            batch = embeddings_normalized[i:end_i]

            # Compare against all faces from i onwards
            remaining = embeddings_normalized[i:]
            similarities = batch @ remaining.T

            for bi, row in enumerate(similarities):
                global_i = i + bi
                for rj, sim in enumerate(row):
                    global_j = i + rj
                    if global_j > global_i and sim >= similarity_threshold:
                        union(global_i, global_j)

        # Group faces by cluster
        clusters_dict = {}
        for idx in range(n):
            root = find(idx)
            if root not in clusters_dict:
                clusters_dict[root] = []
            clusters_dict[root].append(self.faces[idx])

        # Create FaceCluster objects
        self.clusters = []
        for i, (root, faces) in enumerate(clusters_dict.items()):
            # Use first face's ID as stable cluster identifier
            cluster_id = f"cluster_{faces[0].face_id}"

            # Check for custom name, fallback to default
            default_name = f"Person {i + 1}"
            name = self.custom_names.get(cluster_id, default_name)

            cluster = FaceCluster(
                cluster_id=cluster_id,
                name=name,
                faces=faces
            )
            self.clusters.append(cluster)

        # Sort by face count descending
        self.clusters.sort(key=lambda c: c.face_count, reverse=True)

        logger.info(f"Clustered {n} faces into {len(self.clusters)} people")
        return self.clusters

    def recluster_with_constraints(self, similarity_threshold: float = 0.60) -> Dict:
        """
        Smart re-clustering that:
        1. Keeps verified faces as fixed anchors in their clusters
        2. Re-assigns unverified faces based on verified centroids
        3. Respects negative constraints (face should NOT be in cluster X)
        4. Tries to find homes for orphaned faces

        Returns statistics about what changed.
        """
        if not self.clusters:
            if self.faces:
                self.cluster_faces()
            return {"error": "No clusters to recluster"}

        stats = {
            "faces_moved": 0,
            "orphans_placed": 0,
            "orphans_remaining": 0,
            "clusters_before": len(self.clusters),
            "clusters_after": 0
        }

        # Step 1: Separate verified and unverified faces
        verified_faces_by_cluster: Dict[str, List[FaceData]] = {}
        unverified_faces: List[Tuple[FaceData, str]] = []  # (face, original_cluster_id)

        for cluster in self.clusters:
            verified_faces_by_cluster[cluster.cluster_id] = []
            for face in cluster.faces:
                if face.verified:
                    verified_faces_by_cluster[cluster.cluster_id].append(face)
                else:
                    unverified_faces.append((face, cluster.cluster_id))

        # Step 2: Compute verified centroids for clusters with verified faces
        verified_centroids: Dict[str, np.ndarray] = {}
        for cluster_id, verified_faces in verified_faces_by_cluster.items():
            if verified_faces:
                embeddings = np.array([f.embedding for f in verified_faces])
                centroid = np.mean(embeddings, axis=0)
                norm = np.linalg.norm(centroid)
                if norm > 0:
                    centroid = centroid / norm
                verified_centroids[cluster_id] = centroid

        # If no verified faces anywhere, can't do smart re-clustering
        if not verified_centroids:
            logger.info("No verified faces found, cannot perform constrained re-clustering")
            return {"error": "No verified faces to use as anchors. Verify some faces first."}

        # Step 3: Rebuild clusters starting with verified faces
        new_clusters: Dict[str, FaceCluster] = {}
        for cluster in self.clusters:
            if cluster.cluster_id in verified_centroids:
                # Keep cluster with only verified faces for now
                new_clusters[cluster.cluster_id] = FaceCluster(
                    cluster_id=cluster.cluster_id,
                    name=cluster.name,
                    faces=verified_faces_by_cluster[cluster.cluster_id].copy()
                )

        # Step 4: Re-assign unverified faces to best matching cluster
        for face, original_cluster_id in unverified_faces:
            face_embedding = np.array(face.embedding)
            face_embedding = face_embedding / np.linalg.norm(face_embedding)

            # Get constraints for this face
            constrained_clusters = self.negative_constraints.get(face.face_id, [])

            best_cluster_id = None
            best_similarity = similarity_threshold

            for cluster_id, centroid in verified_centroids.items():
                # Skip constrained clusters
                if cluster_id in constrained_clusters:
                    continue

                similarity = float(np.dot(face_embedding, centroid))
                if similarity > best_similarity:
                    best_similarity = similarity
                    best_cluster_id = cluster_id

            if best_cluster_id:
                new_clusters[best_cluster_id].faces.append(face)
                if best_cluster_id != original_cluster_id:
                    stats["faces_moved"] += 1
            else:
                # No suitable cluster - becomes orphaned
                if face not in self.orphaned_faces:
                    self.orphaned_faces.append(face)

        # Step 5: Try to place orphaned faces
        placed_orphans = []
        for face in self.orphaned_faces:
            face_embedding = np.array(face.embedding)
            face_embedding = face_embedding / np.linalg.norm(face_embedding)

            constrained_clusters = self.negative_constraints.get(face.face_id, [])

            best_cluster_id = None
            best_similarity = similarity_threshold

            for cluster_id, centroid in verified_centroids.items():
                if cluster_id in constrained_clusters:
                    continue

                similarity = float(np.dot(face_embedding, centroid))
                if similarity > best_similarity:
                    best_similarity = similarity
                    best_cluster_id = cluster_id

            if best_cluster_id:
                new_clusters[best_cluster_id].faces.append(face)
                placed_orphans.append(face)
                stats["orphans_placed"] += 1

        # Remove placed orphans from orphaned list
        self.orphaned_faces = [f for f in self.orphaned_faces if f not in placed_orphans]
        stats["orphans_remaining"] = len(self.orphaned_faces)

        # Step 6: Update clusters list (remove empty clusters)
        self.clusters = [c for c in new_clusters.values() if c.faces]
        self.clusters.sort(key=lambda c: c.face_count, reverse=True)

        stats["clusters_after"] = len(self.clusters)

        # Save changes
        self._save_faces()
        self._save_orphaned_faces()

        logger.info(f"Re-clustering complete: {stats}")
        return stats

    def get_orphaned_faces(self) -> List[Dict]:
        """Get list of orphaned faces that couldn't be assigned to any cluster."""
        return [f.to_dict() for f in self.orphaned_faces]

    def get_clusters(self) -> List[Dict]:
        """Get all face clusters."""
        if not self.clusters and self.faces:
            self.cluster_faces()
        return [c.to_dict() for c in self.clusters]

    def get_scan_status(self) -> Dict:
        """Get current scan status."""
        return {
            "is_scanning": self.is_scanning,
            "progress": self.scan_progress,
            "status": self.scan_status,
            "total_to_scan": self.total_to_scan,
            "scanned_count": self.scanned_count,
            "total_faces": len(self.faces),
            "total_clusters": len(self.clusters)
        }

    def clear_all(self):
        """Clear all face data."""
        self.faces = []
        self.scanned_paths = set()
        self.clusters = []

        # Delete files
        if os.path.exists(self.faces_file):
            os.remove(self.faces_file)
        if os.path.exists(self.scanned_paths_file):
            os.remove(self.scanned_paths_file)

        # Clear thumbnails
        if os.path.exists(self.thumbnails_dir):
            for f in os.listdir(self.thumbnails_dir):
                os.remove(os.path.join(self.thumbnails_dir, f))

        logger.info("Cleared all face data")
        return {"status": "cleared"}

    def get_new_images_count(self, image_paths: List[str]) -> int:
        """Get count of images not yet scanned."""
        return len([p for p in image_paths if p not in self.scanned_paths])


# Global instance (lazy loaded)
_face_service: Optional[FaceRecognitionService] = None

def get_face_service(data_dir: str) -> FaceRecognitionService:
    """Get or create the face recognition service."""
    global _face_service
    if _face_service is None:
        _face_service = FaceRecognitionService(data_dir)
    return _face_service
