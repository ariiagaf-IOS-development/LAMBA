//
//  AddVehicleView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct AddVehicleView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Vehicle")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Vehicle creation screen")

            Button("Create vehicle") {
                appViewModel.completeVehicleCreation()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
