import SwiftUI
import Foundation

// MARK: - Person Card for Face Recognition
struct PersonCard: View {
    let person: Person
    var isPinned: Bool = false
    var isHidden: Bool = false
    var isSelected: Bool = false
    var isUnknown: Bool = false
    var showPhotosLabel: Bool = true
    var circleSize: CGFloat = 127
    var onRename: ((String) -> Void)?
    var onSelect: (() -> Void)?
    var onTogglePin: (() -> Void)?
    var onToggleHide: (() -> Void)?
    var onToggleSelection: (() -> Void)?
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var showPreview = false
    @State private var previewWorkItem: DispatchWorkItem?
    @FocusState private var isNameFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    private let hoverDelay: Double = 0.5
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(spacing: 6) {
            // Circular face photo with overlays
            ZStack(alignment: .topTrailing) {
                // Circular face image
                imageContent
                    .frame(width: circleSize, height: circleSize)
                    .clipShape(Circle())
                    .saturation(isUnknown ? 0.8 : 1.0)
                    .opacity(isUnknown ? 0.85 : 1.0)
                    .shadow(
                        color: Color.black.opacity(pal.isDark ? 0.35 : 0.12),
                        radius: isHovered ? 10 : 5,
                        y: isHovered ? 4 : 2
                    )

                // Selection checkbox - top right
                Button(action: { onToggleSelection?() }) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? pal.accent : Color.black.opacity(0.4))
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: 2, y: 2)

                // Pin badge - bottom right of circle (accent circle with star)
                if isPinned {
                    ZStack {
                        Circle()
                            .fill(pal.accent)
                            .frame(width: 26, height: 26)
                        Circle()
                            .stroke(pal.paper, lineWidth: 3)
                            .frame(width: 26, height: 26)
                        Text("★")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 2, y: circleSize - 28)
                }

                // Unverified badge - bottom left of circle
                if person.unverifiedCount > 0 {
                    unverifiedBadge
                        .offset(x: -(circleSize - 30), y: circleSize - 26)
                }

