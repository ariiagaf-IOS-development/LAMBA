//
//  RootView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        Group {
            if appViewModel.isAuthenticated == false {
                LoginView()
            } else if appViewModel.hasVehicle == false {
                AddVehicleView()
            } else {
                MainTabView()
            }
        }
    }
}
