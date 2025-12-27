//
//  PythonBridge.swift
//  Mneme
//
//  Communication bridge between Swift and Python backend
//

import Foundation
import Combine

/// Errors that can occur during Python bridge operations
enum PythonBridgeError: LocalizedError {
    case processNotRunning
    case encodingError
    case decodingError(String)
    case backendError(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .processNotRunning:
            return "Python backend is not running"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .backendError(let message):
            return "Backend error: \(message)"
        case .timeout:
            return "Request timed out"
        }
    }
}

/// Response from the Python backend
struct BridgeResponse: Codable {
    let success: Bool
    let data: AnyCodable?
    let error: String?
    let details: String?
}

/// Wrapper for encoding/decoding arbitrary JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
}

/// Manages the Python backend process and communication
@MainActor
class PythonBridge: ObservableObject {
    static let shared = PythonBridge()
    
    @Published var isRunning = false
    @Published var lastError: String?
    
    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var outputBuffer = ""
    private var pendingRequests: [UUID: CheckedContinuation<[String: Any], Error>] = [:]
    
    private let pythonPath: String
    private let bridgePath: String
    
    private init() {
        // Locate Python and bridge script
        let bundle = Bundle.main
        let resourcePath = bundle.resourcePath ?? ""
        
        // In development, use the Backend folder
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        
        bridgePath = "\(projectPath)/Backend/bridge.py"
        
        // Try to find Python 3
        if FileManager.default.fileExists(atPath: "/usr/local/bin/python3") {
            pythonPath = "/usr/local/bin/python3"
        } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/python3") {
            pythonPath = "/opt/homebrew/bin/python3"
        } else {
            pythonPath = "/usr/bin/python3"
        }
    }
    
    /// Start the Python backend process
    func start() async throws {
        guard !isRunning else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [bridgePath]
        process.currentDirectoryURL = URL(fileURLWithPath: bridgePath).deletingLastPathComponent()
        
        // Set up environment for the virtual environment if it exists
        var env = ProcessInfo.processInfo.environment
        let venvPath = URL(fileURLWithPath: bridgePath)
            .deletingLastPathComponent()
            .appendingPathComponent("venv")
            .path
        
        if FileManager.default.fileExists(atPath: venvPath) {
            env["PATH"] = "\(venvPath)/bin:" + (env["PATH"] ?? "")
            env["VIRTUAL_ENV"] = venvPath
            process.executableURL = URL(fileURLWithPath: "\(venvPath)/bin/python3")
        }
        process.environment = env
        
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        stdin = stdinPipe.fileHandleForWriting
        stdout = stdoutPipe.fileHandleForReading
        
        // Handle stdout data
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.handleOutput(output)
                }
            }
        }
        
        // Handle stderr for debugging
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let error = String(data: data, encoding: .utf8), !error.isEmpty {
                print("Python stderr: \(error)")
            }
        }
        
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
            }
        }
        
        do {
            try process.run()
            self.process = process
            self.isRunning = true
            
            // Wait for ready signal
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Stop the Python backend process
    func stop() {
        process?.terminate()
        process = nil
        stdin = nil
        stdout = nil
        isRunning = false
    }
    
    /// Send a request to the Python backend
    func request(_ action: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        guard isRunning, let stdin = stdin else {
            throw PythonBridgeError.processNotRunning
        }
        
        let requestDict: [String: Any] = [
            "action": action,
            "params": params
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict),
              var jsonString = String(data: jsonData, encoding: .utf8) else {
            throw PythonBridgeError.encodingError
        }
        
        jsonString += "\n"
        
        guard let data = jsonString.data(using: .utf8) else {
            throw PythonBridgeError.encodingError
        }
        
        // Send request
        try stdin.write(contentsOf: data)
        
        // Wait for response with timeout
        return try await withCheckedThrowingContinuation { continuation in
            let id = UUID()
            pendingRequests[id] = continuation
            
            // Timeout after 30 seconds
            Task {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                if let cont = pendingRequests.removeValue(forKey: id) {
                    cont.resume(throwing: PythonBridgeError.timeout)
                }
            }
        }
    }
    
    private func handleOutput(_ output: String) {
        outputBuffer += output
        
        // Process complete lines
        while let newlineIndex = outputBuffer.firstIndex(of: "\n") {
            let line = String(outputBuffer[..<newlineIndex])
            outputBuffer = String(outputBuffer[outputBuffer.index(after: newlineIndex)...])
            
            guard !line.isEmpty else { continue }
            
            // Parse JSON response
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Handle ready signal
                if json["ready"] as? Bool == true {
                    continue
                }
                
                // Handle response
                if let (id, continuation) = pendingRequests.first {
                    pendingRequests.removeValue(forKey: id)
                    
                    if let success = json["success"] as? Bool, success {
                        if let responseData = json["data"] as? [String: Any] {
                            continuation.resume(returning: responseData)
                        } else {
                            continuation.resume(returning: [:])
                        }
                    } else {
                        let error = json["error"] as? String ?? "Unknown error"
                        continuation.resume(throwing: PythonBridgeError.backendError(error))
                    }
                }
            }
        }
    }
}

