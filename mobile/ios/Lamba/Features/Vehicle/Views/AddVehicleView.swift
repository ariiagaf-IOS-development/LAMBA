//
//  AddVehicleView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct AddVehicleView: View {
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("ADD VEHICLE")
                .font(.largeTitle)
                .bold()
            
            Button("Create Vehicle") {
                vehicleViewModel.createVehicle()
            }
        }
    }
}