                // Edit button on hover - top left
                if isHovered && !isEditing {
                    HStack(spacing: 4) {
                        pinButton
                        editButton
                    }
                    .offset(x: -(circleSize - 52), y: 2)
                }
            }
            .frame(width: circleSize + 8, height: circleSize + 8)

            // Name below image - serif italic
            nameOverlay

            // Photo count - monospace
            Text(showPhotosLabel ? "\(person.faceCount) photos" : "\(person.faceCount)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(pal.ink3)
                .lineLimit(1)
        }
        .frame(width: circleSize + 20)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(isHidden ? 0.5 : 1.0)
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
            // Handle preview with delay
            previewWorkItem?.cancel()
            if hovering && person.faces.count > 1 {
                let workItem = DispatchWorkItem {
                    withAnimation { showPreview = true }
                }
                previewWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: workItem)
            } else {
                withAnimation { showPreview = false }
            }
        }
        .popover(isPresented: $showPreview, arrowEdge: .bottom) {
            hoverPreviewContent
        }
        .onTapGesture {
            if !isEditing {
                onSelect?()
            }
        }
        .contextMenu {
            Button(action: { startEditing() }) {
                Label("Rename", systemImage: "pencil")
            }
            Button(action: { onSelect?() }) {
                Label("View Photos", systemImage: "photo.on.rectangle")
            }

            Divider()

            Button(action: { onTogglePin?() }) {
                Label(isPinned ? "Unpin" : "Pin to Top", systemImage: isPinned ? "pin.slash" : "pin")
            }
            Button(action: { onToggleHide?() }) {
                Label(isHidden ? "Show" : "Hide Person", systemImage: isHidden ? "eye" : "eye.slash")
            }

            Divider()

            Button(action: { onToggleSelection?() }) {
                Label(isSelected ? "Deselect" : "Select for Merge", systemImage: isSelected ? "minus.circle" : "checkmark.circle")
            }

            Divider()

            if isUnknown {
                Button(action: { startEditing() }) {
                    Label("Name This Person", systemImage: "person.badge.plus")
                }
            }

            Button(action: {
                // Copy the person's name
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(person.name, forType: .string)
            }) {
                Label("Copy Name", systemImage: "doc.on.doc")
            }

            Button(action: {
                // Export face thumbnail
                if let thumb = thumbnail {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([thumb])
                }
            }) {
                Label("Copy Photo", systemImage: "photo")
            }

            Divider()

            Button(role: .destructive, action: { onToggleHide?() }) {
                Label("Remove Person", systemImage: "trash")
            }
        }
        .onAppear { loadThumbnail() }
    }

    private var imageContent: some View {
        Group {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(pal.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(pal.isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                    )
            }
        }
    }

    private var nameOverlay: some View {
        Group {
            if isEditing {
                TextField("Name", text: $editedName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(pal.card)
                            .shadow(color: pal.line, radius: 2)
                    )
                    .focused($isNameFieldFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { cancelRename() }
            } else {
                Text(person.name)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture(count: 2) { startEditing() }
            }
        }
    }

    private var photoBadge: some View {
        Text("\(person.faceCount)")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.black.opacity(0.5)))
            .padding(6)
    }

    private var unverifiedBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
            Text("\(person.unverifiedCount)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(DesignSystem.Colors.warning))
    }

    private var hoverPreviewContent: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                // Face thumbnail 38x38
                if let thumbPath = person.thumbnailPath {
                    FaceThumbnail(imagePath: thumbPath, size: 38, cornerRadius: 10)
                } else if let firstFace = person.faces.first {
                    FaceThumbnail(imagePath: firstFace.imagePath, boundingBox: firstFace.boundingBox, size: 38, cornerRadius: 10)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(person.name)
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(pal.ink)

                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(pal.accent)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(person.faceCount) photos")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(pal.ink3)
                        if person.unverifiedCount > 0 && person.unverifiedCount < person.faceCount {
                            Text("·")
                                .foregroundColor(pal.ink3)
                            Text("\(person.unverifiedCount) suggestions")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(pal.ink3)
                        }
                    }
                }

                Spacer()
            }
            .padding(.bottom, 12)

            // Photo grid: 4 columns, fixed 64px cells
            let gridColumns = Array(repeating: GridItem(.fixed(64), spacing: 4), count: 4)
            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(Array(person.faces.prefix(8).enumerated()), id: \.offset) { _, face in
                    FaceThumbnail(imagePath: face.imagePath, boundingBox: face.boundingBox, size: 64, cornerRadius: 6)
                }
            }

            // Footer
            VStack(spacing: 0) {
                Divider()
                    .background(pal.line)
                    .padding(.top, 12)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(pal.ink3)
                        Text(mostRecentLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(pal.ink3)
                    }

                    Spacer()

                    KeyboardHint(key: "\u{21A9}", description: "open")
                }
                .padding(.top, 8)
            }
        }
        .padding(18)
        .frame(width: 304)
        .background(pal.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(pal.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 20, y: 10)
    }

    /// Computes a human-readable "most recent: X days ago" label from face image file dates
    private var mostRecentLabel: String {
        let fm = FileManager.default
        var latest: Date?
        for face in person.faces {
            if let attrs = try? fm.attributesOfItem(atPath: face.imagePath),
               let mod = attrs[.modificationDate] as? Date {
                if latest == nil || mod > latest! {
                    latest = mod
                }
            }
        }
        guard let date = latest else { return "most recent: unknown" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 {
            return "most recent: today"
        } else if days == 1 {
            return "most recent: 1 day ago"
        } else {
            return "most recent: \(days) days ago"
        }
    }

    private var editButton: some View {
        Button(action: { startEditing() }) {
            Image(systemName: "pencil")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.opacity)
    }

    private var pinButton: some View {
        Button(action: { onTogglePin?() }) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isPinned ? .yellow : .white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.black.opacity(isPinned ? 0.7 : 0.5)))
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.opacity)
    }

    private func loadThumbnail() {
        guard let path = person.thumbnailPath else { return }
        let size = Int(circleSize) * 2
        if let cached = ThumbnailService.shared.cachedThumbnail(for: path, size: size) {
            self.thumbnail = cached
            return
        }
        ThumbnailService.shared.loadThumbnail(for: path, maxSize: size) { thumb in
            self.thumbnail = thumb
        }
    }

    private func startEditing() {
        editedName = person.name
        isEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNameFieldFocused = true
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != person.name {
            onRename?(trimmed)
        }
        isEditing = false
    }

    private func cancelRename() {
        isEditing = false
        editedName = person.name
    }
}

