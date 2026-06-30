//
//  ChatAPIService.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

final class ChatAPIService {
    
    static let shared = ChatAPIService()
    
    private init() {}
    
    func sendMessage(
        vehicleId: Int,
        message: String,
        token: String
    ) async throws -> ChatResponse {
        let url = APIConfig.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("vehicles")
            .appendingPathComponent(String(vehicleId))
            .appendingPathComponent("chat")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ChatMessageRequest(message: message)
        request.httpBody = try JSONEncoder().encode(body)
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.noInternet
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("CHAT REQUEST: POST \(url)")
        print("CHAT STATUS CODE:", httpResponse.statusCode)
        print("CHAT RAW RESPONSE:", String(data: data, encoding: .utf8) ?? "")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Something went wrong"
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(ChatResponse.self, from: data)
    }
    
    func getHistory(vehicleId: Int, token: String) async throws -> [ChatMessageResponse] {
        var components = URLComponents(
            url: APIConfig.baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("vehicles")
                .appendingPathComponent(String(vehicleId))
                .appendingPathComponent("chat")
                .appendingPathComponent("history"),
            resolvingAgainstBaseURL: false
        )
        
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "offset", value: "0")
        ]
        
        guard let url = components?.url else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.noInternet
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("CHAT HISTORY REQUEST: GET \(url)")
        print("CHAT HISTORY STATUS CODE:", httpResponse.statusCode)
        print("CHAT HISTORY RAW RESPONSE:", String(data: data, encoding: .utf8) ?? "")
        
        if httpResponse.statusCode == 404 {
            return []
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Something went wrong"
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let responseBody = try decoder.decode(ChatHistoryResponse.self, from: data)
        return responseBody.messages
    }
}
