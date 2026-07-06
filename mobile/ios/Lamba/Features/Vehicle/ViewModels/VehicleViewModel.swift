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
                token: token
            )

            activeVehicleId = createdVehicle.id
            selectedVehicle = createdVehicle

            await refreshVehicles(token: token)
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
                token: token
            )
            
            activeVehicleId = updatedVehicle.id
            selectedVehicle = updatedVehicle
            
            await refreshVehicles(token: token)
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
    }
    
    func refreshVehicles(token: String) async {
        await loadVehicles(token: token)
    }
    
    func selectVehicle(_ vehicle: VehicleResponse) {
        activeVehicleId = vehicle.id
        selectedVehicle = vehicle
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
        return vehiclePersonalities[vehicle.id] ??
        vehicle.backendPersonality ??
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
    
    func setPersonality(_ personality: VehiclePersonality, for vehicleId: Int) {
        loadVehiclePersonalitiesIfNeeded()
        vehiclePersonalities[vehicleId] = personality
        saveVehiclePersonalities()
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
