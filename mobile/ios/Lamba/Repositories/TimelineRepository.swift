//
//  TimelineRepository.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation
import Combine

@MainActor
final class TimelineRepository: ObservableObject {
    
    @Published private(set) var events: [VehicleEvent] = []
    @Published private(set) var stats: VehicleEventStats?
    @Published private(set) var isLoading = false
    @Published private(set) var isCreating = false
    @Published private(set) var deletingEventIds: Set<Int> = []
    @Published var errorMessage: String?
    
    private let apiService: TimelineAPIService
    
    init(apiService: TimelineAPIService) {
        self.apiService = apiService
    }
    
    convenience init() {
        self.init(apiService: .shared)
    }
    
    func loadTimeline(vehicleId: Int, token: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedTimeline = try await apiService.getTimeline(vehicleId: vehicleId, token: token)
            events = loadedTimeline.timeline.sortedByEventDateDescending()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        stats = try? await apiService.getEventStats(vehicleId: vehicleId, token: token).stats
        
        isLoading = false
    }
    
    func createEvent(
        vehicleId: Int,
        token: String,
        event: VehicleEventRequest
    ) async -> Bool {
        isCreating = true
        errorMessage = nil
        
        do {
            let createdEvent = try await apiService.createEvent(
                vehicleId: vehicleId,
                request: event,
                token: token
            )
            
            events.insert(createdEvent, at: 0)
            events = events.sortedByEventDateDescending()
            
            if let refreshedStats = try? await apiService.getEventStats(vehicleId: vehicleId, token: token) {
                stats = refreshedStats.stats
            }
            
            NotificationCenter.default.post(name: .vehicleEventsDidChange, object: vehicleId)
            
            isCreating = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return false
        }
    }
    
    func deleteEvent(
        vehicleId: Int,
        eventId: Int,
        token: String
    ) async -> Bool {
        deletingEventIds.insert(eventId)
        errorMessage = nil
        
        do {
            try await apiService.deleteEvent(
                vehicleId: vehicleId,
                eventId: eventId,
                token: token
            )
            
            events.removeAll { $0.id == eventId }
            
            if let refreshedStats = try? await apiService.getEventStats(vehicleId: vehicleId, token: token) {
                stats = refreshedStats.stats
            }
            
            NotificationCenter.default.post(name: .vehicleEventsDidChange, object: vehicleId)
            
            deletingEventIds.remove(eventId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            deletingEventIds.remove(eventId)
            return false
        }
    }
    
    func clear() {
        events = []
        stats = nil
        deletingEventIds = []
        errorMessage = nil
    }
}

private extension Array where Element == VehicleEvent {
    func sortedByEventDateDescending() -> [VehicleEvent] {
        sorted { lhs, rhs in
            lhs.eventSortDate > rhs.eventSortDate
        }
    }
}
