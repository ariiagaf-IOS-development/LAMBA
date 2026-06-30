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
    @State private var isAddingVehicle = false
    @State private var isManagingVehicles = false
        
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if vehicleViewModel.hasVehicle {
                        ScreenHeroView(
                            title: vehicleViewModel.brand.isEmpty ? "VEHICLE" : vehicleViewModel.brand,
                            accentTitle: vehicleViewModel.model.isEmpty ? "PROFILE" : vehicleViewModel.model,
                            subtitle: "Performance Dual Motor • Neural Link V2.4 Active",
                            topPadding: 12
                        )

                        if vehicleViewModel.vehicles.count >= 1 {
                            Button {
                                isManagingVehicles = true
                            } label: {
                                ManageVehiclesCard(
                                    count: vehicleViewModel.vehicles.count,
                                    activeVehicleName: "\(vehicleViewModel.brand) \(vehicleViewModel.model)"
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.sm)
                            .zIndex(10)
                        }

                        VehicleImageCard()
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.lg)
                        
                        NeuralLinkCard()
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.sm)
                        
                        VehiclePersonalityMiniCard()
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.sm)
                        
                        AddNewVehicleCard {
                            isAddingVehicle = true
                        }
                        .padding(.top, AppSpacing.sm)
                        
                    } else {
                        EmptyVehicleProfileView {
                            isAddingVehicle = true
                        }
                    }
                }
                .padding(.top, 0)
                .padding(.bottom, AppSpacing.xl)
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
                        if vehicleViewModel.activeVehicle != nil {
                            isEditingVehicle = true
                        }
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
        .fullScreenCover(isPresented: $isAddingVehicle) {
            AddVehicleView(
                mode: .create,
                onClose: {
                    isAddingVehicle = false
                }
            )
            .environmentObject(vehicleViewModel)
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $isManagingVehicles) {
            ManageVehiclesView()
                .environmentObject(vehicleViewModel)
                .environmentObject(authViewModel)
        }
        .onAppear {
            if vehicleViewModel.activeVehicleId == nil {
                vehicleViewModel.activeVehicleId = vehicleViewModel.vehicles.first?.id
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
                            if let data = vehicleViewModel.getImage(for: vehicleViewModel.activeVehicle?.id ?? 0),
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
                        
                        Text(vehicleViewModel.mileageDisplay.isEmpty ? "12,482 km" : vehicleViewModel.mileageDisplay)
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
    
    private struct VehiclePersonalityMiniCard: View {
        
        @EnvironmentObject var vehicleViewModel: VehicleViewModel
        
        var body: some View {
            if let vehicle = vehicleViewModel.activeVehicle {
                let personality = vehicleViewModel.personality(for: vehicle)
                
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: personality.iconName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 48, height: 48)
                        .background(AppColors.primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PERSONALITY CORE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.2)
                        
                        Text(personality.title)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text(personality.aiLine)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.lg)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xxl)
                        .stroke(AppColors.bubbleBorder, lineWidth: 1)
                )
            }
        }
    }
    
    private struct EmptyVehicleProfileView: View {
        
        let onAddVehicle: () -> Void
        
        var body: some View {
            VStack(spacing: 24) {
                ScreenHeroView(
                    title: "VEHICLE",
                    accentTitle: "PROFILE",
                    subtitle: "Connect your first vehicle to unlock AI-powered maintenance tracking.",
                    topPadding: 12
                )
                
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.xxl)
                            .fill(AppColors.card)
                            .frame(height: 220)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.xxl)
                                    .stroke(AppColors.bubbleBorder, lineWidth: 1)
                            )
                        
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primary.opacity(0.10))
                                    .frame(width: 72, height: 72)
                                
                                Image(systemName: "car.fill")
                                    .font(.system(size: 30, weight: .black))
                                    .foregroundStyle(AppColors.primary)
                            }
                            
                            Text("NO VEHICLE CONNECTED")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(AppColors.textPrimary)
                                .tracking(1.4)
                            
                            Text("Add your vehicle to create a digital twin and start tracking its health.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .frame(maxWidth: 240)
                        }
                    }
                    
                    PrimaryActionButton(
                        title: "ADD NEW VEHICLE",
                        colors: [
                            AppColors.gradientStart,
                            AppColors.gradientEnd
                        ]
                    ) {
                        onAddVehicle()
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }
    
    private struct AddNewVehicleCard: View {
        
        let onTap: () -> Void
        
        var body: some View {
            Button {
                onTap()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .fill(AppColors.primary.opacity(0.10))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(AppColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ADD NEW VEHICLE")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(1.2)
                        
                        Text("Create another digital twin")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                }
                .appCard()
                .padding(.horizontal, AppSpacing.lg)
            }
            .buttonStyle(.plain)
        }
    }
    
    private struct ManageVehiclesCard: View {
        
        let count: Int
        let activeVehicleName: String
        
        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .fill(AppColors.primary.opacity(0.10))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MANAGE VEHICLES")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .tracking(1.2)
                    
                    Text("\(count) vehicles · Active: \(activeVehicleName)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AppColors.textMuted)
            }
            .appCard()
            .contentShape(Rectangle())
        }
    }
}
