import SwiftUI
import Foundation

// MARK: - Person Card for Face Recognition
struct PersonCard: View {
    let person: Person
    var isPinned: Bool = false
    var isHidden: Bool = false
    var isSelected: Bool = false
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

    private let cardSize: CGFloat = 120
    private let hoverDelay: Double = 0.5

    var body: some View {
        ZStack {
            // Full bleed face image
            imageContent

            // Bottom gradient with name
            VStack {
                Spacer()
                nameOverlay
            }

            // Top right - selection checkbox (always visible)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { onToggleSelection?() }) {
                        ZStack {
                            Circle()
                                .fill(isSelected ? DesignSystem.Colors.accent : Color.black.opacity(0.4))
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
                    .padding(6)
                }
                Spacer()
            }

            // Top left - pin button (visible when pinned or hovering)
            if isPinned || (isHovered && !isEditing) {
                VStack {
                    HStack {
                        pinButton
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Edit button on hover (next to pin)
            if isHovered && !isEditing {
                VStack {
                    HStack {
                        // Spacer for pin button width
                        Color.clear.frame(width: 30, height: 1)
                        editButton
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Bottom right - unverified badge (only when unverified > 0)
            if person.unverifiedCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        unverifiedBadge
                    }
                }
            }
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isHidden ? 0.5 : 1.0)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
            radius: isHovered ? 12 : 6,
            y: isHovered ? 6 : 3
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
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
            Button(action: { onTogglePin?() }) {
                Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
            }
            Button(action: { onToggleHide?() }) {
                Label(isHidden ? "Unhide" : "Hide", systemImage: isHidden ? "eye" : "eye.slash")
            }
            Divider()
            Button(action: { startEditing() }) {
                Label("Rename", systemImage: "pencil")
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
                    .frame(width: cardSize, height: cardSize)
                    .clipped()
            } else {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40, weight: .light))
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .focused($isNameFieldFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { cancelRename() }
            } else {
                Text(person.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onTapGesture(count: 2) { startEditing() }
            }
        }
    }

    private var photoBadge: some View {
        Text("\(person.faceCount)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
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
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.orange))
        .padding(6)
        .padding(.bottom, 28) // Above the name overlay
    }

    private var hoverPreviewContent: some View {
        VStack(spacing: 8) {
            Text(person.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            // Show up to 4 sample faces
            HStack(spacing: 6) {
                ForEach(Array(person.faces.prefix(4).enumerated()), id: \.offset) { index, face in
                    FaceThumbnail(imagePath: face.imagePath)
                }
            }

            Text("\(person.faces.count) photos")
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .padding(12)
        .background(DesignSystem.Colors.secondaryBackground)
    }

    private var editButton: some View {
        Button(action: { startEditing() }) {
            Image(systemName: "pencil")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 6)
        .transition(.opacity)
    }

    private var pinButton: some View {
        Button(action: { onTogglePin?() }) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isPinned ? .yellow : .white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(isPinned ? 0.7 : 0.5)))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(6)
        .transition(.opacity)
    }

