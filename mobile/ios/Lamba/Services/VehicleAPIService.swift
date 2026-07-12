//
//  VehicleAPIService.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

final class VehicleAPIService {
    
    static let shared = VehicleAPIService()
    
    private init() {}
    
    // MARK: - Get all vehicles
    
    func getVehicles(token: String) async throws -> [VehicleResponse] {
        let url = APIConfig.baseURL.appending(path: "/api/vehicles")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await performRequest(request)
        
        guard 200...299 ~= response.statusCode else {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(VehicleListResponse.self, from: data).vehicles
    }
    
    // MARK: - Get one vehicle
    
    func getVehicle(id: Int, token: String) async throws -> VehicleResponse {
        let url = APIConfig.baseURL.appending(path: "/api/vehicles/\(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await performRequest(request)
        
        guard 200...299 ~= response.statusCode else {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(VehicleResponse.self, from: data)
    }
    
    // MARK: - Create vehicle
    
    func createVehicle(
        brand: String,
        model: String,
        year: Int,
        mileageKm: Int,
        vin: String,
        personality: VehiclePersonality? = nil,
        token: String
    ) async throws -> VehicleResponse {
        
        let url = APIConfig.baseURL.appending(path: "/api/vehicles")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = VehicleRequest(
            brand: brand,
            model: model,
            year: year,
            mileageKm: mileageKm,
            vin: vin,
            fuelType: nil,
            transmission: nil,
            usageType: nil
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await performRequest(request)
        
        guard 200...299 ~= response.statusCode else {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(VehicleResponse.self, from: data)
    }
    
    // MARK: - Update vehicle
    
    func updateVehicle(
        id: Int,
        brand: String,
        model: String,
        year: Int,
        mileageKm: Int,
        vin: String,
        personality: VehiclePersonality? = nil,
        token: String
    ) async throws -> VehicleResponse {
        
        let url = APIConfig.baseURL.appending(path: "/api/vehicles/\(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = VehicleUpdateRequest(
            brand: brand,
            model: model,
            year: year,
            mileageKm: mileageKm,
            vin: vin,
            fuelType: nil,
            transmission: nil,
            usageType: nil
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await performRequest(request)
        
        guard 200...299 ~= response.statusCode else {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(VehicleResponse.self, from: data)
    }
    
    // MARK: - Delete vehicle
    
    func deleteVehicle(id: Int, token: String) async throws {
        let url = APIConfig.baseURL.appending(path: "/api/vehicles/\(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await performRequest(request)
        
        guard 200...299 ~= response.statusCode else {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
    }
    
    func uploadVehiclePhoto(
        id: Int,
        photoData: Data,
        token: String
    ) async throws -> VehicleResponse {
        let url = APIConfig.baseURL.appending(path: "/api/vehicles/\(id)/photo")
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fieldName: "photo",
            filename: "vehicle.jpg",
            mimeType: "image/jpeg",
            data: photoData
        )
        
        let (data, response) = try await performRequest(request)
        
        guard 200...299 ~= response.statusCode else {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(VehicleResponse.self, from: data)
    }
    
    func fetchPhotoData(urlOrPath: String, token: String) async throws -> Data {
        let url = photoURL(from: urlOrPath)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await performRequest(request)
        
        guard 200...299 ~= response.statusCode else {
            throw APIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        return data
    }
    
    // MARK: - Request helper
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
        
        return (data, httpResponse)
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
