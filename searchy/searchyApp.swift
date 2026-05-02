import Foundation
import AppKit
import SwiftUI
import Carbon

// MARK: - Setup Manager
class SetupManager: ObservableObject {
    static let shared = SetupManager()

    @Published var isSetupComplete: Bool = false
    @Published var isSettingUp: Bool = false
    @Published var setupProgress: String = ""
    @Published var setupError: String?
    @Published var currentStep: Int = 0
    @Published var totalSteps: Int = 4

    private let appSupportDir: String
    private let venvPath: String
    private let pythonPath: String

    private init() {
        let basePath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportDir = basePath.appendingPathComponent("searchy").path
        venvPath = "\(appSupportDir)/venv"
        pythonPath = "\(venvPath)/bin/python3"
    }

    var venvPythonPath: String { pythonPath }
    var appSupportPath: String { appSupportDir }

    func checkSetupStatus() {
        // Check if venv exists and has required packages
        let venvExists = FileManager.default.fileExists(atPath: pythonPath)

        if venvExists {
            // Verify torch is installed
            let checkTask = Process()
            checkTask.executableURL = URL(fileURLWithPath: pythonPath)
            checkTask.arguments = ["-c", "import torch; import transformers; import PIL; import deepface; import Vision; print('ok')"]

            let pipe = Pipe()
            checkTask.standardOutput = pipe
            checkTask.standardError = pipe

            do {
                try checkTask.run()
                checkTask.waitUntilExit()

                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                isSetupComplete = output.contains("ok") && checkTask.terminationStatus == 0

                if isSetupComplete {
                    print("✅ Setup verified - all dependencies installed")
                } else {
                    print("⚠️ Setup incomplete - missing dependencies")
                }
            } catch {
                isSetupComplete = false
                print("⚠️ Setup check failed: \(error)")
            }
        } else {
            isSetupComplete = false
            print("⚠️ Virtual environment not found at \(venvPath)")
        }
    }

    func runSetup() async {
        // Total: 3 setup steps + 14 packages + 1 verify = 18
        await MainActor.run {
            isSettingUp = true
            setupError = nil
            currentStep = 0
            totalSteps = 18
        }

        do {
            // Step 1: Create app support directory
            await updateProgress("Creating application directory...", step: 1)
            try createDirectories()

            // Step 2: Find or install Python
            await updateProgress("Checking for Python...", step: 2)
            var systemPython = findSystemPython()

            if systemPython == nil {
                await updateProgress("Installing Python (this may take a minute)...", step: 2)
                systemPython = try await installPython()
            }

            guard let pythonPath = systemPython else {
                throw SetupError.pythonNotFound
            }
            print("✅ Using Python at: \(pythonPath)")

            // Step 3: Create virtual environment
            await updateProgress("Creating virtual environment...", step: 3)
            try await createVirtualEnvironment(using: pythonPath)

            // Steps 4-17: Install dependencies (14 packages)
            try await installDependencies()

            // Step 18: Verify installation
            await updateProgress("Verifying installation...", step: 18)
            try await verifyInstallation()

            // Done!
            await MainActor.run {
                isSetupComplete = true
                isSettingUp = false
                setupProgress = "Setup complete!"
            }
            print("✅ Setup completed successfully")

        } catch {
            await MainActor.run {
                setupError = error.localizedDescription
                isSettingUp = false
            }
            print("❌ Setup failed: \(error)")
        }
    }

    private func updateProgress(_ message: String, step: Int) async {
        await MainActor.run {
            setupProgress = message
            currentStep = step
        }
        print("📦 [\(step)/\(totalSteps)] \(message)")
    }

