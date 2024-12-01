import SwiftUI
import Foundation

@main
struct SearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    private var serverProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startFastAPIServer()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await cleanupBeforeExit()
        }
    }
    private func cleanupBeforeExit() async {
        await stopFastAPIServer()
    }
    private func killProcessOnPort(port: Int) {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-ti:\(port)"]
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let pidOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let pid = pidOutput, !pid.isEmpty {
                let killTask = Process()
                killTask.executableURL = URL(fileURLWithPath: "/bin/kill")
                killTask.arguments = ["-9", pid]
                try killTask.run()
                killTask.waitUntilExit()
                print("Killed process on port \(port).")
            } else {
                print("No process found on port \(port).")
            }
        } catch {
            print("Failed to kill process on port \(port): \(error.localizedDescription)")
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

    private func startFastAPIServer() {
        if isPortInUse(port: 7860) {
            print("Port 7860 is already in use. Killing process.")
            killProcessOnPort(port: 7860)
        }

        if isPortInUse(port: 7860) {
            print("Port 7860 is still in use after attempting to kill the process. Skipping server start.")
            return
        }

        let pythonPath = "/Users/ausaf/Desktop/searchy/.venv/bin/python3"
        let serverScript = "/Users/ausaf/Desktop/searchy/searchy/server.py"

        serverProcess = Process()
        serverProcess?.executableURL = URL(fileURLWithPath: pythonPath)
        serverProcess?.arguments = [serverScript]

        let pipe = Pipe()
        serverProcess?.standardOutput = pipe
        serverProcess?.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            if let output = String(data: fileHandle.availableData, encoding: .utf8), !output.isEmpty {
                print("FastAPI Output: \(output)")
            }
        }

        do {
            try serverProcess?.run()
            print("FastAPI server started successfully.")
        } catch {
            print("Failed to start FastAPI server: \(error.localizedDescription)")
            return
        }

        Task {
            do {
                try await waitForServerReady()
                print("FastAPI server is ready.")
            } catch {
                print("Failed to connect to FastAPI server: \(error.localizedDescription)")
            }
        }
    }

    private func stopFastAPIServer() {
        guard let serverProcess = serverProcess else {
            print("No server process to stop.")
            return
        }

        if serverProcess.isRunning {
            print("Terminating FastAPI server process.")
            serverProcess.terminate()
            serverProcess.waitUntilExit()
        } else {
            print("Server process is not running.")
        }

        serverProcess.terminationHandler = nil // Remove any handlers
        self.serverProcess = nil
        print("FastAPI server stopped.")
    }

    private func waitForServerReady() async throws {
        let maxRetries = 10
        var delay: UInt64 = 1_000_000_000

        for attempt in 1...maxRetries {
            do {
                let url = URL(string: "http://127.0.0.1:7860/status")!
                let (_, response) = try await URLSession.shared.data(for: URLRequest(url: url))
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    return
                }
            } catch {
                print("Retry \(attempt): Server not ready")
            }

            try await Task.sleep(nanoseconds: delay)
            delay *= 2
        }
        throw URLError(.cannotConnectToHost)
    }
}
