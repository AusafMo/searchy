import Foundation
import AppKit
import SwiftUI
import Carbon

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
    private var watcherProcess: Process?
    @MainActor private(set) var serverURL: URL?
    private var assignedPort: Int = 7860
    private var statusItem: NSStatusItem!
    var mainWindow: NSWindow?  // Changed from private to internal so WindowController can access
    private var spotlightWindow: NSPanel?
    private var spotlightHostingView: NSHostingView<SpotlightSearchView>?
    private var windowController: WindowController

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

        // Create main window programmatically - don't rely on SwiftUI WindowGroup
        createMainWindow()

        print("✅ Main window configured")

        Task {
            await startFastAPIServer()
            await startImageWatcher()
        }
        registerGlobalHotKey()
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
        
        let pythonPath = "/Users/ausaf/Desktop/searchy/.venv/bin/python3"
        let serverScript = "/Users/ausaf/Desktop/searchy/searchy/server.py"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [serverScript, "--port", "\(assignedPort)"]
        
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
        let watchDir = NSString(string: "~/Downloads").expandingTildeInPath
        let dataDir = NSString(string: "~/Library/Application Support/searchy").expandingTildeInPath

        let pythonPath = "/Users/ausaf/Desktop/searchy/.venv/bin/python3"
        let watcherScript = "/Users/ausaf/Desktop/searchy/searchy/image_watcher.py"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [watcherScript, watchDir, dataDir]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            if let output = String(data: fileHandle.availableData, encoding: .utf8), !output.isEmpty {
                print("Image Watcher: \(output)")
            }
        }

        do {
            try process.run()
            watcherProcess = process
            print("✅ Image watcher started - monitoring ~/Downloads for new images")
        } catch {
            print("❌ Failed to start image watcher: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func stopImageWatcher() async {
        guard let watcherProcess = watcherProcess else {
            return
        }

        if watcherProcess.isRunning {
            print("⏹️  Stopping image watcher...")
            watcherProcess.terminate()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        watcherProcess.terminationHandler = nil
        self.watcherProcess = nil
        print("✅ Image watcher stopped")
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
