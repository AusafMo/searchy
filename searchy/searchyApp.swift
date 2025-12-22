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
            checkTask.arguments = ["-c", "import torch; import transformers; print('ok')"]

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
        await MainActor.run {
            isSettingUp = true
            setupError = nil
            currentStep = 0
            totalSteps = 5
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

            // Step 4: Install dependencies
            await updateProgress("Installing AI dependencies (this may take a few minutes)...", step: 4)
            try await installDependencies()

            // Step 5: Verify installation
            await updateProgress("Verifying installation...", step: 5)
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
        print("✅ Created directory: \(appSupportDir)")
    }

    private func findSystemPython() -> String? {
        // Check common Python locations
        let pythonPaths = [
            "/opt/homebrew/bin/python3",      // Homebrew on Apple Silicon
            "/usr/local/bin/python3",          // Homebrew on Intel
            "\(appSupportDir)/python/bin/python3",  // Our installed Python
            "/usr/bin/python3",                // System Python
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3"  // Python.org
        ]

        for path in pythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                // Verify it's a working Python 3.9+
                let task = Process()
                task.executableURL = URL(fileURLWithPath: path)
                task.arguments = ["-c", "import sys; print(sys.version_info >= (3, 9))"]

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
        checkTask.arguments = ["-c", "import torch; import transformers; import PIL; print('verified')"]

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

        // Install packages
        let packages = [
            "torch",
            "transformers",
            "pillow",
            "numpy",
            "tqdm",
            "watchdog",
            "fastapi",
            "uvicorn"
        ]

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pipPath)
        task.arguments = ["install"] + packages

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        // Stream output for progress
        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let line = String(data: handle.availableData, encoding: .utf8), !line.isEmpty {
                print("pip: \(line)")
            }
        }

        try task.run()
        task.waitUntilExit()

        pipe.fileHandleForReading.readabilityHandler = nil

        if task.terminationStatus != 0 {
            throw SetupError.dependencyInstallFailed
        }

        print("✅ All dependencies installed")
    }

    enum SetupError: LocalizedError {
        case pythonNotFound
        case pythonDownloadFailed
        case venvCreationFailed(String)
        case dependencyInstallFailed
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .pythonNotFound:
                return "Could not find or install Python 3.9+. Please install Python manually from python.org"
            case .pythonDownloadFailed:
                return "Failed to download Python. Please check your internet connection and try again."
            case .venvCreationFailed(let output):
                return "Failed to create virtual environment: \(output)"
            case .dependencyInstallFailed:
                return "Failed to install dependencies. Please check your internet connection and try again."
            case .verificationFailed:
                return "Installation verification failed. Please try again or report this issue."
            }
        }
    }
}

// MARK: - Setup View
struct SetupView: View {
    @ObservedObject var setupManager = SetupManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 40)

            // Title
            Text("Welcome to Searchy")
                .font(.system(size: 28, weight: .bold))

            Text("AI-powered image search for your Mac")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            Spacer()

            if setupManager.isSettingUp {
                // Progress view
                VStack(spacing: 20) {
                    ProgressView(value: Double(setupManager.currentStep), total: Double(setupManager.totalSteps))
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 300)

                    Text(setupManager.setupProgress)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if setupManager.currentStep == 4 {
                        Text("This may take 2-5 minutes on first run...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

            } else if let error = setupManager.setupError {
                // Error view
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("Setup Failed")
                        .font(.headline)

                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Try Again") {
                        Task {
                            await setupManager.runSetup()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            } else {
                // Initial setup prompt
                VStack(spacing: 16) {
                    Text("First-time setup required")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        SetupStepRow(number: 1, text: "Install Python (if needed)")
                        SetupStepRow(number: 2, text: "Create isolated environment")
                        SetupStepRow(number: 3, text: "Download AI models (~2GB)")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )

                    Text("Requires internet connection")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Button(action: {
                        Task {
                            await setupManager.runSetup()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Start Setup")
                        }
                        .frame(width: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)
                }
            }

            Spacer()

            // Footer
            Text("All processing happens on-device. No data leaves your Mac.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(width: 450, height: 500)
        .background(colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color.white)
    }
}

struct SetupStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.purple.opacity(0.8)))

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
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

        if setupManager.isSetupComplete {
            // Setup complete - proceed normally
            proceedWithAppLaunch()
        } else {
            // Show setup window
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
            self?.onSetupComplete()
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
        // Create main window programmatically - don't rely on SwiftUI WindowGroup
        createMainWindow()

        print("✅ Main window configured")

        Task {
            await startFastAPIServer()
            await startImageWatcher()
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
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.applicationName: "Searchy",
            NSApplication.AboutPanelOptionKey.applicationVersion: "3.0",
            NSApplication.AboutPanelOptionKey.version: "3.0"
        ])
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func createMainWindow() {
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Searchy"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = windowController

        mainWindow = window
        print("✅ Created main window programmatically")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await stopFastAPIServer()
            await stopImageWatcher()
        }

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
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            if let output = String(data: fileHandle.availableData, encoding: .utf8), !output.isEmpty {
                print("FastAPI Output: \(output)")
            }
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
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        NSApplication.AboutPanelOptionKey.applicationName: "Searchy",
                        NSApplication.AboutPanelOptionKey.applicationVersion: "3.0",
                        NSApplication.AboutPanelOptionKey.version: "3.0"
                    ])
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