    private func createDirectories() throws {
        try FileManager.default.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true)
        let logDir = "\(appSupportDir)/logs"
        try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        print("✅ Created directory: \(appSupportDir)")
    }

    private func appendToSetupLog(_ text: String) {
        let logPath = "\(appSupportDir)/logs/setup.log"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: text.data(using: .utf8))
        }
    }

    private func findSystemPython() -> String? {
        // Check common Python locations
        let pythonPaths = [
            // Prefer specific versions known to work with TensorFlow
            "/opt/homebrew/bin/python3.12",    // Homebrew on Apple Silicon (versioned)
            "/opt/homebrew/bin/python3.11",
            "/usr/local/bin/python3.12",       // Homebrew on Intel (versioned)
            "/usr/local/bin/python3.11",
            "/opt/homebrew/bin/python3",       // Homebrew on Apple Silicon (generic)
            "/usr/local/bin/python3",          // Homebrew on Intel (generic)
            "\(appSupportDir)/python/bin/python3",  // Our installed Python
            "/usr/bin/python3",                // System Python
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3"  // Python.org
        ]

        for path in pythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                // Verify it's a working Python 3.9+
                let task = Process()
                task.executableURL = URL(fileURLWithPath: path)
                task.arguments = ["-c", "import sys; print((3, 9) <= sys.version_info < (3, 14))"]

                let pipe = Pipe()
                task.standardOutput = pipe

                do {
                    try task.run()
                    task.waitUntilExit()
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if output.contains("True") {
                        return path
                    }
                } catch {
                    continue
                }
            }
        }
        return nil
    }

    private func installPython() async throws -> String? {
        // Check if Homebrew is available
        let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            ? "/opt/homebrew/bin/brew"
            : (FileManager.default.fileExists(atPath: "/usr/local/bin/brew") ? "/usr/local/bin/brew" : nil)

        if let brew = brewPath {
            print("📦 Installing Python via Homebrew...")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: brew)
            task.arguments = ["install", "python@3.12"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                // Find the installed Python
                let pythonPath = "/opt/homebrew/bin/python3"
                if FileManager.default.fileExists(atPath: pythonPath) {
                    print("✅ Python installed via Homebrew")
                    return pythonPath
                }
                let pythonPathIntel = "/usr/local/bin/python3"
                if FileManager.default.fileExists(atPath: pythonPathIntel) {
                    return pythonPathIntel
                }
            }
        }

        // Fallback: Download standalone Python using python-build-standalone
        print("📦 Downloading standalone Python...")
        return try await downloadStandalonePython()
    }

    private func downloadStandalonePython() async throws -> String {
        let pythonDir = "\(appSupportDir)/python"
        let pythonBin = "\(pythonDir)/bin/python3"

        // Download Python standalone build for macOS ARM64
        // Using python-build-standalone releases
        let downloadURL = "https://github.com/indygreg/python-build-standalone/releases/download/20241206/cpython-3.12.8+20241206-aarch64-apple-darwin-install_only.tar.gz"

        guard let url = URL(string: downloadURL) else {
            throw SetupError.pythonDownloadFailed
        }

        let tarballPath = "\(appSupportDir)/python.tar.gz"

        // Download
        print("⬇️ Downloading Python (~30MB)...")
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SetupError.pythonDownloadFailed
        }

        // Move to our location
        try? FileManager.default.removeItem(atPath: tarballPath)
        try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: tarballPath))

        // Extract
        print("📦 Extracting Python...")
        let extractTask = Process()
        extractTask.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractTask.arguments = ["-xzf", tarballPath, "-C", appSupportDir]
        extractTask.currentDirectoryURL = URL(fileURLWithPath: appSupportDir)

        try extractTask.run()
        extractTask.waitUntilExit()

        // Cleanup tarball
        try? FileManager.default.removeItem(atPath: tarballPath)

        // The extracted folder is named "python" - verify it exists
        if FileManager.default.fileExists(atPath: pythonBin) {
            print("✅ Standalone Python installed")
            return pythonBin
        }

        throw SetupError.pythonDownloadFailed
    }

    private func verifyInstallation() async throws {
        let checkTask = Process()
        checkTask.executableURL = URL(fileURLWithPath: pythonPath)
        // Verify all critical dependencies including face recognition and OCR
        checkTask.arguments = ["-c", "import torch; import transformers; import PIL; import deepface; import Vision; print('verified')"]

        let pipe = Pipe()
        checkTask.standardOutput = pipe
        checkTask.standardError = pipe

        try checkTask.run()
        checkTask.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if !output.contains("verified") || checkTask.terminationStatus != 0 {
            throw SetupError.verificationFailed
        }
        print("✅ Installation verified")
    }

    private func createVirtualEnvironment(using pythonPath: String) async throws {
        // Remove any existing venv to avoid Python version conflicts
        // (e.g., old 3.14 venv getting overlaid with 3.12 packages)
        if FileManager.default.fileExists(atPath: venvPath) {
            try? FileManager.default.removeItem(atPath: venvPath)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = ["-m", "venv", venvPath]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw SetupError.venvCreationFailed(output)
        }

        print("✅ Virtual environment created at: \(venvPath)")
    }

    private func installDependencies() async throws {
        let pipPath = "\(venvPath)/bin/pip3"

        // Upgrade pip first
        let upgradePip = Process()
        upgradePip.executableURL = URL(fileURLWithPath: pythonPath)
        upgradePip.arguments = ["-m", "pip", "install", "--upgrade", "pip"]
        try upgradePip.run()
        upgradePip.waitUntilExit()

        // Install packages one by one for granular progress
        let packages = [
            "torch",
            "transformers",
            "pillow",
            "numpy",
            "tqdm",
            "watchdog",
            "fastapi",
            "uvicorn",
            "scikit-learn",
            "pyobjc-core",
            "pyobjc-framework-Quartz",
            "pyobjc-framework-Vision",
            "deepface",
            "tf-keras"
        ]

        let totalPackages = packages.count

        for (index, package) in packages.enumerated() {
            let displayIndex = index + 1
            await MainActor.run {
                setupProgress = "Installing \(package) (\(displayIndex) of \(totalPackages))..."
                currentStep = 3 + displayIndex  // Steps 4 through 17
            }
            print("📦 [\(displayIndex)/\(totalPackages)] Installing \(package)...")
            appendToSetupLog("[\(displayIndex)/\(totalPackages)] Installing \(package)...\n")

            let task = Process()
            task.executableURL = URL(fileURLWithPath: pipPath)
            task.arguments = ["install", package]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            var pipOutput = ""
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                if let line = String(data: handle.availableData, encoding: .utf8), !line.isEmpty {
                    pipOutput += line
                    self?.appendToSetupLog(line)
                }
            }

            try task.run()
            task.waitUntilExit()

            pipe.fileHandleForReading.readabilityHandler = nil

            if task.terminationStatus != 0 {
                print("❌ Failed to install \(package)")
                appendToSetupLog("FAILED: \(package)\n\(pipOutput)\n")
                throw SetupError.dependencyInstallFailed(pipOutput)
            }

            print("✅ Installed \(package)")
        }

        print("✅ All dependencies installed")
    }

    enum SetupError: LocalizedError {
        case pythonNotFound
        case pythonDownloadFailed
        case venvCreationFailed(String)
        case dependencyInstallFailed(String)
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .pythonNotFound:
                return "Could not find or install Python 3.9+. Please install Python manually from python.org"
            case .pythonDownloadFailed:
                return "Failed to download Python. Please check your internet connection and try again."
            case .venvCreationFailed(let output):
                return "Failed to create virtual environment: \(output)"
            case .dependencyInstallFailed(let output):
                let lastLines = output.components(separatedBy: "\n").suffix(5).joined(separator: "\n")
                return "Failed to install dependencies.\n\n\(lastLines)"
            case .verificationFailed:
                return "Installation verification failed. Please try again or report this issue."
            }
        }
    }
}

