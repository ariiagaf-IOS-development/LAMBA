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
        return await createEventAndReturn(
            vehicleId: vehicleId,
            token: token,
            event: event
        ) != nil
    }
    
    func createEventAndReturn(
        vehicleId: Int,
        token: String,
        event: VehicleEventRequest
    ) async -> VehicleEvent? {
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
            return createdEvent
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return nil
        }
    }
    
    func updateEventAndReturn(
        vehicleId: Int,
        eventId: Int,
        token: String,
        event: VehicleEventUpdateRequest
    ) async -> VehicleEvent? {
        isCreating = true
        errorMessage = nil
        
        do {
            let updatedEvent = try await apiService.updateEvent(
                vehicleId: vehicleId,
                eventId: eventId,
                request: event,
                token: token
            )
            
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index] = updatedEvent
            } else {
                events.insert(updatedEvent, at: 0)
            }
            
            events = events.sortedByEventDateDescending()
            
            if let refreshedStats = try? await apiService.getEventStats(vehicleId: vehicleId, token: token) {
                stats = refreshedStats.stats
            }
            
            NotificationCenter.default.post(name: .vehicleEventsDidChange, object: vehicleId)
            
            isCreating = false
            return updatedEvent
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return nil
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
    
    func uploadEventPhotos(
        vehicleId: Int,
        eventId: Int,
        photos: [Data],
        token: String
    ) async -> [VehicleEventPhoto] {
        var uploadedPhotos: [VehicleEventPhoto] = []
        
        for photo in photos {
            do {
                let uploadedPhoto = try await apiService.uploadEventPhoto(
                    vehicleId: vehicleId,
                    eventId: eventId,
                    photoData: photo,
                    token: token
                )
                uploadedPhotos.append(uploadedPhoto)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        
        return uploadedPhotos
    }
    
    func loadPhotoData(
        vehicleId: Int,
        eventId: Int,
        token: String
    ) async -> [Data] {
        do {
            let photoList = try await apiService.listEventPhotos(
                vehicleId: vehicleId,
                eventId: eventId,
                token: token
            )
            
            var loadedPhotos: [Data] = []
            
            for photo in photoList.photos {
                if let data = try? await apiService.fetchPhotoData(
                    urlOrPath: photo.url,
                    token: token
                ) {
                    loadedPhotos.append(data)
                }
            }
            
            return loadedPhotos
        } catch {
            return []
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
