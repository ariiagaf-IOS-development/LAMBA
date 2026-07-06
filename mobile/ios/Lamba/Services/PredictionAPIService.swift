//
//  PredictionAPIService.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

final class PredictionAPIService {
    
    static let shared = PredictionAPIService()
    
    private init() {}
    
    func getPredictions(vehicleId: Int, token: String) async throws -> PredictionResponse {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/predictions",
            method: "GET",
            token: token
        )
    }
    
    func refreshPredictions(vehicleId: Int, token: String) async throws -> PredictionResponse {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/predictions/refresh",
            method: "POST",
            token: token
        )
    }
    
    func getDashboard(vehicleId: Int, token: String) async throws -> VehicleDashboard {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/dashboard",
            method: "GET",
            token: token
        )
    }
    
    func getVehicleParts(vehicleId: Int, token: String) async throws -> VehiclePartsResponse {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/parts",
            method: "GET",
            token: token
        )
    }
    
    private func sendRequest<Response: Decodable>(
        path: String,
        method: String,
        token: String
    ) async throws -> Response {
        let url = APIConfig.baseURL.appending(path: path)
        
        var request = URLRequest(url: url)
        request.httpMethod = method
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
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8)?
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(240)
            
            throw APIError.responseDecodingError(
                message: "\(error.localizedDescription). Body: \(rawBody ?? "empty")"
            )
        }
    }
}
