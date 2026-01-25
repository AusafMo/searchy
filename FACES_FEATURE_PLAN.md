# Faces Tab Feature Enhancement Plan

## Overview
Comprehensive plan to enhance the Faces tab with search, organization, data quality, and action features.

---

## 1. Search Bar

### UI Changes (Swift)
- Add search bar below header, above grid (similar to main search tab style)
- Real-time filtering as user types
- Clear button when text present
- Placeholder: "Search people..."

### Implementation
```swift
// In facesTabContent, add after header:
@State private var peopleSearchText = ""

// Filter people array:
var filteredPeople: [Person] {
    if peopleSearchText.isEmpty { return faceManager.people }
    return faceManager.people.filter {
        $0.name.localizedCaseInsensitiveContains(peopleSearchText)
    }
}
```

### Effort: Small (Swift only)

---

## 2. Hover Preview

### UI Changes (Swift)
- On PersonCard hover, show floating preview with 3-4 sample face thumbnails
- Small tooltip-style popup below or beside the card
- Show faces from different photos (variety)

### Implementation
- Store multiple face thumbnail paths per cluster (already have `faces` array in Person)
- Create `PersonHoverPreview` view component
- Use `.popover` or custom overlay with delay (similar to image preview in search tab)

### Backend Changes (Python)
- Ensure `FaceCluster.faces` includes diverse samples (maybe pick from different images)
- Add `sample_thumbnails: List[str]` to cluster response (limit to 4)

### Effort: Medium

---

## 3. Organization Features

### 3.1 Merge People

#### UI Changes (Swift)
- Add "Merge" button in person detail view header
- Show modal/sheet with other people to merge into
- Search/filter in merge modal
- Confirmation dialog showing combined result

#### Backend Changes (Python)
```python
# New endpoint: POST /face-merge
def merge_clusters(source_cluster_id: str, target_cluster_id: str, data_dir: str):
    """Merge source cluster into target cluster."""
    # Move all faces from source to target
    # Delete source cluster
    # Update custom names
    # Re-save face index
```

#### Data Model
- Add `merged_from: List[str]` to track merge history (for potential undo)

#### Effort: Medium

---

### 3.2 Hide/Archive People

#### UI Changes (Swift)
- Add "Hide" option in PersonCard context menu
- Add "Show Hidden" toggle in header (like a filter)
- Hidden people shown with reduced opacity when visible
- Badge showing hidden count

#### Backend Changes (Python)
```python
# New file: hidden_clusters.json
# Structure: {"hidden": ["cluster_id_1", "cluster_id_2"]}

# New endpoints:
# POST /face-hide?cluster_id=xxx
# POST /face-unhide?cluster_id=xxx
# GET /face-hidden-count
```

#### Swift Model
```swift
// Add to FaceManager:
@Published var hiddenClusterIds: Set<String> = []
@Published var showHidden: Bool = false

var visiblePeople: [Person] {
    if showHidden { return people }
    return people.filter { !hiddenClusterIds.contains($0.id) }
}
```

#### Effort: Medium

---

### 3.3 Pin Favorites

#### UI Changes (Swift)
- Star/pin icon on PersonCard (top-left, like favorite on ImageCard)
- Pinned people always appear first in grid
- Visual indicator (subtle highlight or pin icon)

#### Backend Changes (Python)
```python
# New file: pinned_clusters.json
# Structure: {"pinned": ["cluster_id_1", "cluster_id_2"]}

# New endpoints:
# POST /face-pin?cluster_id=xxx
# POST /face-unpin?cluster_id=xxx
```

#### Swift Sorting
```swift
var sortedPeople: [Person] {
    let pinned = people.filter { pinnedIds.contains($0.id) }
    let unpinned = people.filter { !pinnedIds.contains($0.id) }
    return pinned + unpinned
}
```

#### Effort: Small-Medium

---

### 3.4 Groups/Tags

#### UI Changes (Swift)
- Tag pills below person name (e.g., "Family", "Work")
- Group filter bar (horizontal scroll of group chips)
- "Manage Groups" in settings or modal
- Assign groups via context menu or detail view

#### Backend Changes (Python)
```python
# New file: cluster_groups.json
# Structure: {
#   "groups": ["Family", "Friends", "Work", "School"],
#   "assignments": {
#     "cluster_id_1": ["Family"],
#     "cluster_id_2": ["Work", "Friends"]
#   }
# }

# New endpoints:
# GET /face-groups
# POST /face-group-create?name=xxx
# POST /face-group-assign?cluster_id=xxx&group=xxx
# POST /face-group-remove?cluster_id=xxx&group=xxx
# DELETE /face-group-delete?name=xxx
```

#### UI Components
- `GroupChip` - small colored pill
- `GroupFilterBar` - horizontal scrolling chips
- `GroupAssignSheet` - modal to assign groups to a person
- `GroupManageView` - create/edit/delete groups

