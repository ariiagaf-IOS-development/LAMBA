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
    let backendPersonality: VehiclePersonality?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case brand
        case model
        case year
        case mileageKm
        case vin
        case createdAt
        case updatedAt
        case personality
        case personalityType
        case character
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        brand = try container.decode(String.self, forKey: .brand)
        model = try container.decode(String.self, forKey: .model)
        year = try container.decode(Int.self, forKey: .year)
        mileageKm = try container.decode(Int.self, forKey: .mileageKm)
        vin = try container.decodeIfPresent(String.self, forKey: .vin) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        
        let personalityValue =
            try container.decodeIfPresent(String.self, forKey: .personality) ??
            (try container.decodeIfPresent(String.self, forKey: .personalityType)) ??
            (try container.decodeIfPresent(String.self, forKey: .character))
        
        backendPersonality = VehiclePersonality(backendValue: personalityValue)
    }
}

struct VehicleListResponse: Decodable {
    let vehicles: [VehicleResponse]
}
