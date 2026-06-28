//
//  VehicleViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import Foundation
import Combine

@MainActor
final class VehicleViewModel: ObservableObject {
    
    @Published var vehicles: [VehicleResponse] = []
    @Published var selectedVehicle: VehicleResponse?
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var vehicleImages: [Int: Data] = [:]

    private let vehicleImagesCacheKey = "local_vehicle_images_by_vehicle_id"

    @Published var activeVehicleId: Int?
    
    init() {
        loadVehicleImagesIfNeeded()
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
            saveVehicleImages()
            
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
            
            saveVehicleImages()
            
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
}