#### Effort: Large

---

## 4. Data Quality Features

### 4.1 Face Verification Mode

#### UI Changes (Swift)
- "Review Faces" button in person detail view
- Full-screen swipe interface (like Tinder)
- Show face crop prominently
- Swipe right = confirm, swipe left = reject
- Rejected faces get moved to "Uncategorized" or separate cluster

#### Backend Changes (Python)
```python
# New endpoint: POST /face-verify
def verify_face(face_id: str, cluster_id: str, is_correct: bool, data_dir: str):
    """Mark a face as verified or move to uncategorized."""
    if is_correct:
        # Mark as verified in face data
        pass
    else:
        # Remove from cluster, add to uncategorized
        pass

# Track verification status per face
# Add to FaceData: verified: bool = False
```

#### UI Components
- `FaceVerificationView` - swipe interface
- `FaceCard` - large face preview with photo context
- Progress indicator (X of Y reviewed)

#### Effort: Large

---

### 4.2 Unreviewed Faces Badge

#### UI Changes (Swift)
- Badge on PersonCard showing unreviewed face count
- Badge on "Faces" tab showing total unreviewed
- After scan, highlight new/unreviewed clusters

#### Backend Changes (Python)
```python
# Add to FaceData model:
verified: bool = False
added_date: str = ""  # ISO timestamp

# Add to cluster response:
unverified_count: int
```

#### Implementation
- After each scan, new faces are marked unverified
- Badge shows count of unverified faces in cluster
- Tab badge shows sum across all clusters

#### Effort: Medium

---

## 5. Action Features

### 5.1 Quick Share

#### UI Changes (Swift)
- "Share" button in person detail view
- Uses native macOS share sheet
- Creates temporary album/folder with person's photos
- Options: Share photos, Share as album, Copy paths

#### Implementation
```swift
func sharePersonPhotos(_ person: Person) {
    let images = faceManager.getImagesForPerson(person)
    let urls = images.map { URL(fileURLWithPath: $0.path) }

    let picker = NSSharingServicePicker(items: urls)
    picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
}
```

#### Effort: Small

---

### 5.2 Create Album

#### UI Changes (Swift)
- "Create Album" button in person detail view
- Prompt for album name (default: person's name)
- Creates symlink folder in user-specified location
- Success toast with "Open in Finder" option

#### Implementation
```swift
func createAlbum(for person: Person, name: String, location: URL) {
    let albumPath = location.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: albumPath)

    let images = faceManager.getImagesForPerson(person)
    for image in images {
        let source = URL(fileURLWithPath: image.path)
        let dest = albumPath.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.createSymbolicLink(at: dest, withDestinationURL: source)
    }
}
```

#### Effort: Small-Medium

---

### 5.3 Bulk Select

#### UI Changes (Swift)
- "Select" button in header toggles selection mode
- Checkmarks appear on PersonCards
- Floating action bar at bottom when items selected
- Actions: Merge, Hide, Add to Group, Delete

#### Implementation
```swift
@State private var isSelectionMode = false
@State private var selectedPeopleIds: Set<String> = []

// PersonCard gets selection state
// Tap toggles selection instead of opening detail
// Header shows "X selected" and Cancel button
```

#### UI Components
- `SelectionActionBar` - floating bar with bulk actions
- Modified `PersonCard` with checkbox overlay

#### Effort: Medium

---

## Implementation Priority

### Phase 1 - Quick Wins (1-2 days)
1. Search bar
2. Pin favorites
3. Quick share

### Phase 2 - Core Organization (3-4 days)
4. Hide/archive
5. Bulk select
6. Merge people

### Phase 3 - Data Quality (3-4 days)
7. Unreviewed faces badge
8. Face verification mode

### Phase 4 - Advanced (4-5 days)
9. Groups/tags
10. Create album
11. Hover preview

---

## Files to Modify

### Swift (ContentView.swift)
- `FaceManager` class - new methods and state
- `facesTabContent` - search bar, filters, selection mode
- `PersonCard` - pin icon, selection checkbox, badges
- `personDetailView` - action buttons, verification
- New views: `FaceVerificationView`, `GroupManageView`, etc.

### Python (face_recognition_service.py)
- `FaceData` model - add verified, added_date fields
- `FaceCluster` - add sample_thumbnails, unverified_count
- New methods: merge, hide, pin, verify, groups

### Python (server.py)
- New endpoints for all operations

### New JSON Files
- `hidden_clusters.json`
- `pinned_clusters.json`
- `cluster_groups.json`
- `verified_faces.json`

---

## Notes

- All organization data (pins, hidden, groups) stored separately from face index
- This allows re-clustering without losing organization
- Consider adding "undo" for destructive operations (merge, delete)
- Face verification could run in background after clustering
