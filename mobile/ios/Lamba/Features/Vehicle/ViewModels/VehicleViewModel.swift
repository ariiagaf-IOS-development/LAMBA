//
//  VehicleViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class VehicleViewModel: ObservableObject {
    
    @Published var vehicles: [VehicleResponse] = []
    @Published var selectedVehicle: VehicleResponse?
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var vehicleImages: [Int: Data] = [:]
    @Published var vehiclePersonalities: [Int: VehiclePersonality] = [:]

    private let vehicleImagesCacheKey = "local_vehicle_images_by_vehicle_id"
    private let vehiclePersonalitiesCacheKey = "local_vehicle_personalities_by_vehicle_id"
    private let chatMessagesCacheKey = "local_chat_messages_by_vehicle_id"
    private let eventPhotosLegacyCacheKey = "local_event_photos_by_event_id"
    private let activeTripsCacheKey = "local_active_trips_by_vehicle_id"

    @Published var activeVehicleId: Int?
    
    init() {
        loadVehicleImagesIfNeeded()
        loadVehiclePersonalitiesIfNeeded()
    }
    
    var activeVehicle: VehicleResponse? {
        vehicles.first { $0.id == activeVehicleId }
    }
    
    var hasVehicle: Bool {
        activeVehicle != nil
    }

    var brand: String {
        activeVehicle?.brand ?? ""
    }

    var model: String {
        activeVehicle?.model ?? ""
    }

    var year: String {
        if let year = activeVehicle?.year {
            return String(year)
        }

        return ""
    }

    var mileage: String {
        if let mileageKm = activeVehicle?.mileageKm {
            return String(mileageKm)
        }

        return ""
    }

    var mileageDisplay: String {
        if let mileageKm = activeVehicle?.mileageKm {
            return "\(mileageKm) km"
        }

        return ""
    }

    var vin: String {
        activeVehicle?.vin ?? ""
    }
    
    func loadVehicles(token: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedVehicles = try await VehicleAPIService.shared.getVehicles(token: token)
            
            vehicles = loadedVehicles

            if let currentId = activeVehicleId,
               loadedVehicles.contains(where: { $0.id == currentId }) {
                activeVehicleId = currentId
            } else {
                activeVehicleId = loadedVehicles.first?.id
            }

            selectedVehicle = vehicles.first(where: { $0.id == activeVehicleId })
            await syncVehiclePhotos(for: loadedVehicles, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createVehicle(
        brand: String,
        model: String,
        year: String,
        mileage: String,
        vin: String,
        personality: VehiclePersonality?,
        token: String
    ) async {
        isLoading = true
        errorMessage = nil
        
        let cleanYear = Int(year.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let cleanMileage = mileage
            .replacingOccurrences(of: "km", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let mileageKm = Int(cleanMileage) ?? 0
        
        do {
            let createdVehicle = try await VehicleAPIService.shared.createVehicle(
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                year: cleanYear,
                mileageKm: mileageKm,
                vin: vin.trimmingCharacters(in: .whitespacesAndNewlines),
                personality: personality ?? VehiclePersonality.inferred(
                    brand: brand,
                    model: model,
                    year: cleanYear,
                    mileageKm: mileageKm
                ),
                token: token
            )

            activeVehicleId = createdVehicle.id
            selectedVehicle = createdVehicle
            upsertVehicle(createdVehicle)
            
            if let personality {
                vehiclePersonalities[createdVehicle.id] = personality
                saveVehiclePersonalities()
            }
        } catch APIError.serverError(let statusCode, let message) where statusCode == 409 {
            let didRecoverExistingVehicle = await recoverExistingVehicleAfterCreateConflict(
                brand: brand,
                model: model,
                year: cleanYear,
                vin: vin,
                personality: personality,
                token: token
            )
            
            if !didRecoverExistingVehicle {
                errorMessage = APIError.serverError(
                    statusCode: statusCode,
                    message: message
                ).localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateSelectedVehicle(
        brand: String,
        model: String,
        year: String,
        mileage: String,
        vin: String,
        personality: VehiclePersonality?,
        token: String
    ) async {
        guard let activeVehicle else { return }
        
        isLoading = true
        errorMessage = nil
        
        let cleanYear = Int(year.trimmingCharacters(in: .whitespacesAndNewlines)) ?? activeVehicle.year
        let mileageKm = Int(mileage.filter { $0.isNumber }) ?? activeVehicle.mileageKm
        
        do {
            let updatedVehicle = try await VehicleAPIService.shared.updateVehicle(
                id: activeVehicle.id,
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                year: cleanYear,
                mileageKm: mileageKm,
                vin: vin.trimmingCharacters(in: .whitespacesAndNewlines),
                personality: personality ?? self.personality(for: activeVehicle),
                token: token
            )
            
            activeVehicleId = updatedVehicle.id
            selectedVehicle = updatedVehicle
            upsertVehicle(updatedVehicle)
            
            if let personality {
                vehiclePersonalities[updatedVehicle.id] = personality
                saveVehiclePersonalities()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateMileage(
        for vehicle: VehicleResponse,
        to mileageKm: Int,
        token: String
    ) async -> Bool {
        errorMessage = nil
        
        do {
            let updatedVehicle = try await VehicleAPIService.shared.updateVehicle(
                id: vehicle.id,
                brand: vehicle.brand,
                model: vehicle.model,
                year: vehicle.year,
                mileageKm: mileageKm,
                vin: vehicle.vin,
                personality: personality(for: vehicle),
                token: token
            )
            
            if let index = vehicles.firstIndex(where: { $0.id == updatedVehicle.id }) {
                vehicles[index] = updatedVehicle
            } else {
                vehicles.append(updatedVehicle)
            }
            
            if activeVehicleId == updatedVehicle.id {
                selectedVehicle = updatedVehicle
            }
            
            NotificationCenter.default.post(name: .vehicleEventsDidChange, object: updatedVehicle.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func deleteSelectedVehicle(token: String) async {
        guard let activeVehicle else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await VehicleAPIService.shared.deleteVehicle(
                id: activeVehicle.id,
                token: token
            )
            
            vehicleImages.removeValue(forKey: activeVehicle.id)
            vehiclePersonalities.removeValue(forKey: activeVehicle.id)
            saveVehicleImages()
            saveVehiclePersonalities()
            
            if activeVehicleId == activeVehicle.id {
                activeVehicleId = nil
                selectedVehicle = nil
            }
            
            await refreshVehicles(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteVehicle(_ vehicle: VehicleResponse, token: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await VehicleAPIService.shared.deleteVehicle(
                id: vehicle.id,
                token: token
            )
            
            vehicles.removeAll { $0.id == vehicle.id }
            vehicleImages.removeValue(forKey: vehicle.id)
            vehiclePersonalities.removeValue(forKey: vehicle.id)
            
            saveVehicleImages()
            saveVehiclePersonalities()
            
            if activeVehicleId == vehicle.id {
                activeVehicleId = vehicles.first?.id
            }

            selectedVehicle = vehicles.first(where: { $0.id == activeVehicleId })

            if vehicles.isEmpty {
                activeVehicleId = nil
                selectedVehicle = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearSessionState() {
        vehicles = []
        selectedVehicle = nil
        activeVehicleId = nil
        errorMessage = nil
        isLoading = false
        vehicleImages = [:]
        vehiclePersonalities = [:]
        purgeLocalSessionCaches()
        NotificationCenter.default.post(name: .localSessionCachesDidClear, object: nil)
    }
    
    func refreshVehicles(token: String) async {
        await loadVehicles(token: token)
    }
    
    func selectVehicle(_ vehicle: VehicleResponse) {
        activeVehicleId = vehicle.id
        selectedVehicle = vehicle
    }
    
    private func upsertVehicle(_ vehicle: VehicleResponse) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            vehicles[index] = vehicle
        } else {
            vehicles.append(vehicle)
        }
    }
    
    private func recoverExistingVehicleAfterCreateConflict(
        brand: String,
        model: String,
        year: Int,
        vin: String,
        personality: VehiclePersonality?,
        token: String
    ) async -> Bool {
        let requestedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedVin = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        do {
            let loadedVehicles = try await VehicleAPIService.shared.getVehicles(token: token)
            vehicles = loadedVehicles
            
            guard let existingVehicle = loadedVehicles.first(where: { vehicle in
                let vehicleVin = vehicle.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                
                if !requestedVin.isEmpty, vehicleVin == requestedVin {
                    return true
                }
                
                return vehicle.brand.caseInsensitiveCompare(requestedBrand) == .orderedSame &&
                    vehicle.model.caseInsensitiveCompare(requestedModel) == .orderedSame &&
                    vehicle.year == year
            }) else {
                return false
            }
            
            activeVehicleId = existingVehicle.id
            selectedVehicle = existingVehicle
            
            if let personality {
                vehiclePersonalities[existingVehicle.id] = personality
                saveVehiclePersonalities()
            }
            
            return true
        } catch {
            return false
        }
    }
    
    func getImage(for vehicleId: Int) -> Data? {
        vehicleImages[vehicleId]
    }

    func setImage(_ data: Data?, for vehicleId: Int) {
        loadVehicleImagesIfNeeded()
        
        if let data {
            vehicleImages[vehicleId] = data
        } else {
            vehicleImages.removeValue(forKey: vehicleId)
        }
        
        saveVehicleImages()
    }
    
    func uploadImage(_ data: Data, for vehicleId: Int, token: String) async -> Bool {
        errorMessage = nil
        
        do {
            let updatedVehicle = try await VehicleAPIService.shared.uploadVehiclePhoto(
                id: vehicleId,
                photoData: data.normalizedVehiclePhotoData,
                token: token
            )
            
            if let index = vehicles.firstIndex(where: { $0.id == updatedVehicle.id }) {
                vehicles[index] = updatedVehicle
            }
            
            selectedVehicle = vehicles.first(where: { $0.id == activeVehicleId })
            setImage(data.normalizedVehiclePhotoData, for: vehicleId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func personality(for vehicle: VehicleResponse) -> VehiclePersonality {
        return vehicle.backendPersonality ??
        vehiclePersonalities[vehicle.id] ??
        VehiclePersonality.inferred(
            brand: vehicle.brand,
            model: vehicle.model,
            year: vehicle.year,
            mileageKm: vehicle.mileageKm
        )
    }
    
    func personality(for vehicleId: Int) -> VehiclePersonality? {
        if let personality = vehiclePersonalities[vehicleId] {
            return personality
        }
        
        guard let vehicle = vehicles.first(where: { $0.id == vehicleId }) else {
            return nil
        }
        
        return personality(for: vehicle)
    }
    
    func setPersonality(
        _ personality: VehiclePersonality,
        for vehicleId: Int,
        token: String?
    ) async -> Bool {
        loadVehiclePersonalitiesIfNeeded()
        
        guard let vehicle = vehicles.first(where: { $0.id == vehicleId }),
              let token else {
            vehiclePersonalities[vehicleId] = personality
            saveVehiclePersonalities()
            return false
        }
        
        do {
            let updatedVehicle = try await VehicleAPIService.shared.updateVehicle(
                id: vehicle.id,
                brand: vehicle.brand,
                model: vehicle.model,
                year: vehicle.year,
                mileageKm: vehicle.mileageKm,
                vin: vehicle.vin,
                personality: personality,
                token: token
            )
            
            if let index = vehicles.firstIndex(where: { $0.id == updatedVehicle.id }) {
                vehicles[index] = updatedVehicle
            }
            
            selectedVehicle = vehicles.first(where: { $0.id == activeVehicleId })
            
            if updatedVehicle.backendPersonality == nil {
                vehiclePersonalities[vehicleId] = personality
            } else {
                vehiclePersonalities.removeValue(forKey: vehicleId)
            }
            
            saveVehiclePersonalities()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    private func saveVehicleImages() {
        do {
            let encoded = try JSONEncoder().encode(vehicleImages)
            UserDefaults.standard.set(encoded, forKey: vehicleImagesCacheKey)
        } catch {
            print("Failed to save vehicle images:", error.localizedDescription)
        }
    }

    private func loadVehicleImagesIfNeeded() {
        guard vehicleImages.isEmpty,
              let data = UserDefaults.standard.data(forKey: vehicleImagesCacheKey) else {
            return
        }
        
        do {
            vehicleImages = try JSONDecoder().decode(
                [Int: Data].self,
                from: data
            )
        } catch {
            print("Failed to load vehicle images:", error.localizedDescription)
        }
    }
    
    private func syncVehiclePhotos(for vehicles: [VehicleResponse], token: String) async {
        for vehicle in vehicles {
            guard let photoUrl = vehicle.photoUrl,
                  !photoUrl.isEmpty,
                  vehicleImages[vehicle.id] == nil else {
                continue
            }
            
            if let data = try? await VehicleAPIService.shared.fetchPhotoData(
                urlOrPath: photoUrl,
                token: token
            ) {
                vehicleImages[vehicle.id] = data
            }
        }
        
        saveVehicleImages()
    }
    
    private func setPersonalityIfNeeded(for vehicle: VehicleResponse) {
        guard vehiclePersonalities[vehicle.id] == nil,
              vehicle.backendPersonality == nil else {
            return
        }
        
        vehiclePersonalities[vehicle.id] = VehiclePersonality.inferred(
            brand: vehicle.brand,
            model: vehicle.model,
            year: vehicle.year,
            mileageKm: vehicle.mileageKm
        )
        saveVehiclePersonalities()
    }
    
    private func saveVehiclePersonalities() {
        do {
            let encoded = try JSONEncoder().encode(vehiclePersonalities)
            UserDefaults.standard.set(encoded, forKey: vehiclePersonalitiesCacheKey)
        } catch {
            print("Failed to save vehicle personalities:", error.localizedDescription)
        }
    }
    
    private func loadVehiclePersonalitiesIfNeeded() {
        guard vehiclePersonalities.isEmpty,
              let data = UserDefaults.standard.data(forKey: vehiclePersonalitiesCacheKey) else {
            return
        }
        
        do {
            vehiclePersonalities = try JSONDecoder().decode(
                [Int: VehiclePersonality].self,
                from: data
            )
        } catch {
            vehiclePersonalities = [:]
            UserDefaults.standard.removeObject(forKey: vehiclePersonalitiesCacheKey)
            print("Failed to load vehicle personalities:", error.localizedDescription)
        }
    }
    
    private func purgeLocalSessionCaches() {
        let defaults = UserDefaults.standard
        [
            vehicleImagesCacheKey,
            vehiclePersonalitiesCacheKey,
            chatMessagesCacheKey,
            eventPhotosLegacyCacheKey,
            activeTripsCacheKey
        ].forEach { defaults.removeObject(forKey: $0) }
        
        removeStoredEventPhotos()
    }
    
    private func removeStoredEventPhotos() {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        
        let eventPhotosURL = supportURL
            .appendingPathComponent("Lamba", isDirectory: true)
            .appendingPathComponent("EventPhotos", isDirectory: true)
        
        do {
            if FileManager.default.fileExists(atPath: eventPhotosURL.path) {
                try FileManager.default.removeItem(at: eventPhotosURL)
            }
        } catch {
            print("Failed to remove stored event photos:", error.localizedDescription)
        }
    }
}

private extension Data {
    var normalizedVehiclePhotoData: Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: self) else {
            return self
        }
        
        let maxSide: CGFloat = 1400
        let size = image.size
        let scale = Swift.min(1, maxSide / Swift.max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        return resizedImage.jpegData(compressionQuality: 0.82) ?? self
        #else
        return self
        #endif
    }
}
