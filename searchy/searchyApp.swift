import Foundation
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private static var _shared: AppDelegate?
    
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
    
    private var serverProcess: Process?
    @MainActor private(set) var serverURL: URL?
    private var assignedPort: Int = 7860
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await startFastAPIServer()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await stopFastAPIServer()
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
        return port
    }
    
    @MainActor
    private func startFastAPIServer() async {
        // Kill any existing Python processes
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killTask.arguments = ["-f", "server.py"]
        try? killTask.run()
        killTask.waitUntilExit()
        
        // Wait a moment for ports to clear
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Set port first
        assignedPort = 7860  // Use a fixed port instead of finding available
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
        
        // Increase initial delay before checking server
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

@main
struct SearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