    private func loadThumbnail() {
        guard let path = person.thumbnailPath else { return }
        let size = Int(cardSize) * 2
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

    private var facesToReview: [(id: String, thumbnailPath: String?, imagePath: String)] {
        person.faces.compactMap { face in
            if verificationResults[face.id.uuidString] == nil {
                return (id: face.id.uuidString, thumbnailPath: nil, imagePath: face.imagePath)
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
        .frame(width: 500, height: 600)
        .background(DesignSystem.Colors.secondaryBackground)
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review Faces")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text("Reviewing \(person.name)")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            Spacer()
            HStack(spacing: 8) {
                Text("\(verificationResults.count)/\(person.faces.count)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                CircularProgressView(progress: progress)
                    .frame(width: 24, height: 24)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("All faces reviewed!")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text("\(confirmedCount) confirmed, \(rejectedCount) rejected")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Button(action: onDismiss) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(DesignSystem.Colors.accent))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 12)
            Spacer()
        }
    }

    private var swipeInterface: some View {
        VStack {
            cardStack
                .padding(32)
            actionButtons
                .padding(.bottom, 32)
            Text("Swipe right to confirm, left to reject")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .padding(.bottom, 16)
        }
    }

    private var cardStack: some View {
        ZStack {
            ForEach(Array(facesToReview.prefix(3).enumerated().reversed()), id: \.element.id) { index, face in
                if index > 0 {
                    FaceReviewCard(imagePath: face.imagePath, thumbnailPath: face.thumbnailPath)
                        .scaleEffect(1.0 - CGFloat(index) * 0.05)
                        .offset(y: CGFloat(index) * 8)
                        .opacity(1.0 - Double(index) * 0.2)
                }
            }
            if let currentFace = facesToReview.first {
                currentCardView(face: currentFace)
            }
        }
    }

    private func currentCardView(face: (id: String, thumbnailPath: String?, imagePath: String)) -> some View {
        FaceReviewCard(imagePath: face.imagePath, thumbnailPath: face.thumbnailPath)
            .offset(x: offset)
            .rotationEffect(.degrees(Double(offset / 20)))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isAnimating { offset = value.translation.width }
                    }
                    .onEnded { value in
                        handleSwipe(value: value, faceId: face.id)
                    }
            )
            .overlay(swipeIndicators)
    }

    private var swipeIndicators: some View {
        ZStack {
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Confirm")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(24)
                .opacity(offset > 50 ? Double(min(1, (offset - 50) / 50)) : 0)
            }
            HStack {
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Reject")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                }
                .padding(24)
                .opacity(offset < -50 ? Double(min(1, (-offset - 50) / 50)) : 0)
                Spacer()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 40) {
            Button(action: { if let f = facesToReview.first { swipeLeft(faceId: f.id) } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { if let f = facesToReview.first { swipeRight(faceId: f.id) } }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.green))
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            verificationResults[faceId] = true
            offset = 0
            isAnimating = false
        }
    }

    private func swipeLeft(faceId: String) {
        isAnimating = true
        withAnimation(.easeOut(duration: 0.3)) { offset = -500 }
        Task { await verifyFace(faceId: faceId, isCorrect: false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            verificationResults[faceId] = false
            offset = 0
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
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOfFile: imagePath) {
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }
}

// Face review card for the swipe interface
struct FaceReviewCard: View {
    let imagePath: String
    let thumbnailPath: String?
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
    }

    private func loadImage() {
        // Try thumbnail first, then full image
        let pathToLoad = thumbnailPath ?? imagePath

        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOfFile: pathToLoad) {
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            } else if thumbnailPath != nil, let nsImage = NSImage(contentsOfFile: imagePath) {
                // Fallback to full image if thumbnail fails
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }
}

// Circular progress indicator
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
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

    var body: some View {
        ZStack {
            // Image content
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: cardHeight)
                    .clipped()
            } else {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    .frame(height: cardHeight)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }

            // Selection overlay
            if isSelected {
                Color.blue.opacity(0.3)
            }

            // Top indicators row
            VStack {
                HStack {
                    // Verified badge (left)
                    if face.verified {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }

                    Spacer()

                    // Selection checkbox (right) - show in selection mode or on hover
                    if isSelectionMode || isHovered {
                        Button(action: { onSelect?() }) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(isSelected ? .blue : .white)
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

                    // Verify/Reject buttons
                    HStack(spacing: 24) {
                        // Reject button
                        Button(action: {
                            verifyFace(isCorrect: false)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.red))
                                .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isVerifying)
                        .help("Not this person")

                        // Verify button
                        Button(action: {
                            verifyFace(isCorrect: true)
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.green))
                                .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
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

            // Bottom gradient with filename
            VStack {
                Spacer()
                HStack {
                    Text(URL(fileURLWithPath: result.path).lastPathComponent)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 8, y: 4)
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
        ThumbnailService.shared.loadThumbnail(for: result.path, maxSize: 400) { image in
            self.thumbnail = image
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