// MARK: - Setup View
struct SetupView: View {
    @ObservedObject var setupManager = SetupManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var pal: AtelierPalette { themeManager.palette }

    private var steps: [(label: String, status: String)] {
        let current = setupManager.currentStep
        let total = setupManager.totalSteps
        let items = [
            "python + virtual environment",
            "AI libraries (PyTorch, etc.)",
            "face recognition + OCR",
            "final checks",
        ]
        return items.enumerated().map { i, label in
            if !setupManager.isSettingUp { return (label, "pending") }
            let stepThreshold = total > 0 ? (Double(i) / Double(items.count)) * Double(total) : Double(i)
            if Double(current) > stepThreshold + Double(total) / Double(items.count) {
                return (label, "done")
            } else if Double(current) > stepThreshold {
                return (label, "active")
            } else {
                return (label, "pending")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Centered logo + title
                VStack(spacing: 16) {
                    // "S" logo
                    Text("S")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(pal.accent)
                                .shadow(color: pal.accent.opacity(0.3), radius: 14, x: 0, y: 8)
                        )

                    // Welcome heading
                    HStack(spacing: 0) {
                        Text("Welcome to ")
                            .font(.system(size: 44, weight: .regular, design: .serif))
                            .foregroundColor(pal.ink)
                        Text("Searchy")
                            .font(.system(size: 44, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(pal.accent)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                    Text("on-device image search \u{00B7} everything stays on your mac")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .italic()
                        .foregroundColor(pal.ink2)
                }
                .padding(.bottom, 36)

                // Progress card
                VStack(alignment: .leading, spacing: 0) {
                    if setupManager.isSettingUp {
                        // Card header
                        HStack(alignment: .firstTextBaseline) {
                            Text("preparing your library")
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .italic()
                                .foregroundColor(pal.ink)
                            Spacer()
                            Text("\(setupManager.currentStep) / \(setupManager.totalSteps)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(pal.ink3)
                        }
                        .padding(.bottom, 14)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(pal.line)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(pal.accent)
                                    .frame(
                                        width: geo.size.width * (Double(setupManager.currentStep) / Double(max(setupManager.totalSteps, 1))),
                                        height: 6
                                    )
                                    .shadow(color: pal.accent.opacity(0.3), radius: 7)
                                    .animation(.easeInOut(duration: 0.3), value: setupManager.currentStep)
                            }
                        }
                        .frame(height: 6)
                        .padding(.bottom, 22)

                        // Step checklist
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                                HStack(alignment: .top, spacing: 12) {
                                    // Circle indicator
                                    ZStack {
                                        Circle()
                                            .fill(step.status == "done" ? pal.accent : Color.clear)
                                            .frame(width: 18, height: 18)
                                        Circle()
                                            .stroke(step.status == "pending" ? pal.ink3 : pal.accent, lineWidth: 1.5)
                                            .frame(width: 18, height: 18)
                                        if step.status == "done" {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        if step.status == "active" {
                                            Circle()
                                                .fill(pal.accent)
                                                .frame(width: 6, height: 6)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.label)
                                            .font(.system(size: 13, weight: step.status == "active" ? .semibold : .regular))
                                            .foregroundColor(pal.ink)
                                        if step.status == "active" {
                                            Text(setupManager.setupProgress)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(pal.ink3)
                                        }
                                    }
                                }
                                .opacity(step.status == "pending" ? 0.45 : 1)
                            }
                        }

                        // Footer
                        Divider()
                            .background(pal.line)
                            .padding(.top, 22)
                            .padding(.bottom, 16)

                        Text("first run takes a few minutes \u{00B7} models will not download again")
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(pal.ink3)
                            .frame(maxWidth: .infinity, alignment: .center)

                    } else if let error = setupManager.setupError {
                        // Error state
                        VStack(spacing: 14) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(DesignSystem.Colors.error)

                            Text("setup failed")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(pal.ink)

                            ScrollView {
                                Text(error)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(pal.ink2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 100)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(pal.line.opacity(0.5))
                            )

                            Button(action: {
                                Task { await setupManager.runSetup() }
                            }) {
                                Text("retry")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(pal.accent))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                    } else {
                        // Initial "set up" state
                        VStack(spacing: 10) {
                            ForEach(Array([
                                ("checkmark.circle", "python + virtual environment"),
                                ("arrow.down.circle", "CLIP model + dependencies (~2 GB)"),
                                ("lock.circle", "everything stays on your mac")
                            ].enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .stroke(pal.ink3, lineWidth: 1.5)
                                            .frame(width: 18, height: 18)
                                    }
                                    Text(item.1)
                                        .font(.system(size: 13))
                                        .foregroundColor(pal.ink2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.bottom, 20)

                        Button(action: {
                            Task { await setupManager.runSetup() }
                        }) {
                            Text("set up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(RoundedRectangle(cornerRadius: 10).fill(pal.accent))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("requires internet")
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .italic()
                            .foregroundColor(pal.ink3)
                            .padding(.top, 8)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(DesignSystem.Colors.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(pal.line, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 8)
            }
            .frame(maxWidth: 560)

            Spacer()

            // Footer
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "\u{2014}")")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(pal.ink3)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 48)
        .frame(width: 620, height: 640)
        .background(pal.paper)
    }
}

// Custom panel that accepts keyboard input
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }
}

class WindowController: NSObject, NSWindowDelegate {
    static let shared = WindowController()
    private var windows: Set<NSWindow> = []
    weak var appDelegate: AppDelegate?

    private override init() {
        super.init()
    }

    func createNewWindow() -> NSWindow {
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Searchy"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        windows.insert(window)
        return window
    }

    func removeWindow(_ window: NSWindow) {
        windows.remove(window)
    }

    // NSWindowDelegate methods
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window is KeyablePanel {
                // This is the spotlight window
                Task { @MainActor in
                    appDelegate?.clearSpotlightWindow()
                }
            } else {
                // This is a regular window (main or additional)
                print("🚪 Regular window closing")
                removeWindow(window)
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window is KeyablePanel {
                // Spotlight window lost focus, close it
                window.orderOut(nil)
                Task { @MainActor in
                    appDelegate?.clearSpotlightWindow()
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private static var _shared: AppDelegate?
    private var serverProcess: Process?
    private var watcherProcesses: [Process] = []
    @MainActor private(set) var serverURL: URL?
    private var assignedPort: Int = 7860
    private var statusItem: NSStatusItem!
    var mainWindow: NSWindow?  // Changed from private to internal so WindowController can access
    private var setupWindow: NSWindow?
    private var spotlightWindow: NSPanel?
    private var spotlightHostingView: NSHostingView<SpotlightSearchView>?
    private var windowController: WindowController
    private var setupObserver: NSObjectProtocol?

    private var eventHotKey: EventHotKey?
    private struct EventHotKey {
        var id: UInt32
        var ref: EventHotKeyRef?
    }

    @MainActor
    static var shared: AppDelegate {
        if let delegate = _shared {
            return delegate
        }
        _shared = NSApp.delegate as? AppDelegate
        return _shared ?? AppDelegate()
    }

    override init() {
        self.windowController = WindowController.shared
        super.init()
        Self._shared = self
        self.windowController.appDelegate = self
    }

    @MainActor
    func clearSpotlightWindow() {
        spotlightWindow = nil
        // Keep spotlightHostingView alive for reuse
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // Hide from Dock, no main window by default

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Use a unique icon - tilted photo/image icon
            if let image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                                   accessibilityDescription: "Searchy") {
                image.isTemplate = true  // Makes it adapt to light/dark mode
                button.image = image
                print("✅ Menu bar icon created successfully with 'photo.on.rectangle.angled'")
            } else {
                print("❌ Failed to create menu bar icon")
            }

            button.target = self
            button.action = #selector(toggleMainWindow)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])  // Handle both left and right clicks
            print("✅ Menu bar button action set to toggleMainWindow")
        } else {
            print("❌ Failed to create status item button")
        }

        // Create menu for right-click
        createStatusItemMenu()

        print("📍 Status item created: \(statusItem != nil ? "YES" : "NO")")

        // Check if setup is needed
        let setupManager = SetupManager.shared
        setupManager.checkSetupStatus()

        print("🔍 isSetupComplete = \(setupManager.isSetupComplete)")

        if setupManager.isSetupComplete {
            // Setup complete - proceed normally
            print("🚀 Calling proceedWithAppLaunch...")
            proceedWithAppLaunch()
            print("✅ proceedWithAppLaunch returned")
        } else {
            // Show setup window
            print("📋 Showing setup window...")
            showSetupWindow()
        }

        registerGlobalHotKey()
    }

    private func showSetupWindow() {
        let setupView = SetupView()
        let hostingView = NSHostingView(rootView: setupView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Searchy Setup"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        setupWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Watch for setup completion
        setupObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SetupComplete"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onSetupComplete()
            }
        }

        // Also observe the SetupManager directly
        Task { @MainActor in
            // Poll for setup completion
            while !SetupManager.shared.isSetupComplete {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            self.onSetupComplete()
        }
    }

    @MainActor
    private func onSetupComplete() {
        print("✅ Setup complete - launching app")

        // Close setup window
        setupWindow?.close()
        setupWindow = nil

        if let observer = setupObserver {
            NotificationCenter.default.removeObserver(observer)
            setupObserver = nil
        }

        // Proceed with normal app launch
        proceedWithAppLaunch()
    }

    private func proceedWithAppLaunch() {
        print("📍 proceedWithAppLaunch started")

        // Create main window programmatically - don't rely on SwiftUI WindowGroup
        print("📍 About to create main window...")
        createMainWindow()
        print("📍 Main window created")

        // Show the window on first launch
        if let window = mainWindow {
            print("📍 About to show window...")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ Main window shown")
        } else {
            print("❌ mainWindow is nil!")
        }

        print("✅ Main window configured")

        Task {
            await startFastAPIServer()
            await syncDirectoriesOnStartup()
            await startImageWatcher()
        }
    }

    @MainActor
    private func syncDirectoriesOnStartup() async {
        print("🔄 Checking for new images since last run...")

        guard let serverURL = self.serverURL else {
            print("❌ Server URL not available for sync")
            return
        }

        let dirManager = DirectoryManager.shared
        let indexingSettings = IndexingSettings.shared
        let setupManager = SetupManager.shared

        // Build the sync request
        let directories = dirManager.watchedDirectories.map { dir -> [String: Any] in
            var filterType = "all"
            switch dir.filterType {
            case .all: filterType = "all"
            case .startsWith: filterType = "starts-with"
            case .endsWith: filterType = "ends-with"
            case .contains: filterType = "contains"
            case .regex: filterType = "regex"
            }
            return [
                "path": dir.path,
                "filter_type": filterType,
                "filter_value": dir.filter
            ]
        }

        let requestBody: [String: Any] = [
            "data_dir": setupManager.appSupportPath,
            "directories": directories,
            "fast_indexing": indexingSettings.enableFastIndexing,
            "max_dimension": indexingSettings.maxDimension,
            "batch_size": indexingSettings.batchSize
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Failed to serialize sync request")
            return
        }

        let url = serverURL.appendingPathComponent("sync")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let status = json["status"] as? String ?? "unknown"
                    let newImages = json["new_images"] as? Int ?? 0
                    let cleanedUp = json["cleaned_up"] as? Int ?? 0

                    if cleanedUp > 0 {
                        print("🗑️ Startup sync: removed \(cleanedUp) deleted images from index")
                    }

                    if status == "started" {
                        print("✅ Startup sync: indexing \(newImages) new images in background")
                    } else if status == "no_new_images" {
                        print("✅ Startup sync: all images already indexed")
                    } else {
                        print("ℹ️ Startup sync status: \(status)")
                    }
                }
            } else {
                print("⚠️ Sync request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            print("❌ Startup sync error: \(error.localizedDescription)")
        }
    }

    private func createStatusItemMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Open Searchy", action: #selector(toggleMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Searchy", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Searchy", action: #selector(quitApp), keyEquivalent: "q"))

        // Store menu but don't set it yet - we'll show it on right-click
        statusItem.menu = menu
    }

    @objc private func showAbout() {
        AtelierAboutWindow.show()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func createMainWindow() {
        print("📍 createMainWindow: Creating ContentView...")
        let contentView = ContentView()
        print("📍 createMainWindow: ContentView created, creating NSHostingView...")
        let hostingView = NSHostingView(rootView: contentView)
        print("📍 createMainWindow: NSHostingView created, creating NSWindow...")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Searchy"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = windowController

        mainWindow = window
        print("📍 createMainWindow: Window configured")
        print("✅ Created main window programmatically")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Kill server synchronously
        if let proc = serverProcess, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        serverProcess = nil

        // Kill all watchers synchronously
        for proc in watcherProcesses {
            if proc.isRunning {
                proc.terminate()
                proc.waitUntilExit()
            }
        }
        watcherProcesses.removeAll()

        if let hotKey = eventHotKey?.ref {
            UnregisterEventHotKey(hotKey)
        }
    }
    
    @objc private func toggleMainWindow() {
        print("🖱️ Menu bar icon clicked - toggleMainWindow called")

        if let window = mainWindow {
            print("📝 Main window exists, isVisible: \(window.isVisible)")
            if window.isVisible {
                print("🙈 Hiding main window")
                window.orderOut(nil)
            } else {
                print("👁️ Showing main window")

                // Set proper window size before showing
                let frame = NSRect(x: 0, y: 0, width: 900, height: 700)
                window.setFrame(frame, display: false)
                window.center()

                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)

                print("✅ Window shown, total windows: \(NSApplication.shared.windows.count)")
            }
        } else {
            print("⚠️ Main window is nil!")
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    private func bringAppToFront() {
        Task { @MainActor in
            showSpotlightWindow()
        }
    }

    @MainActor
    private func showSpotlightWindow() {
        // Capture the currently active app BEFORE we show our window
        let previousApp = NSWorkspace.shared.runningApplications
            .first(where: { $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier })

        if let app = previousApp {
            print("💾 Captured previous app: \(app.localizedName ?? "Unknown")")
        } else {
            print("⚠️ Could not capture previous app")
        }

        // If window already exists, update it and show it
        if let existingWindow = spotlightWindow {
            // Update the view with the new previous app
            let contentView = SpotlightSearchView(previousApp: previousApp)
            spotlightHostingView = NSHostingView(rootView: contentView)
            existingWindow.contentView = spotlightHostingView

            // Reset window size
            existingWindow.setFrame(NSRect(x: 0, y: 0, width: 650, height: 500), display: false)
            existingWindow.center()
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create hosting view with the previous app
        let contentView = SpotlightSearchView(previousApp: previousApp)
        spotlightHostingView = NSHostingView(rootView: contentView)

        guard let hostingView = spotlightHostingView else { return }

        // Create custom keyable window
        let window = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.animationBehavior = .alertPanel
        window.acceptsMouseMovedEvents = true
        window.hidesOnDeactivate = false

        // Handle window closing
        window.delegate = windowController

        spotlightWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Force focus with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            window.makeKey()
        }
    }
    
    private func registerGlobalHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType("SRCH".utf16.reduce(0, { ($0 << 8) + UInt32($1) })), id: 1)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, _) -> OSStatus in
            let appDelegate = AppDelegate.shared
            DispatchQueue.main.async {
                appDelegate.bringAppToFront()
            }
            return noErr
        }, 1, &eventType, nil, nil)
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(kVK_Space),
                                       UInt32(cmdKey | shiftKey),
                                       hotKeyID,
                                       GetApplicationEventTarget(),
                                       0,
                                       &hotKeyRef)
        
        if status == noErr {
            eventHotKey = EventHotKey(id: hotKeyID.id, ref: hotKeyRef)
            print("Hot key registered successfully")
        } else {
            print("Failed to register hot key")
        }
    }
    
