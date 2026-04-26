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
                        color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
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
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
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

    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    @State private var verificationResults: [String: Bool] = [:]
    @Environment(\.colorScheme) var colorScheme

    private var facesToReview: [(id: String, imagePath: String, boundingBox: CGRect)] {
        person.faces.compactMap { face in
            if verificationResults[face.id.uuidString] == nil {
                return (id: face.id.uuidString, imagePath: face.imagePath, boundingBox: face.boundingBox)
            }
            return nil
        }
    }

    private var progress: Double {
        let total = person.faces.count
        let reviewed = verificationResults.count
        return total > 0 ? Double(reviewed) / Double(total) : 0
    }

    private var confirmedCount: Int {
        verificationResults.filter { $0.value }.count
    }

    private var rejectedCount: Int {
        verificationResults.filter { !$0.value }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if facesToReview.isEmpty {
                completionView
            } else {
                swipeInterface
            }
        }
        .frame(width: 520, height: 680)
        .background(pal.card)
    }

    private var pal: AtelierPalette { ThemeManager.shared.palette }

    private var headerView: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FACE REVIEW")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundColor(pal.ink3)
                Text("Reviewing \(person.name)")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink)
                HStack(spacing: 8) {
                    Text("\(verificationResults.count)/\(person.faces.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(pal.ink2)
                    Text("\(confirmedCount) kept")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.success)
                    Text("\(rejectedCount) removed")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.error)
                }
            }
            Spacer()
            CircularProgressView(progress: progress)
                .frame(width: 36, height: 36)
            Button(action: onDismiss) {
                ZStack {
                    Circle()
                        .fill(pal.paper)
                        .overlay(Circle().stroke(pal.line, lineWidth: 1))
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(pal.ink3)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 16)
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

    private var swipeInterface: some View {
        VStack(spacing: 0) {
            cardStack
                .padding(22)
            actionButtons
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            // Keyboard hints footer
            HStack(spacing: 16) {
                KeyboardHint(key: "\u{2190}", description: "reject")
                KeyboardHint(key: "\u{2192}", description: "confirm")
                KeyboardHint(key: "\u{2191}", description: "skip")
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                Divider().background(pal.line)
            }
        }
    }

    private var cardStack: some View {
        ZStack {
            ForEach(Array(facesToReview.prefix(3).enumerated().reversed()), id: \.element.id) { index, face in
                if index > 0 {
                    FaceReviewCard(imagePath: face.imagePath, boundingBox: face.boundingBox)
                        .id(face.id)
                        .scaleEffect(1.0 - CGFloat(index) * 0.05)
                        .offset(y: CGFloat(index) * 8)
                        .opacity(1.0 - Double(index) * 0.2)
                }
            }
            if let currentFace = facesToReview.first {
                FaceReviewCard(imagePath: currentFace.imagePath, boundingBox: currentFace.boundingBox)
                    .id(currentFace.id)
                    .offset(x: offset)
                    .rotationEffect(.degrees(Double(offset / 20)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isAnimating { offset = value.translation.width }
                            }
                            .onEnded { value in
                                handleSwipe(value: value, faceId: currentFace.id)
                            }
                    )
                    .overlay(swipeIndicators)
            }
        }
    }

    private var swipeIndicators: some View {
        ZStack {
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.success)
                    Text("Confirm")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.success)
                }
                .padding(24)
                .opacity(offset > 50 ? Double(min(1, (offset - 50) / 50)) : 0)
            }
            HStack {
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.error)
                    Text("Reject")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.error)
                }
                .padding(24)
                .opacity(offset < -50 ? Double(min(1, (-offset - 50) / 50)) : 0)
                Spacer()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button(action: { if let f = facesToReview.first { swipeLeft(faceId: f.id) } }) {
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                    Text("not them")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .italic()
                }
                .foregroundColor(DesignSystem.Colors.error)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(pal.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(pal.line, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { if let f = facesToReview.first { swipeRight(faceId: f.id) } }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .medium))
                    Text("yes, that\u{2019}s them")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .italic()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(pal.accent)
                )
                .shadow(color: pal.accent.opacity(0.3), radius: 11, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func handleSwipe(value: DragGesture.Value, faceId: String) {
        let threshold: CGFloat = 100
        if value.translation.width > threshold {
            swipeRight(faceId: faceId)
        } else if value.translation.width < -threshold {
            swipeLeft(faceId: faceId)
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { offset = 0 }
        }
    }

    private func swipeRight(faceId: String) {
        isAnimating = true
        withAnimation(.easeOut(duration: 0.3)) { offset = 500 }
        Task { await verifyFace(faceId: faceId, isCorrect: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Reset offset without animation before removing the card
            offset = 0
            withAnimation(.easeInOut(duration: 0.2)) {
                verificationResults[faceId] = true
            }
            isAnimating = false
        }
    }

    private func swipeLeft(faceId: String) {
        isAnimating = true
        withAnimation(.easeOut(duration: 0.3)) { offset = -500 }
        Task { await verifyFace(faceId: faceId, isCorrect: false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            offset = 0
            withAnimation(.easeInOut(duration: 0.2)) {
                verificationResults[faceId] = false
            }
            isAnimating = false
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

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
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
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 6, y: 3)
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
