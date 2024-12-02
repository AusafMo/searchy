import Foundation
import AppKit
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private static var _shared: AppDelegate?
    private var serverProcess: Process?
    @MainActor private(set) var serverURL: URL?
    private var assignedPort: Int = 7860
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    
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
        super.init()
        Self._shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Initialize status bar with custom length and position
        statusItem = NSStatusBar.system.statusItem(withLength: 24.0) // Set specific width
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.stack",
                                 accessibilityDescription: "Searchy")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
            
            // Center the image in the button
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            
            button.target = self
            button.action = #selector(toggleMainWindow)
        }
        
        setupMainWindow()
        
        Task {
            await startFastAPIServer()
        }
        registerGlobalHotKey()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await stopFastAPIServer()
        }
        
        if let hotKey = eventHotKey?.ref {
            UnregisterEventHotKey(hotKey)
        }
    }
    
    private func setupMainWindow() {
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Searchy"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        self.mainWindow = window
    }
    
    @objc private func toggleMainWindow() {
        if let window = mainWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func bringAppToFront() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        print(port)
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
            delay *= 2 // Exponential backoff
        }
        
        throw URLError(.cannotConnectToHost)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.orderOut(nil)
        }
    }
}

@main
struct SearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