    private func isPortInUse(port: Int) -> Bool {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i:\(port)"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            return output?.contains("LISTEN") ?? false
        } catch {
            print("Failed to check port usage: \(error.localizedDescription)")
            return false
        }
    }
    
    private func findAvailablePort(startingFrom basePort: Int, maxRetries: Int = 100) -> Int {
        var port = basePort
        var retries = 0
        
        while isPortInUse(port: port) {
            port += 1
            retries += 1
            if retries >= maxRetries {
                fatalError("No available port found.")
            }
        }
        print("Using port: \(port)")
        return port
    }
    
    @MainActor
    private func startFastAPIServer() async {
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killTask.arguments = ["-f", "server.py"]
        try? killTask.run()
        killTask.waitUntilExit()

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        assignedPort = findAvailablePort(startingFrom: 7860)
        serverURL = URL(string: "http://127.0.0.1:\(assignedPort)")

        guard let serverURL = self.serverURL else {
            print("Error: Unable to determine server URL.")
            return
        }

        // Use venv from Application Support (created during setup)
        let setupManager = SetupManager.shared
        let pythonPath = setupManager.venvPythonPath

        // Get server script from app bundle Resources
        guard let serverScript = Bundle.main.path(forResource: "server", ofType: "py") else {
            print("❌ Could not find server.py in app bundle")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [serverScript, "--port", "\(assignedPort)"]

        // Set PYTHONPATH to include the Resources directory so imports work
        let resourcesPath = Bundle.main.resourcePath ?? ""
        process.environment = [
            "PYTHONPATH": resourcesPath,
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: resourcesPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Persist Python server output to log file
        let logDir = "\(SetupManager.shared.appSupportPath)/logs"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        let logPath = "\(logDir)/server_stdout.log"
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let logHandle = FileHandle(forWritingAtPath: logPath)
        logHandle?.seekToEndOfFile()

        pipe.fileHandleForReading.readabilityHandler = { [weak logHandle] fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("FastAPI Output: \(output)")
            }
            logHandle?.write(data)
        }

        process.terminationHandler = { _ in
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        do {
            try process.run()
            serverProcess = process
            print("FastAPI server started successfully on port \(assignedPort).")
        } catch {
            print("Failed to start FastAPI server: \(error.localizedDescription)")
            return
        }
        
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
        
        do {
            try await waitForServerReady()
            print("FastAPI server is ready at \(serverURL).")
            // Reload face data now that server is ready
            await FaceManager.shared.loadClustersFromAPI()
            await FaceManager.shared.checkForNewImages()
        } catch {
            print("Failed to connect to FastAPI server: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func stopFastAPIServer() async {
        guard let serverProcess = serverProcess else {
            print("No server process to stop.")
            return
        }
        
        if serverProcess.isRunning {
            print("Terminating FastAPI server process.")
            serverProcess.terminate()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        } else {
            print("Server process is not running.")
        }
        
        serverProcess.terminationHandler = nil
        self.serverProcess = nil
        print("FastAPI server stopped.")
    }
    
    private func waitForServerReady() async throws {
        let maxRetries = 15
        var delay: UInt64 = 3_000_000_000 // 3 seconds

        for attempt in 1...maxRetries {
            do {
                guard let serverURL = await self.serverURL else {
                    throw URLError(.badURL)
                }
                let url = serverURL.appendingPathComponent("status")
                let (_, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("Server is ready")
                        return
                    }
                }
            } catch {
                print("Retry \(attempt): Server not ready. Error: \(error)")
            }

            try await Task.sleep(nanoseconds: delay)
            delay *= 2
        }

        throw URLError(.cannotConnectToHost)
    }

    @MainActor
    private func startImageWatcher() async {
        let indexingSettings = IndexingSettings.shared
        let dirManager = DirectoryManager.shared
        let setupManager = SetupManager.shared
        let dataDir = setupManager.appSupportPath

        let pythonPath = setupManager.venvPythonPath

        // Get watcher script from app bundle Resources
        guard let watcherScript = Bundle.main.path(forResource: "image_watcher", ofType: "py") else {
            print("❌ Could not find image_watcher.py in app bundle")
            return
        }

        // Start a watcher for each watched directory
        for directory in dirManager.watchedDirectories {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)

            // Build arguments with all settings
            var arguments = [
                watcherScript,
                directory.path,
                dataDir,
                "--server-url", "http://127.0.0.1:\(assignedPort)",
                "--max-dimension", String(indexingSettings.maxDimension),
                "--batch-size", String(indexingSettings.batchSize)
            ]

            // Add fast indexing flag
            if indexingSettings.enableFastIndexing {
                arguments.append("--fast")
            } else {
                arguments.append("--no-fast")
            }

            // Add filter if set
            if !directory.filter.isEmpty && directory.filterType != .all {
                let filterTypeArg = directory.filterType.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
                arguments.append(contentsOf: ["--filter-type", filterTypeArg, "--filter", directory.filter])
            }

            process.arguments = arguments

            // Set PYTHONPATH to include the Resources directory so imports work
            let resourcesPath = Bundle.main.resourcePath ?? ""
            process.environment = [
                "PYTHONPATH": resourcesPath,
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            ]
            process.currentDirectoryURL = URL(fileURLWithPath: resourcesPath)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let dirName = directory.path.components(separatedBy: "/").last ?? directory.path
            pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                if let output = String(data: fileHandle.availableData, encoding: .utf8), !output.isEmpty {
                    print("[\(dirName)] \(output)")
                }
            }

            process.terminationHandler = { _ in
                pipe.fileHandleForReading.readabilityHandler = nil
            }

            do {
                try process.run()
                watcherProcesses.append(process)
                let filterInfo = directory.filterDescription ?? "all files"
                print("✅ Image watcher started for \(dirName) (\(filterInfo))")
            } catch {
                print("❌ Failed to start watcher for \(dirName): \(error.localizedDescription)")
            }
        }

        if watcherProcesses.isEmpty {
            print("⚠️ No image watchers started - check watched directories in Settings")
        } else {
            print("✅ Started \(watcherProcesses.count) image watcher(s)")
        }
    }

    @MainActor
    private func stopImageWatcher() async {
        guard !watcherProcesses.isEmpty else {
            return
        }

        print("⏹️  Stopping \(watcherProcesses.count) image watcher(s)...")

        for process in watcherProcesses {
            if process.isRunning {
                process.terminate()
            }
            process.terminationHandler = nil
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        watcherProcesses.removeAll()
        print("✅ All image watchers stopped")
    }
}

@main
struct SearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Prevent automatic window restoration
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    var body: some Scene {
        // Use Settings instead of WindowGroup to prevent auto-window creation
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Searchy") {
                    AtelierAboutWindow.show()
                }
            }

            CommandGroup(after: .appInfo) {
                Divider()
                Button("Quit Searchy") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

// MARK: - Atelier About Window
class AtelierAboutWindow {
    static var window: NSWindow?

    static func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let aboutView = AtelierAboutView()
        let hostingView = NSHostingView(rootView: aboutView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "About Searchy"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        window = w
    }
}

struct AtelierAboutView: View {
    private var pal: AtelierPalette { ThemeManager.shared.palette }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4.2"
    }

    var body: some View {
        ZStack {
            pal.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(pal.accent)
                        .frame(width: 80, height: 80)
                        .shadow(color: pal.accent.opacity(0.3), radius: 20, y: 8)
                    Text("S")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer().frame(height: 24)

                // Title
                Text("Searchy")
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .foregroundColor(pal.ink)

                Spacer().frame(height: 6)

                Text("Visual search for your photo library")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink2)

                Spacer().frame(height: 20)

                // Version pill
                HStack(spacing: 8) {
                    Text("v\(version)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(pal.accent)
                    Circle()
                        .fill(pal.line)
                        .frame(width: 3, height: 3)
                    Text("CLIP-powered")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(pal.ink3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(pal.card)
                        .overlay(Capsule().stroke(pal.line, lineWidth: 0.5))
                )

                Spacer().frame(height: 32)

                // Info grid
                VStack(spacing: 0) {
                    aboutInfoRow(label: "Built with", value: "SwiftUI + Python")
                    Rectangle().fill(pal.line).frame(height: 0.5).padding(.horizontal, 16)
                    aboutInfoRow(label: "Model", value: ModelSettings.shared.currentModelName.components(separatedBy: "/").last ?? "CLIP")
                    Rectangle().fill(pal.line).frame(height: 0.5).padding(.horizontal, 16)
                    aboutInfoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(pal.card)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.line, lineWidth: 0.5))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 40)

                Spacer()

                // Footer
                Text("Made with care")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(pal.ink3)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 420, height: 480)
    }

    private func aboutInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(pal.ink2)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(pal.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