// MARK: - Face Verification View
struct FaceVerificationView: View {
    let person: Person
    @ObservedObject var faceManager: FaceManager
    let onDismiss: () -> Void

    @State private var verificationResults: [String: Bool] = [:]
    @Environment(\.colorScheme) var colorScheme

    private var pal: AtelierPalette { ThemeManager.shared.palette }

    private var allFaces: [(id: String, faceId: String?, imagePath: String, boundingBox: CGRect)] {
        person.faces.map { face in
            (id: face.id.uuidString, faceId: face.faceId, imagePath: face.imagePath, boundingBox: face.boundingBox)
        }
    }

    private var reviewedCount: Int { verificationResults.count }
    private var confirmedCount: Int { verificationResults.filter { $0.value }.count }
    private var rejectedCount: Int { verificationResults.filter { !$0.value }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                // Person thumbnail
                if let thumbPath = person.thumbnailPath,
                   let image = NSImage(contentsOfFile: thumbPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("VERIFYING")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundColor(pal.ink3)
                    HStack(spacing: 0) {
                        Text("Is this ")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundColor(pal.ink)
                        Text(person.name)
                            .font(.system(size: 22, weight: .regular, design: .serif).italic())
                            .foregroundColor(pal.accent)
                        Text("?")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundColor(pal.ink)
                    }
                }

                Spacer()

                // Progress pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("\(reviewedCount) of \(person.faces.count) reviewed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pal.ink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(pal.sidebar)
                        .overlay(Capsule().stroke(pal.line, lineWidth: 0.5))
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Rectangle().fill(pal.line).frame(height: 0.5)

            if allFaces.isEmpty {
                completionView
            } else {
                // Grid of face cards
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 10)], spacing: 10) {
                        ForEach(allFaces, id: \.id) { face in
                            verificationGridCard(face: face)
                        }
                    }
                    .padding(16)
                }

                // Keyboard hints footer
                HStack(spacing: 16) {
                    KeyboardHint(key: "\u{2190}", description: "reject")
                    KeyboardHint(key: "\u{2192}", description: "confirm")
                    KeyboardHint(key: "r", description: "skip")
                    Spacer()
                    KeyboardHint(key: "\u{238b}", description: "undo")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(pal.line).frame(height: 0.5)
                }
            }
        }
        .frame(width: 720, height: 640)
        .background(pal.card)
    }

    private func verificationGridCard(face: (id: String, faceId: String?, imagePath: String, boundingBox: CGRect)) -> some View {
        let result = verificationResults[face.id]
        let isReviewed = result != nil
        let isConfirmed = result == true
        let isRejected = result == false
        let verifyId = face.faceId ?? face.id

        return ZStack {
            // Face image
            FaceReviewCard(imagePath: face.imagePath, boundingBox: face.boundingBox)

            // Reviewed indicator (top-right)
            VStack {
                HStack {
                    Spacer()
                    if isConfirmed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(DesignSystem.Colors.success)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    } else if isRejected {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(DesignSystem.Colors.error)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
                .padding(8)
                Spacer()
            }

            // Yes/No buttons at bottom (only for unreviewed)
            if !isReviewed {
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                verificationResults[face.id] = false
                            }
                            Task { await verifyFace(faceId: verifyId, isCorrect: false) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("No")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(Color.black.opacity(0.6))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                verificationResults[face.id] = true
                            }
                            Task { await verifyFace(faceId: verifyId, isCorrect: true) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Yes")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(DesignSystem.Colors.success.opacity(0.85))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Dim overlay for reviewed cards
            if isReviewed {
                Color.black.opacity(isRejected ? 0.3 : 0.05)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(0.85, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isConfirmed ? DesignSystem.Colors.success :
                        (isRejected ? DesignSystem.Colors.error : Color.clear),
                        lineWidth: isReviewed ? 2.5 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            if isReviewed {
                withAnimation(.easeOut(duration: 0.2)) {
                    verificationResults.removeValue(forKey: face.id)
                }
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.success)
            Text("All faces reviewed!")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundColor(pal.ink)
            Text("\(confirmedCount) confirmed, \(rejectedCount) rejected")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(pal.ink2)
            Button(action: onDismiss) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(pal.accent))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 12)
            Spacer()
        }
    }

    private func verifyFace(faceId: String, isCorrect: Bool) async {
        var components = URLComponents(string: "\(faceManager.baseURL)/face-verify")
        components?.queryItems = [
            URLQueryItem(name: "face_id", value: faceId),
            URLQueryItem(name: "cluster_id", value: person.id),
            URLQueryItem(name: "is_correct", value: isCorrect ? "true" : "false"),
            URLQueryItem(name: "data_dir", value: faceManager.dataDir)
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await faceManager.loadClustersFromAPI()
        } catch {
            print("Error verifying face: \(error)")
        }
    }
}

// Small face thumbnail for hover preview
struct FaceThumbnail: View {
    let imagePath: String
    var boundingBox: CGRect? = nil
    var size: CGFloat? = 50
    var cornerRadius: CGFloat = 6
    private var pal: AtelierPalette { ThemeManager.shared.palette }
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(pal.line.opacity(0.3))
                    .frame(width: size, height: size)
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let nsImage = NSImage(contentsOfFile: imagePath) else { return }

            let cropped: NSImage
            if let bbox = boundingBox, let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let imgW = CGFloat(cgImage.width)
                let imgH = CGFloat(cgImage.height)
                // bbox is in pixel coords; add 20% padding for context
                let pad = max(bbox.width, bbox.height) * 0.2
                let cropRect = CGRect(
                    x: max(0, bbox.origin.x - pad),
                    y: max(0, bbox.origin.y - pad),
                    width: min(bbox.width + pad * 2, imgW - max(0, bbox.origin.x - pad)),
                    height: min(bbox.height + pad * 2, imgH - max(0, bbox.origin.y - pad))
                )
                if cropRect.width > 0, cropRect.height > 0, let croppedCG = cgImage.cropping(to: cropRect) {
                    cropped = NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))
                } else {
                    cropped = nsImage
                }
            } else {
                cropped = nsImage
            }

            DispatchQueue.main.async {
                self.image = cropped
            }
        }
    }
}

