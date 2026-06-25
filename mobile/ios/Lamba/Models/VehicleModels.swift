//
//  VehicleModels.swift
//  Lamba
//
//  Created by Арина Агафонова on 25.06.2026.
//

import Foundation

struct VehicleRequest: Encodable {
    let brand: String
    let model: String
    let year: Int
    let mileageKm: Int
    let vin: String
}

struct VehicleUpdateRequest: Encodable {
    let brand: String
    let model: String
    let year: Int
    let mileageKm: Int
    let vin: String
}

struct VehicleResponse: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let brand: String
    let model: String
    let year: Int
    let mileageKm: Int
    let vin: String
    let createdAt: String?
    let updatedAt: String?
}

struct VehicleListResponse: Decodable {
    let vehicles: [VehicleResponse]
}
