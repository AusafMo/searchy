# Searchy - Information Security & Privacy Audit Report

**Application:** Searchy (macOS Semantic Image Search)
**Audit Date:** January 2026
**Version:** v1.2
**Status:** Updated with remediation + threat model analysis

---

## Executive Summary

This security audit evaluates the Searchy application's data handling, privacy practices, network communications, and permission usage. The application is a local-first semantic image search tool that uses CLIP embeddings for image similarity search.

### Risk Summary

| Severity | Total | Resolved | Remaining | Won't Fix | Needs Investigation |
|----------|-------|----------|-----------|-----------|---------------------|
| Critical | 2 | 1 | 1 | 0 | 0 |
| High | 6 | 1 | 2 | 3 | 0 |
| Medium | 10 | 1 | 3 | 3 | 3 |
| Low | 6 | 1 | 2 | 2 | 1 |

### Changes in v1.2
- **SEC-004 RESOLVED:** CORS now restricted to localhost origins
- **SEC-012 RESOLVED:** Dependencies pinned with version ranges
- **SEC-019 RESOLVED:** Server now binds to 127.0.0.1 (was 0.0.0.0)
- **Threat model documented:** Explained why certain issues are "Won't Fix"
- **README updated:** Security decisions documented transparently
- **SEC-020 to SEC-025 ADDED:** Additional attack surface areas identified

---

## 1. Data Collection & Storage

### 1.1 Data Collected

| Data Type | Storage Location | Encryption | Retention |
|-----------|------------------|------------|-----------|
| Image file paths | `index.pkl` | None | Persistent |
| Image embeddings (512-1024 dim vectors) | `index.pkl` | None | Persistent |
| Face embeddings | `face_index.pkl` | None | Persistent |
| OCR extracted text | `index.pkl` | None | Persistent |
| Model preferences | `model_config.json` | None | Persistent |
| Watched directories | UserDefaults | System | Persistent |
| Recent searches | Memory only | N/A | Session |

### 1.2 Sensitive Data Identified

- **Biometric Data:** Face embeddings stored in `face_index.pkl` constitute biometric identifiers
- **Personal Documents:** OCR text extraction may capture sensitive document content
- **Location Metadata:** File paths may reveal directory structures and user organization patterns
- **Behavioral Data:** Search queries (in-memory only) could reveal user interests

### 1.3 Findings

