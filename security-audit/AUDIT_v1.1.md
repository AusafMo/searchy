# Searchy - Information Security & Privacy Audit Report

**Application:** Searchy (macOS Semantic Image Search)
**Audit Date:** January 2026
**Version:** v1.1
**Status:** Updated with remediation

---

## Executive Summary

This security audit evaluates the Searchy application's data handling, privacy practices, network communications, and permission usage. The application is a local-first semantic image search tool that uses CLIP embeddings for image similarity search.

### Risk Summary

| Severity | Total | Resolved | Remaining |
|----------|-------|----------|-----------|
| Critical | 2 | 1 | 1 |
| High | 5 | 0 | 5 |
| Medium | 6 | 1 | 5 |
| Low | 4 | 1 | 3 |

### Changes in v1.1
- **SEC-004 RESOLVED:** CORS now restricted to localhost origins
- **SEC-012 RESOLVED:** Dependencies pinned with version ranges

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

**[CRITICAL] SEC-001: Unencrypted Biometric Storage**
- Face embeddings are stored in plaintext pickle files
- No access controls beyond filesystem permissions
- Recommendation: Encrypt biometric data at rest using macOS Keychain or encrypted container

**[HIGH] SEC-002: OCR Text Exposure**
- Extracted text from images stored without sanitization
- May contain passwords, personal info, or sensitive documents
- Recommendation: Allow users to opt-out of OCR, implement selective redaction

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

**[HIGH] SEC-005: No Authentication on API**
- All endpoints accessible without authentication
- Any local process can access the API
- Recommendation: Implement localhost-only binding verification, consider token auth

**[MEDIUM] SEC-006: HTTP vs HTTPS**
- Local communication uses unencrypted HTTP
- Acceptable for localhost, but prevents future remote access
- Recommendation: Document as localhost-only, add HTTPS option if remote needed

**[LOW] SEC-007: Model Download Source**
- Models downloaded from HuggingFace without signature verification
- Supply chain risk if HuggingFace compromised
- Recommendation: Pin model hashes, verify checksums

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

**[HIGH] SEC-008: Excessive Filesystem Access**
- App requests full disk access for indexing
- No scoped bookmark usage for watched directories
- Recommendation: Use security-scoped bookmarks, limit to user-selected directories

**[HIGH] SEC-009: App Sandbox Disabled**
```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>
<!-- No sandbox entitlements -->
```
- Application runs without sandbox restrictions
- Recommendation: Enable App Sandbox with specific entitlements for file access

**[MEDIUM] SEC-010: Photos Access Scope**
- Full Photos library access when enabled
- Recommendation: Use PHPicker for user-selected albums only

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

**[LOW] SEC-018: No Data Export**
- Users cannot export their data
- Recommendation: Add data export functionality

---

## 7. Recommendations Summary

### Completed (v1.1)

| ID | Issue | Status |
|----|-------|--------|
| SEC-004 | CORS Misconfiguration | ✅ Resolved |
| SEC-012 | Dependency Pinning | ✅ Resolved |

### Immediate Actions (Critical/High)

1. **Encrypt Biometric Data** - Use Keychain or encrypted storage
2. **Enable App Sandbox** - Add proper entitlements
3. **Add Biometric Consent** - Opt-in for face recognition
4. **Implement API Authentication** - Token or session-based
5. **Add Privacy Policy** - Document data collection

### Short-term Improvements (Medium)

1. Replace pickle with safer serialization
2. Add data expiration/cleanup
3. Implement exclude patterns for directories
4. Add biometric consent flow

### Long-term Enhancements (Low)

1. Model checksum verification
2. Data export functionality
3. HTTPS support option
4. Audit logging

---

## 8. Appendix

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

---

*This report is for informational purposes. Findings should be validated in a production environment before remediation.*
