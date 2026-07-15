//
//  VehicleEvent.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

extension Notification.Name {
    static let vehicleEventsDidChange = Notification.Name("vehicleEventsDidChange")
    static let localSessionCachesDidClear = Notification.Name("localSessionCachesDidClear")
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
        fuelLiters ?? metadataDoubleValue(for: [
            "fuel_liters",
            "fuel_litres",
            "fuel_liter",
            "fuel_litre",
            "liters",
            "litres",
            "fuel",
            "fuel_amount",
            "fuel_amount_liters",
            "fuel_volume",
            "fuel_volume_liters",
            "volume_liters"
        ])
    }
    
    var displayPricePerLiter: Double? {
        metadataDoubleValue(for: [
            "price_per_liter",
            "price_per_litre",
            "price_per_l",
            "price_liter",
            "price_litre",
            "fuel_price_per_liter",
            "cost_per_liter",
            "cost_per_litre",
            "rub_per_liter",
            "rub_per_litre"
        ])
    }
    
    var tripStartDate: Date? {
        metadataStringValue(for: ["start_at", "started_at", "trip_start", "start_time"])?.iso8601Date
    }
    
    var tripEndDate: Date? {
        metadataStringValue(for: ["end_at", "ended_at", "trip_end", "end_time"])?.iso8601Date ?? eventDate.iso8601Date
    }
    
    var tripDurationSeconds: Double? {
        if let durationSeconds = metadataDoubleValue(for: ["duration_seconds", "trip_duration_seconds"]) {
            return durationSeconds
        }
        
        guard let tripStartDate,
              let tripEndDate else {
            return nil
        }
        
        return tripEndDate.timeIntervalSince(tripStartDate)
    }
    
    var tripDistanceKm: Double? {
        metadataDoubleValue(for: ["distance_km", "trip_distance_km"])
    }
    
    var additionalMetadataItems: [EventMetadataDisplayItem] {
        let reservedKeys = Set([
            "fuel_liters",
            "fuel_litres",
            "fuel_liter",
            "fuel_litre",
            "liters",
            "litres",
            "fuel",
            "fuel_amount",
            "fuel_amount_liters",
            "fuel_volume",
            "fuel_volume_liters",
            "volume_liters",
            "price_per_liter",
            "price_per_litre",
            "price_per_l",
            "price_liter",
            "price_litre",
            "fuel_price_per_liter",
            "cost_per_liter",
            "cost_per_litre",
            "rub_per_liter",
            "rub_per_litre",
            "start_at",
            "started_at",
            "trip_start",
            "start_time",
            "end_at",
            "ended_at",
            "trip_end",
            "end_time",
            "duration_seconds",
            "trip_duration_seconds",
            "distance_km",
            "trip_distance_km"
        ])
        
        return (metadata ?? [:])
            .filter { !reservedKeys.contains($0.key.lowercased()) }
            .map { key, value in
                EventMetadataDisplayItem(
                    key: key,
                    title: key.metadataTitle,
                    value: value.displayText
                )
            }
            .sorted { $0.title < $1.title }
    }
    
    private func metadataDoubleValue(for aliases: [String]) -> Double? {
        guard let metadata else { return nil }
        
        for alias in aliases {
            if let value = metadata.first(where: { $0.key.caseInsensitiveCompare(alias) == .orderedSame })?.value.doubleValue {
                return value
            }
        }
        
        return nil
    }
    
    private func metadataStringValue(for aliases: [String]) -> String? {
        guard let metadata else { return nil }
        
        for alias in aliases {
            if let value = metadata.first(where: { $0.key.caseInsensitiveCompare(alias) == .orderedSame })?.value.stringValue {
                return value
            }
        }
        
        return nil
    }
}

struct EventMetadataDisplayItem: Identifiable {
    let key: String
    let title: String
    let value: String
    
    var id: String { key }
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
    let metadata: [String: EventMetadataValue]?
}

struct VehicleEventUpdateRequest: Encodable {
    let type: VehicleEventType?
    let title: String?
    let description: String?
    let eventDate: String?
    let mileageKm: Int?
    let cost: Double?
    let metadata: [String: EventMetadataValue]?
}

struct VehicleEventPhoto: Decodable, Identifiable {
    let id: Int
    let vehicleEventId: Int?
    let url: String
    let createdAt: String?
}

struct VehicleEventPhotoListResponse: Decodable {
    let vehicleEventId: Int
    let photos: [VehicleEventPhoto]
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
            return value.firstDecimalValue
        case .bool:
            return nil
        }
    }
    
    var displayText: String {
        switch self {
        case .double(let value):
            return value.formatted(.number.precision(.fractionLength(0...2)))
        case .int(let value):
            return value.formatted()
        case .string(let value):
            return value
        case .bool(let value):
            return value ? "Yes" : "No"
        }
    }
    
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .double(let value):
            return String(value)
        case .int(let value):
            return String(value)
        case .bool(let value):
            return String(value)
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

private extension String {
    var iso8601Date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: self) {
            return date
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }
    
    var firstDecimalValue: Double? {
        let normalized = replacingOccurrences(of: ",", with: ".")
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.-")
        let parts = normalized
            .unicodeScalars
            .split { !allowedCharacters.contains($0) }
            .map(String.init)
        
        return parts.compactMap(Double.init).first
    }
    
    var metadataTitle: String {
        split(separator: "_")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
