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
    let accumulatedPausedSeconds: TimeInterval
    let pausedAt: Date?
    
    var id: Int { vehicleId }
    var isPaused: Bool { pausedAt != nil }
    
    init(
        tripId: Int?,
        vehicleId: Int,
        startMileageKm: Int,
        startedAt: Date,
        accumulatedPausedSeconds: TimeInterval = 0,
        pausedAt: Date? = nil
    ) {
        self.tripId = tripId
        self.vehicleId = vehicleId
        self.startMileageKm = startMileageKm
        self.startedAt = startedAt
        self.accumulatedPausedSeconds = accumulatedPausedSeconds
        self.pausedAt = pausedAt
    }
    
    var elapsedSeconds: TimeInterval {
        elapsedSeconds(at: Date())
    }
    
    func elapsedSeconds(at date: Date) -> TimeInterval {
        let visibleEndDate = pausedAt ?? date
        return max(0, visibleEndDate.timeIntervalSince(startedAt) - accumulatedPausedSeconds)
    }
    
    func pausing(at date: Date) -> ActiveTrip {
        ActiveTrip(
            tripId: tripId,
            vehicleId: vehicleId,
            startMileageKm: startMileageKm,
            startedAt: startedAt,
            accumulatedPausedSeconds: accumulatedPausedSeconds,
            pausedAt: date
        )
    }
    
    func resuming(at date: Date) -> ActiveTrip {
        let pausedInterval = pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        
        return ActiveTrip(
            tripId: tripId,
            vehicleId: vehicleId,
            startMileageKm: startMileageKm,
            startedAt: startedAt,
            accumulatedPausedSeconds: accumulatedPausedSeconds + pausedInterval,
            pausedAt: nil
        )
    }
}

struct Trip: Decodable, Identifiable {
    let id: Int
    let vehicleId: Int
    let startMileageKm: Int
    let endMileageKm: Int?
    let startAt: String
    let endAt: String?
    let isPaused: Bool?
    let pausedAt: String?
    let totalPausedSeconds: TimeInterval?
    let accumulatedPausedSeconds: TimeInterval?
    let createdAt: String?
    
    var activeTrip: ActiveTrip {
        ActiveTrip(
            tripId: id,
            vehicleId: vehicleId,
            startMileageKm: startMileageKm,
            startedAt: startAt.tripISO8601Date ?? Date(),
            accumulatedPausedSeconds: accumulatedPausedSeconds ?? totalPausedSeconds ?? 0,
            pausedAt: isPaused == true ? pausedAt?.tripISO8601Date : nil
        )
    }
}

struct StartTripRequest: Encodable {
    let startAt: String
    let startMileageKm: Int
}

struct EndTripRequest: Encodable {
    let endAt: String
    let endMileageKm: Int
}

struct TripPauseRequest: Encodable {
    let pausedAt: String
}

struct TripResumeRequest: Encodable {
    let resumedAt: String
}

struct TripTrackingFormatter {
    static func shortDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
    
    static func duration(from startDate: Date, to endDate: Date = Date()) -> String {
        duration(fromSeconds: endDate.timeIntervalSince(startDate))
    }
    
    static func duration(fromSeconds seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        
        return "\(max(1, minutes))m"
    }
}

private extension String {
    var tripISO8601Date: Date? {
        ISO8601DateFormatter().date(from: self)
    }
}
