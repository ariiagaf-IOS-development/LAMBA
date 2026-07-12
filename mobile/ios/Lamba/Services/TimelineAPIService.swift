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
    
    func updateEvent(
        vehicleId: Int,
        eventId: Int,
        request body: VehicleEventUpdateRequest,
        token: String
    ) async throws -> VehicleEvent {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/events/\(eventId)",
            method: "PATCH",
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
    
    func listEventPhotos(
        vehicleId: Int,
        eventId: Int,
        token: String
    ) async throws -> VehicleEventPhotoListResponse {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/events/\(eventId)/photos",
            method: "GET",
            token: token
        )
    }
    
    func uploadEventPhoto(
        vehicleId: Int,
        eventId: Int,
        photoData: Data,
        token: String
    ) async throws -> VehicleEventPhoto {
        try await uploadMultipartPhoto(
            path: "/api/vehicles/\(vehicleId)/events/\(eventId)/photos",
            photoData: photoData,
            token: token,
            responseType: VehicleEventPhoto.self
        )
    }
    
    func fetchPhotoData(urlOrPath: String, token: String) async throws -> Data {
        let url = photoURL(from: urlOrPath)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        return data
    }
    
    func startTrip(
        vehicleId: Int,
        request body: StartTripRequest,
        token: String
    ) async throws -> Trip {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/trips/start",
            method: "POST",
            token: token,
            body: body
        )
    }
    
    func getActiveTrip(vehicleId: Int, token: String) async throws -> Trip {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/trips/active",
            method: "GET",
            token: token
        )
    }
    
    func pauseTrip(
        vehicleId: Int,
        tripId: Int,
        request body: TripPauseRequest,
        token: String
    ) async throws -> Trip {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/trips/\(tripId)/pause",
            method: "POST",
            token: token,
            body: body
        )
    }
    
    func resumeTrip(
        vehicleId: Int,
        tripId: Int,
        request body: TripResumeRequest,
        token: String
    ) async throws -> Trip {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/trips/\(tripId)/resume",
            method: "POST",
            token: token,
            body: body
        )
    }
    
    func endTrip(
        vehicleId: Int,
        tripId: Int,
        request body: EndTripRequest,
        token: String
    ) async throws -> Trip {
        try await sendRequest(
            path: "/api/vehicles/\(vehicleId)/trips/\(tripId)/end",
            method: "POST",
            token: token,
            body: body
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
    
    private func uploadMultipartPhoto<Response: Decodable>(
        path: String,
        photoData: Data,
        token: String,
        responseType: Response.Type
    ) async throws -> Response {
        let url = APIConfig.baseURL.appending(path: path)
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fieldName: "photo",
            filename: "photo.jpg",
            mimeType: "image/jpeg",
            data: photoData
        )
        
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
        return try decoder.decode(Response.self, from: data)
    }
    
    private func multipartBody(
        boundary: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8) ?? Data())
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8) ?? Data())
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8) ?? Data())
        return body
    }
    
    private func photoURL(from urlOrPath: String) -> URL {
        if let url = URL(string: urlOrPath), url.scheme != nil {
            return url
        }
        
        let filename = urlOrPath
            .split(separator: "/")
            .last
            .map(String.init) ?? urlOrPath
        
        return APIConfig.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("photos")
            .appendingPathComponent(filename)
    }
}

private struct EmptyResponse: Decodable {}