// Face review card for the swipe interface
struct FaceReviewCard: View {
    let imagePath: String
    let boundingBox: CGRect
    @State private var image: NSImage?
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(pal.isDark ? Color.white.opacity(0.08) : Color.white)
            .frame(width: 320, height: 400)
            .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)
            .overlay(
                Group {
                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 300, height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        ProgressView()
                    }
                }
            )
            .onAppear { loadImage() }
            .id(imagePath)
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let nsImage = NSImage(contentsOfFile: imagePath),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

            let imgW = CGFloat(cgImage.width)
            let imgH = CGFloat(cgImage.height)
            let pad = max(boundingBox.width, boundingBox.height) * 0.5
            let cropRect = CGRect(
                x: max(0, boundingBox.origin.x - pad),
                y: max(0, boundingBox.origin.y - pad),
                width: min(boundingBox.width + pad * 2, imgW - max(0, boundingBox.origin.x - pad)),
                height: min(boundingBox.height + pad * 2, imgH - max(0, boundingBox.origin.y - pad))
            )

            let cropped: NSImage
            if cropRect.width > 0, cropRect.height > 0, let croppedCG = cgImage.cropping(to: cropRect) {
                cropped = NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))
            } else {
                cropped = nsImage
            }

            DispatchQueue.main.async {
                self.image = cropped
            }
        }
    }
}

