//
//  AuthAPIService.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingError
    case responseDecodingError(message: String?)
    case noInternet
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Something went wrong. Please try again."
            
        case .serverError(let statusCode, let message):
            if let message, !message.isEmpty {
                return cleanBackendMessage(message)
            }
            
            switch statusCode {
            case 400:
                return "Please check your email and password."
            case 401:
                return "Incorrect email or password."
            case 409:
                return "An account with this email already exists."
            case 500...599:
                return "Server is temporarily unavailable. Please try again later."
            default:
                return "Something went wrong. Please try again."
            }
            
        case .decodingError:
            return "Could not read server response."
            
        case .responseDecodingError(let message):
            if let message, !message.isEmpty {
                return "Could not read server response: \(message)"
            }
            
            return "Could not read server response."
            
        case .noInternet:
            return "No internet connection. Please check your network."
            
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
    
    private func cleanBackendMessage(_ message: String) -> String {
        let lowercased = message.lowercased()
        
        if lowercased.contains("already") || lowercased.contains("exists") || lowercased.contains("duplicate") {
            return "An account with this email already exists."
        }
        
        if lowercased.contains("invalid") || lowercased.contains("wrong") || lowercased.contains("unauthorized") {
            return "Incorrect email or password."
        }
        
        if lowercased.contains("password") {
            return "Please check your password."
        }
        
        if lowercased.contains("email") {
            return "Please check your email address."
        }
        
        return "Something went wrong. Please try again."
    }
}

final class AuthAPIService {
    
    static let shared = AuthAPIService()
    
    private init() {}
    
    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws -> AuthResponse {
        let body = RegisterRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        
        return try await sendAuthRequest(
            path: "/api/auth/register",
            body: body
        )
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(
            email: email,
            password: password
        )
        
        return try await sendAuthRequest(
            path: "/api/auth/login",
            body: body
        )
    }
    
    func getCurrentUser(token: String) async throws -> UserResponse {
        let url = APIConfig.baseURL.appending(path: "/api/me")
        
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
        
        guard 200...299 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(UserResponse.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    private func sendAuthRequest<Body: Encodable>(
        path: String,
        body: Body
    ) async throws -> AuthResponse {
        
        let url = APIConfig.baseURL.appending(path: path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        request.httpBody = try encoder.encode(body)
        
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
        
        guard 200...299 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8)
            
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(AuthResponse.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}
