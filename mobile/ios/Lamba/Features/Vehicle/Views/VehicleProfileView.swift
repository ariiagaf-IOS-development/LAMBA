//
//  VehicleProfileView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct VehicleProfileView: View {
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isEditingVehicle = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    ScreenHeroView(
                        title: vehicleViewModel.brand.isEmpty ? "TESLA" : vehicleViewModel.brand,
                        accentTitle: vehicleViewModel.model.isEmpty ? "MODEL 3" : vehicleViewModel.model,
                        subtitle: "Performance Dual Motor • Neural Link V2.4 Active"
                    )
                    .padding(.top, AppSpacing.sm)
                    
                    VehicleImageCard()
                        .padding(.top, AppSpacing.lg)
                    
                    NeuralLinkCard()
                        .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, 12)
                .padding(.top, -5)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeaderView(
                config: .init(
                    title: "VEHICLE PROFILE",
                    leftIcon: "car.fill",
                    rightIcon: "gearshape.fill",
                    showsBackButton: false
                ),
                actions: .init(
                    onRightTap: {
                        isEditingVehicle = true
                    }
                )
            )
        }
        .fullScreenCover(isPresented: $isEditingVehicle) {
            AddVehicleView(
                mode: .edit,
                onClose: {
                    isEditingVehicle = false
                }
            )
            .environmentObject(vehicleViewModel)
            .environmentObject(authViewModel)
        }
    }
}

private struct VehicleImageCard: View {
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            
            ZStack {
                
                GeometryReader { geo in
                    Group {
                        if let data = vehicleViewModel.vehicleImageData,
                           let uiImage = UIImage(data: data) {
                            
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            
                            Image("vehicle_tesla_model_3")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
                .frame(height: 280)
                
                LinearGradient(
                    colors: [
                        Color.clear,
                        AppColors.primary.opacity(0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                Text("ACTIVE STREAM")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(1.2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ODOMETER")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textSecondary)
                    
                    Text(vehicleViewModel.mileage.isEmpty ? "12,482 km" : vehicleViewModel.mileage)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("CYCLE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textSecondary)
                    
                    Text(vehicleViewModel.year.isEmpty ? "2024" : vehicleViewModel.year)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.primary)
                }
            }
            .padding(20)
        }
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct NeuralLinkCard: View {
    
    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "cpu.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("SYSTEM ARCHITECTURE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.2)
                
                Text("AI Neural Link")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppColors.green)
        }
        .padding(24)
        .background(AppColors.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
    }
}
