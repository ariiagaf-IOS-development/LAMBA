//
//  VehicleViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import Foundation
import Combine

final class VehicleViewModel: ObservableObject {
    
    @Published var vehicleImageData: Data?
    
    @Published var hasVehicle: Bool = false
    
    @Published var brand: String = ""
    @Published var model: String = ""
    @Published var year: String = ""
    @Published var mileage: String = ""
    
    func createVehicle(
        brand: String,
        model: String,
        year: String,
        mileage: String
    ) {
        self.brand = brand
        self.model = model
        self.year = year
        self.mileage = mileage
        
        self.hasVehicle = true
    }
}
