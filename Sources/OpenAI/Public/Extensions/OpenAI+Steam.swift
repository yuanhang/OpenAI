//
//  File.swift
//  
//
//  Created by Yuanhang Guo on 2/11/23.
//

import Foundation

public enum OpenAIError: Equatable, Sendable, LocalizedError {
    case invalidServerResponse
}

@available(iOS 15.0, *)
extension OpenAI {
    func performStreamRequest<ResultType: Codable>(request: Request<ResultType>) async throws -> AsyncStream<CompletionsResult> {
        let request = try makeRequest(query: request.body, url: request.url, timeoutInterval: request.timeoutInterval)
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidURL
        }
        
        return AsyncStream(CompletionsResult.self, bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for try await line in asyncBytes.lines {
                    let json = String(line.dropFirst(6))
                    if json == "[DONE]" {
                        break
                    }
                    continuation.yield(try JSONDecoder().decode(CompletionsResult.self, from: Data(json.utf8)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
