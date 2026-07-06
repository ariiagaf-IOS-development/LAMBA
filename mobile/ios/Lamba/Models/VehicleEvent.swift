//
//  VehicleEvent.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

extension Notification.Name {
    static let vehicleEventsDidChange = Notification.Name("vehicleEventsDidChange")
}

enum VehicleEventType: String, Codable, CaseIterable, Identifiable {
    case trip
    case refuel
    case repair
    case inspection
    case accident
    case recall
    case warning
    case maintenance
    case prediction
    case diagnostic
    case partReplacement = "part_replacement"
    case note
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .trip:
            return "Trip"
        case .refuel:
            return "Refuel"
        case .repair:
            return "Repair"
        case .inspection:
            return "Inspection"
        case .accident:
            return "Accident"
        case .recall:
            return "Recall"
        case .warning:
            return "Warning"
        case .maintenance:
            return "Maintenance"
        case .prediction:
            return "Prediction"
        case .diagnostic:
            return "Diagnostic"
        case .partReplacement:
            return "Part Replacement"
        case .note:
            return "Note"
        }
    }
}

enum TimelineFilter: String, CaseIterable, Identifiable {
    case all
    case trip
    case refuel
    case repair
    case maintenance
    case other
    
    var id: String { rawValue }
    
    var title: String {
        rawValue.uppercased()
    }
}

struct VehicleEvent: Codable, Identifiable {
    let id: Int
    let vehicleId: Int?
    let type: VehicleEventType
    let title: String
    let description: String?
    let eventDate: String
    let mileageKm: Int?
    let cost: Double?
    let fuelLiters: Double?
    let metadata: [String: EventMetadataValue]?
    let createdAt: String?
    
    var displayFuelLiters: Double? {
        fuelLiters ?? metadata?["fuel_liters"]?.doubleValue
    }
}

struct VehicleTimelineResponse: Decodable {
    let vehicleId: Int
    let timeline: [VehicleEvent]
    let count: Int?
    let limit: Int?
    let offset: Int?
}

struct VehicleEventsResponse: Decodable {
    let vehicleId: Int
    let events: [VehicleEvent]
    let count: Int?
    let limit: Int?
    let offset: Int?
}

struct VehicleEventStatsResponse: Decodable {
    let vehicleId: Int
    let stats: VehicleEventStats
}

struct VehicleEventStats: Decodable {
    let totalEvents: Int
    let totalCost: Double
    let lastEventDate: String?
    let byType: [VehicleEventTypeStats]
    
    var repairCost: Double {
        let serviceCost = byType
            .filter { [.repair, .maintenance, .partReplacement].contains($0.type) }
            .map(\.cost)
            .reduce(0, +)
        
        return serviceCost
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalEvents = try container.decodeIfPresent(Int.self, forKey: .totalEvents) ?? 0
        totalCost = try container.decodeIfPresent(Double.self, forKey: .totalCost) ?? 0
        lastEventDate = try container.decodeIfPresent(String.self, forKey: .lastEventDate)
        byType = try container.decodeIfPresent([VehicleEventTypeStats].self, forKey: .byType) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case totalEvents
        case totalCost
        case lastEventDate
        case byType
    }
}

struct VehicleEventTypeStats: Decodable, Identifiable {
    let type: VehicleEventType
    let count: Int
    let cost: Double
    
    var id: VehicleEventType { type }
}

struct VehicleEventRequest: Encodable {
    let type: VehicleEventType
    let title: String
    let description: String?
    let eventDate: String
    let mileageKm: Int?
    let cost: Double?
    let fuelLiters: Double?
    let metadata: [String: EventMetadataValue]?
}

enum EventMetadataValue: Codable, Equatable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    
    var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        case .string(let value):
            return Double(value.replacingOccurrences(of: ",", with: "."))
        case .bool:
            return nil
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .string((try? container.decode(String.self)) ?? "")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}
