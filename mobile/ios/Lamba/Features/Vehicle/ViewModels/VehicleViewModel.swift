//
//  VehicleViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import Foundation
import Combine

class VehicleViewModel: ObservableObject {
    
    @Published var hasVehicle: Bool = false
    
    func createVehicle() {
        hasVehicle = true
    }
}
