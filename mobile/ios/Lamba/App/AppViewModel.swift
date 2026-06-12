//
//  AppViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation
import Combine

final class AppViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasVehicle = false

    func login() {
        isAuthenticated = true
    }

    func completeVehicleCreation() {
        hasVehicle = true
    }

    func logout() {
        isAuthenticated = false
        hasVehicle = false
    }
}
