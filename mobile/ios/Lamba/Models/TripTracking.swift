//
//  TripTracking.swift
//  Lamba
//
//  Created by Codex on 06.07.2026.
//

import Foundation

struct ActiveTrip: Codable, Identifiable, Equatable {
    let tripId: Int?
    let vehicleId: Int
    let startMileageKm: Int
    let startedAt: Date
    
    var id: Int { vehicleId }
    
    init(
        tripId: Int?,
        vehicleId: Int,
        startMileageKm: Int,
        startedAt: Date
    ) {
        self.tripId = tripId
        self.vehicleId = vehicleId
        self.startMileageKm = startMileageKm
        self.startedAt = startedAt
    }
}

struct Trip: Decodable, Identifiable {
    let id: Int
    let vehicleId: Int
    let startMileageKm: Int
    let endMileageKm: Int?
    let startAt: String
    let endAt: String?
    let createdAt: String?
}

struct StartTripRequest: Encodable {
    let startAt: String
    let startMileageKm: Int
}

struct EndTripRequest: Encodable {
    let endAt: String
    let endMileageKm: Int
}

struct TripTrackingFormatter {
    static func shortDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
    
    static func duration(from startDate: Date, to endDate: Date = Date()) -> String {
        let totalMinutes = max(0, Int(endDate.timeIntervalSince(startDate) / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        
        return "\(max(1, minutes))m"
    }
}
