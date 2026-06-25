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
    
    @Published var vehicleImageData: Data?
    
    var hasVehicle: Bool {
        selectedVehicle != nil
    }
    
    var brand: String {
        selectedVehicle?.brand ?? ""
    }
    
    var model: String {
        selectedVehicle?.model ?? ""
    }
    
    var year: String {
        if let year = selectedVehicle?.year {
            return String(year)
        }
        return ""
    }
    
    var mileage: String {
        if let mileageKm = selectedVehicle?.mileageKm {
            return "\(mileageKm) km"
        }
        return ""
    }
    
    var vin: String {
        selectedVehicle?.vin ?? ""
    }
    
    func loadVehicles(token: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedVehicles = try await VehicleAPIService.shared.getVehicles(token: token)
            vehicles = loadedVehicles
            selectedVehicle = loadedVehicles.first
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
        guard let selectedVehicle else { return }
        
        isLoading = true
        errorMessage = nil
        
        let cleanYear = Int(year.trimmingCharacters(in: .whitespacesAndNewlines)) ?? selectedVehicle.year
        let cleanMileage = mileage
            .replacingOccurrences(of: "km", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let mileageKm = Int(cleanMileage) ?? selectedVehicle.mileageKm
        
        do {
            let updatedVehicle = try await VehicleAPIService.shared.updateVehicle(
                id: selectedVehicle.id,
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                year: cleanYear,
                mileageKm: mileageKm,
                vin: vin.trimmingCharacters(in: .whitespacesAndNewlines),
                token: token
            )
            
            self.selectedVehicle = updatedVehicle
            
            await refreshVehicles(token: token)
            
            if let index = vehicles.firstIndex(where: { $0.id == updatedVehicle.id }) {
                vehicles[index] = updatedVehicle
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteSelectedVehicle(token: String) async {
        guard let selectedVehicle else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await VehicleAPIService.shared.deleteVehicle(
                id: selectedVehicle.id,
                token: token
            )
            
            await refreshVehicles(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func selectVehicle(_ vehicle: VehicleResponse) {
        selectedVehicle = vehicle
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func refreshVehicles(token: String) async {
        await loadVehicles(token: token)
    }
}