// Circular progress indicator
struct CircularProgressView: View {
    let progress: Double
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        ZStack {
            Circle()
                .stroke(pal.line, lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(pal.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
    }
}

// MARK: - Person Face Card (with verify/reject buttons and selection)
struct PersonFaceCard: View {
    let face: DetectedFace
    let personId: String
    let result: SearchResult
    @ObservedObject var faceManager: FaceManager
    var cardHeight: CGFloat = 200
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onSelect: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var thumbnail: NSImage?
    @State private var isVerifying = false
    @Environment(\.colorScheme) var colorScheme
    private var pal: AtelierPalette { ThemeManager.shared.palette }

    var body: some View {
        VStack(spacing: 0) {
            // Image content
            ZStack {
                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: cardHeight)
                } else {
                    Rectangle()
                        .fill(pal.card)
                        .frame(height: cardHeight)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }

                // Selection overlay
                if isSelected {
                    pal.accent.opacity(0.25)
                }

                // Top indicators row
                VStack {
                    HStack {
                        // Verified badge (left) - accent checkmark
                        if face.verified {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(pal.accent)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }

                        Spacer()

                        // Selection checkbox (right) - show in selection mode or on hover
                        if isSelectionMode || isHovered {
                            Button(action: { onSelect?() }) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(isSelected ? pal.accent : .white)
                                    .padding(6)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Spacer()
                }
                .padding(8)

                // Hover overlay with verify/reject buttons (only when not in selection mode)
                if isHovered && !face.verified && !isSelectionMode {
                    ZStack {
                        // Semi-transparent overlay
                        Color.black.opacity(0.4)

                        // Verify/Reject buttons - serif italic style
                        HStack(spacing: 8) {
                            Button(action: {
                                verifyFace(isCorrect: false)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(DesignSystem.Colors.error.opacity(0.85)))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isVerifying)
                            .help("Not this person")

                            Button(action: {
                                verifyFace(isCorrect: true)
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(pal.accent))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isVerifying)
                            .help("Confirm this is correct")
                        }

                        if isVerifying {
                            ProgressView()
                                .scaleEffect(1.2)
                        }
                    }
                }
            }
            .frame(height: cardHeight)
            .clipped()

            // Bottom filename bar
            HStack {
                Text(URL(fileURLWithPath: result.path).lastPathComponent)
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(pal.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? pal.accent : pal.line.opacity(0.5), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: Color.black.opacity(pal.isDark ? 0.4 : 0.08), radius: 6, y: 3)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            if isSelectionMode {
                onSelect?()
            }
        }
        .onAppear { loadThumbnail() }
        .contextMenu {
            Button(action: { onSelect?() }) {
                Label(isSelected ? "Deselect" : "Select", systemImage: isSelected ? "checkmark.circle.fill" : "circle")
            }

            Divider()

            Button(action: { verifyFace(isCorrect: true) }) {
                Label("Confirm Face", systemImage: "checkmark.circle")
            }
            .disabled(face.verified)

            Button(action: { verifyFace(isCorrect: false) }) {
                Label("Not This Person", systemImage: "xmark.circle")
            }

            Divider()

            Button(action: {
                NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
            }) {
                Label("Show in Finder", systemImage: "folder")
            }
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let nsImage = NSImage(contentsOfFile: result.path) else { return }
            guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { self.thumbnail = nsImage }
                return
            }

            let bbox = face.boundingBox
            let imgW = CGFloat(cgImage.width)
            let imgH = CGFloat(cgImage.height)
            // Expand crop area by 80% for more context around face
            let pad = max(bbox.width, bbox.height) * 0.8
            let cropRect = CGRect(
                x: max(0, bbox.origin.x - pad),
                y: max(0, bbox.origin.y - pad),
                width: min(bbox.width + pad * 2, imgW - max(0, bbox.origin.x - pad)),
                height: min(bbox.height + pad * 2, imgH - max(0, bbox.origin.y - pad))
            )

            let cropped: NSImage
            if cropRect.width > 0, cropRect.height > 0, let croppedCG = cgImage.cropping(to: cropRect) {
                cropped = NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))
            } else {
                cropped = nsImage
            }

            DispatchQueue.main.async {
                self.thumbnail = cropped
            }
        }
    }

    private func verifyFace(isCorrect: Bool) {
        guard let faceId = face.faceId else { return }
        isVerifying = true

        Task {
            await faceManager.verifyFace(faceId: faceId, clusterId: personId, isCorrect: isCorrect)
            await MainActor.run {
                isVerifying = false
            }
        }
    }
}
