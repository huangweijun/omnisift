#!/usr/bin/env swift

import Foundation

// Test downloading a file from HuggingFace with URLSession
let urlString = "https://huggingface.co/mlboydaisuke/gemma-4-E2B-coreml/resolve/n1024/model_config.json"
let outputPath = "/tmp/omnisift_download_test.json"

print("Testing download from: \(urlString)")

let semaphore = DispatchSemaphore(value: 0)

Task {
    do {
        guard let url = URL(string: urlString) else {
            print("ERROR: Invalid URL")
            semaphore.signal()
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)

        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("ERROR: Not HTTP response")
            semaphore.signal()
            return
        }

        print("HTTP Status: \(httpResponse.statusCode)")
        print("Content-Length: \(httpResponse.expectedContentLength)")

        // Stream to file
        let fm = FileManager.default
        if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
        }
        fm.createFile(atPath: outputPath, contents: nil)

        guard let fileHandle = FileHandle(forWritingAtPath: outputPath) else {
            print("ERROR: Cannot open file for writing")
            semaphore.signal()
            return
        }

        var buffer = Data()
        var totalBytes: Int64 = 0

        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count >= 4096 {
                fileHandle.write(buffer)
                totalBytes += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
            }
        }

        if !buffer.isEmpty {
            fileHandle.write(buffer)
            totalBytes += Int64(buffer.count)
        }
        fileHandle.closeFile()

        print("SUCCESS: Downloaded \(totalBytes) bytes to \(outputPath)")

        // Verify content
        if let content = try? String(contentsOfFile: outputPath, encoding: .utf8) {
            print("Content preview: \(String(content.prefix(100)))")
        }

        session.invalidateAndCancel()
    } catch {
        print("ERROR: \(error)")
    }
    semaphore.signal()
}

semaphore.wait()
print("Done.")
