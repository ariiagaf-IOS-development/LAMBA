//
//  TimelineAPIService.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

final class TimelineAPIService {
    
    static let shared = TimelineAPIService()
    
    private init() {}
    
    func getTimeline(vehicleId: Int, token: String) async throws -> VehicleTimelineResponse {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/timeline",
            method: "GET",
            token: token
        )
    }
    
    func getEventStats(vehicleId: Int, token: String) async throws -> VehicleEventStatsResponse {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/events/stats",
            method: "GET",
            token: token
        )
    }
    
    func createEvent(
        vehicleId: Int,
        request body: VehicleEventRequest,
        token: String
    ) async throws -> VehicleEvent {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/events",
            method: "POST",
            token: token,
            body: body
        )
    }
    
    func deleteEvent(
        vehicleId: Int,
        eventId: Int,
        token: String
    ) async throws {
        let _: EmptyResponse = try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/events/\(eventId)",
            method: "DELETE",
            token: token
        )
    }
    
    private func sendRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        token: String,
        body: Body? = Optional<String>.none
    ) async throws -> Response {
        let url = APIConfig.baseURL.appending(path: path)
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }
        
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
        
        if data.isEmpty,
           let emptyResponse = EmptyResponse() as? Response {
            return emptyResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

private struct EmptyResponse: Decodable {}
