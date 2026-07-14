//
//  ManageVehiclesView.swift
//  Lamba
//
//  Created by Арина Агафонова on 28.06.2026.
//

import SwiftUI

struct ManageVehiclesView: View {
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(vehicleViewModel.vehicles) { vehicle in
                    Button {
                        vehicleViewModel.selectVehicle(vehicle)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primary.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "car.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppColors.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(vehicle.brand) \(vehicle.model)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Text("\(vehicle.year) · \(vehicle.mileageKm) km")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if vehicle.id == vehicleViewModel.activeVehicleId {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppColors.primary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                guard let token = authViewModel.token else { return }
                                
                                await vehicleViewModel.deleteVehicle(vehicle, token: token)
                                
                                if vehicleViewModel.vehicles.isEmpty {
                                    dismiss()
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("My Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