**[WON'T FIX] SEC-001: Unencrypted Biometric Storage**
- Face embeddings are stored in plaintext pickle files
- No access controls beyond filesystem permissions
- **Rationale:** If an attacker can read `~/Library/Application Support/searchy/`, they can already access the original images in `~/Pictures`. Encrypting embeddings while source images remain unencrypted is security theater. Would only help if Application Support syncs to cloud (iCloud) while Pictures doesn't.

**[WON'T FIX] SEC-002: OCR Text Exposure**
- Extracted text from images stored without sanitization
- May contain passwords, personal info from screenshots
- **Rationale:** Same as SEC-001. The original images contain the same data. Encrypting extracted text doesn't protect anything the attacker can't already access.

**[MEDIUM] SEC-003: Pickle File Security**
- Pickle files are vulnerable to arbitrary code execution if tampered
- Recommendation: Consider using safer serialization (JSON, SQLite with parameterized queries)

---

## 2. Network Communications

### 2.1 Network Architecture

```
┌─────────────────┐     HTTP (localhost)    ┌─────────────────┐
│   SwiftUI App   │ ◄─────────────────────► │  FastAPI Server │
│   (Frontend)    │      Port 7860          │   (Backend)     │
└─────────────────┘                         └─────────────────┘
                                                    │
                                                    ▼
                                            ┌─────────────────┐
                                            │  HuggingFace    │
                                            │  (Model DL)     │
                                            └─────────────────┘
```

### 2.2 Findings

**[RESOLVED] ~~SEC-004: CORS Misconfiguration~~**
```python
# BEFORE (vulnerable):
allow_origins=["*"]

# AFTER (v1.1 - fixed):
allow_origins=[
    "http://localhost:*",
    "http://127.0.0.1:*",
    "http://localhost",
    "http://127.0.0.1",
]
allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$"
```
- ✅ Fixed: Only localhost origins can now access the API
- External websites can no longer enumerate indexed images

**[RESOLVED] ~~SEC-019: Server Binding to 0.0.0.0~~**
```python
# BEFORE (vulnerable):
uvicorn.run(app, host="0.0.0.0", port=port)

# AFTER (v1.2 - fixed):
uvicorn.run(app, host="127.0.0.1", port=port)
```
- ✅ Fixed: Server now only listens on localhost
- Other machines on the network can no longer access the API

**[WON'T FIX] SEC-005: No Authentication on API**
- All endpoints accessible without authentication
- Any local process can access the API
- **Rationale:** API now binds to 127.0.0.1 only. Any process that can call the API could also just read the index files directly. Authentication adds complexity without meaningful security benefit.

**[WON'T FIX] SEC-006: HTTP vs HTTPS**
- Local communication uses unencrypted HTTP
- **Rationale:** Localhost-only communication. HTTPS would require certificate management for no security benefit on loopback interface.

**[LOW] SEC-007: Model Download Source**
- Models downloaded from HuggingFace without signature verification
- Supply chain risk if HuggingFace compromised
- Recommendation: Pin model hashes, verify checksums

**[MEDIUM - NEEDS INVESTIGATION] SEC-020: API Path Traversal**
- `/similar` endpoint accepts arbitrary `image_path` parameter
- Could potentially be used to probe filesystem: `../../etc/passwd`
- PIL.Image.open() would fail on non-images, but may leak file existence
- Recommendation: Validate paths are within allowed directories, sanitize input

**[HIGH] SEC-021: Transformers Arbitrary Code Execution**
- HuggingFace `transformers` library can execute arbitrary Python when loading models
- A malicious model file could compromise the system on load
- This is by design in transformers (models can have custom code)
- Recommendation: Only load models from trusted sources, consider `trust_remote_code=False`

---

## 3. Permissions & Entitlements

### 3.1 Current Permissions

| Permission | Declared | Justification | Risk |
|------------|----------|---------------|------|
| Full Disk Access | Runtime | Image indexing | High |
| Photos Access | Runtime | Photo library indexing | Medium |
| Automation | Not declared | N/A | N/A |
| Network (Local) | Implicit | API server | Low |
| Network (Outbound) | Implicit | Model download | Low |

### 3.2 Findings

**[WON'T FIX] SEC-008: Excessive Filesystem Access**
- App requests full disk access for indexing
- No scoped bookmark usage for watched directories
- **Rationale:** The app's core purpose is indexing user-selected directories. Security-scoped bookmarks would require re-granting access after app restarts. Runtime permission dialogs already inform users.

**[WON'T FIX] SEC-009: App Sandbox Disabled**
- Application runs without sandbox restrictions
- **Rationale:** Sandboxing would break core functionality. The app needs to read arbitrary user-selected image directories. Would only matter for App Store distribution (requires sandbox).

**[WON'T FIX] SEC-010: Photos Access Scope**
- Full Photos library access when enabled
- **Rationale:** Users explicitly grant Photos access. PHPicker would require manual selection each session, breaking the "index everything" use case.

---

## 4. Third-Party Dependencies

### 4.1 Python Dependencies

| Package | Version | Known Vulnerabilities | Risk |
|---------|---------|----------------------|------|
| torch | >=2.0,<3.0 | None critical | Low |
| transformers | >=4.30,<5.0 | Model loading risks | Medium |
| FastAPI | >=0.100,<1.0 | None critical | Low |
| Pillow | >=10.0,<11.0 | Historic CVEs (patched) | Low |
| deepface | >=0.0.79,<1.0 | Downloads models at runtime | Medium |
| watchdog | >=3.0,<4.0 | None critical | Low |

### 4.2 Findings

**[MEDIUM] SEC-011: Runtime Model Downloads**
- DeepFace downloads face recognition models on first use
- No integrity verification
- Recommendation: Pre-bundle models or verify checksums

**[RESOLVED] ~~SEC-012: Dependency Pinning~~**
```txt
# BEFORE (unpinned):
torch
transformers
fastapi

# AFTER (v1.1 - pinned):
torch>=2.0.0,<3.0.0
transformers>=4.30.0,<5.0.0
fastapi>=0.100.0,<1.0.0
```
- ✅ Fixed: All dependencies now have version range constraints
- Prevents unexpected breaking changes from upstream packages

---

## 5. Data Handling Practices

### 5.1 Data Flow Analysis

```
User Image → PIL Load → CLIP Embedding → Pickle Storage
                ↓
           OCR Extract → Text Storage
                ↓
           Face Detect → Face Embedding Storage
```

### 5.2 Findings

**[HIGH] SEC-013: No Data Minimization**
- All images in watched directories indexed by default
- No exclusion patterns for sensitive folders
- Recommendation: Add exclude patterns, respect .noindex files

**[MEDIUM] SEC-014: No Data Expiration**
- Embeddings persist indefinitely
- Deleted images remain in index until manual reindex
- Recommendation: Implement automatic cleanup of orphaned entries

**[MEDIUM] SEC-015: No Export Controls**
- Index files can be copied/shared without restriction
- Contains paths and embeddings that could identify images
- Recommendation: Document data sensitivity, add export warnings

---

## 6. Privacy Compliance

### 6.1 Regulatory Considerations

| Regulation | Applicability | Compliance Status |
|------------|--------------|-------------------|
| GDPR | If EU users | Partial - No consent flow |
| CCPA | If CA users | Partial - No disclosure |
| BIPA | If IL users | Non-compliant - Biometric data |
| Apple Privacy Guidelines | Yes | Partial |

### 6.2 Findings

**[HIGH] SEC-016: No Privacy Policy**
- Application lacks privacy policy or data disclosure
- Recommendation: Add privacy policy explaining data collection

**[MEDIUM] SEC-017: No Consent for Biometrics**
- Face indexing occurs without explicit consent
- BIPA requires written consent for biometric collection
- Recommendation: Add opt-in for face recognition feature

**[WON'T FIX] SEC-018: No Data Export**
- Users cannot export their data
- **Rationale:** Index files are standard pickle format, documented in README. Users can copy files directly. Adding a UI export adds complexity for minimal benefit.

---

## 7. Additional Attack Surface (Needs Investigation)

These areas were identified but not fully audited. They require further investigation.

### 7.1 Swift Application Security

**[MEDIUM - NEEDS INVESTIGATION] SEC-022: Swift App Security Audit Incomplete**
- Primary audit focused on Python backend
- Swift/SwiftUI frontend not fully reviewed for:
  - Secure storage of watched directories (UserDefaults vs Keychain)
  - Memory handling of sensitive data (search queries, paths)
  - IPC security between Swift app and Python server
  - Hardcoded paths or credentials
  - Proper certificate pinning if any HTTPS calls
- Recommendation: Conduct dedicated Swift security review

### 7.2 Information Leakage

**[MEDIUM - NEEDS INVESTIGATION] SEC-023: Logging Sensitive Data**
- Python logging may capture:
  - Search queries in debug logs
  - Full file paths in error messages
  - User directory structures
- Log files location and retention unknown
- Recommendation: Audit logging configuration, ensure no PII in logs, implement log rotation

**[LOW - NEEDS INVESTIGATION] SEC-024: Temporary File Exposure**
- PIL/Pillow may create temp files during image processing
- PyTorch may cache tensors to disk
- Temp files might contain image data or embeddings
- Location: `/tmp/`, `/var/folders/`, or app-specific temp
- Recommendation: Audit temp file creation, ensure cleanup, consider secure temp directory

**[LOW] SEC-025: Process Argument Visibility**
- File paths passed as command-line arguments visible in `ps aux`
- Example: `python generate_embeddings.py /Users/bob/sensitive-folder/`
- Any user on the system can see process arguments
- Recommendation: Pass sensitive paths via stdin, environment variables, or config files

---

## 9. Threat Model Analysis

### Attack Paths Considered

| Path | Description | Our Response |
|------|-------------|--------------|
| **Path 1: Searchy as attack vector** | Attacker uses Searchy to gain access | **Hardened** - CORS, localhost binding, pinned deps |
| **Path 2: Attacker on system** | Attacker already has system access | **Limited value** - they can access original images anyway |

### Path 1: Searchy as Entry Point (Hardened)

| Vector | Risk | Mitigation |
|--------|------|------------|
| CORS allows any website to query API | Critical | ✅ Fixed - localhost only |
| Server listens on all interfaces | High | ✅ Fixed - 127.0.0.1 binding |
| Malicious dependency update | Medium | ✅ Mitigated - pinned versions |
| Malicious HuggingFace model | High | ⚠️ Open - transformers can execute arbitrary code (SEC-021) |
| Tampered pickle file | Medium | ⚠️ Open - pickle allows code execution (SEC-003) |
| API path traversal | Medium | 🔍 Needs investigation (SEC-020) |
| Process argument exposure | Low | ⚠️ Open - paths visible in ps (SEC-025) |

### Path 2: Attacker Already on System (Limited Mitigation Value)

If an attacker has access to your user account, they can:
- Access original images directly (`~/Pictures`, `~/Downloads`, etc.)
- Keylog any decryption passwords
- Screenshot the running app
- Read process memory

**Conclusion:** Encrypting index files provides minimal security benefit when original images are unencrypted. Searchy doesn't make the situation worse—it just provides faster reconnaissance of images the attacker could already access.

### When Encryption Would Help

Index encryption would provide value in these specific scenarios:
- `~/Library/Application Support/` syncs to iCloud but `~/Pictures` doesn't
- Multi-user system where other accounts might access your files
- Compliance requirements (BIPA, GDPR) that mandate biometric data encryption regardless of practical threat model

---

## 10. Recommendations Summary

### Resolved (v1.2)

| ID | Issue | Status |
|----|-------|--------|
| SEC-004 | CORS Misconfiguration | ✅ Resolved |
| SEC-012 | Dependency Pinning | ✅ Resolved |
| SEC-019 | Server binding 0.0.0.0 | ✅ Resolved |

### Won't Fix (With Rationale)

| ID | Issue | Rationale |
|----|-------|-----------|
| SEC-001 | Biometric encryption | Original images unencrypted; security theater |
| SEC-002 | OCR text encryption | Same as SEC-001 |
| SEC-005 | API authentication | Localhost-only; files readable anyway |
| SEC-006 | HTTPS | Localhost doesn't benefit from TLS |
| SEC-008 | Scoped bookmarks | Would break core functionality |
| SEC-009 | App sandbox | Would break core functionality |
| SEC-010 | Photos picker | Would break "index everything" UX |
| SEC-018 | Data export UI | Files already accessible, format documented |

### Needs Investigation

| ID | Issue | Notes |
|----|-------|-------|
| SEC-020 | API path traversal | Check if `/similar` endpoint can probe filesystem |
| SEC-022 | Swift app security | Full frontend security review pending |
| SEC-023 | Logging sensitive data | Audit what gets logged and where |
| SEC-024 | Temp file exposure | Check PIL/PyTorch temp file behavior |

### Remaining Action Items

**High Priority (Real Risk):**

| ID | Issue | Recommendation |
|----|-------|----------------|
| SEC-003 | Pickle code execution | Replace with JSON/SQLite - eliminates persistence attack vector |
| SEC-021 | Transformers code execution | Use `trust_remote_code=False`, verify model sources |
| SEC-017 | No biometric consent | Add opt-in for face recognition - legal compliance (BIPA) |

**Medium Priority:**

| ID | Issue | Recommendation |
|----|-------|----------------|
| SEC-007 | Model downloads | Add checksum verification for HuggingFace models |
| SEC-011 | DeepFace models | Pre-bundle or verify checksums |
| SEC-013 | No exclusion patterns | Add `.noindex` support |
| SEC-014 | No data expiration | Auto-cleanup orphaned entries |

**Low Priority:**

| ID | Issue | Recommendation |
|----|-------|----------------|
| SEC-015 | Export warnings | Document data sensitivity |
| SEC-016 | Privacy policy | Add to repo (legal, not security) |
| SEC-025 | Process argument exposure | Pass paths via config instead of CLI args |

---

## 11. Appendix

### A. Files Reviewed

- `server.py` - FastAPI backend
- `clip_model.py` - CLIP model manager
- `face_recognition_service.py` - Face detection
- `image_watcher.py` - Directory watcher
- `ContentView.swift` - Main UI
- `searchyApp.swift` - App entry point
- `Info.plist` - App configuration
- `searchy.entitlements` - Sandbox config
- `requirements.txt` - Python dependencies

### B. Test Methodology

- Static code analysis
- Configuration review
- Network traffic inspection
- Permission audit
- Dependency vulnerability scan

### C. Version History

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | Jan 2026 | Initial audit |
| v1.1 | Jan 2026 | Fixed SEC-004 (CORS), SEC-012 (deps) |
| v1.2 | Jan 2026 | Fixed SEC-019 (127.0.0.1 binding), added threat model analysis, documented "Won't Fix" rationale, added SEC-020 to SEC-025 for additional attack surface |

---

*This report is for informational purposes. Findings should be validated in a production environment before remediation.*
