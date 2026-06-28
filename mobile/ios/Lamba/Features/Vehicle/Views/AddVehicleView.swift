//
//  AddVehicleView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI
import PhotosUI

enum VehicleFormMode {
    case create
    case edit
}

struct AddVehicleView: View {
    
    let mode: VehicleFormMode
    let onClose: (() -> Void)?
    
    init(
        mode: VehicleFormMode = .create,
        onClose: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.onClose = onClose
    }
    
    private var isEditing: Bool {
        mode == .edit
    }
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var brand: String = ""
    @State private var model: String = ""
    @State private var year: String = ""
    @State private var mileage: String = ""
    @State private var vin: String = ""
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var localVehicleImageData: Data?
    
    private var isFormValid: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !mileage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        vin.trimmingCharacters(in: .whitespacesAndNewlines).count == 17
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                AppHeaderView(
                    config: .init(
                        title: isEditing ? "EDIT VEHICLE" : "CREATE VEHICLE"
                    ),
                    actions: .init(
                        onBackTap: {
                            onClose?()
                        }
                    )
                )
                
                ScreenHeroView(
                    title: isEditing ? "EDIT YOUR" : "CREATE YOUR",
                    accentTitle: "DIGITAL TWIN",
                    subtitle: isEditing
                    ? "Update your vehicle details and keep your digital twin accurate."
                    : "Add your vehicle details to initialize LAMBA AI sync."
                )
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        VehiclePhotoUploadField(
                            selectedPhoto: $selectedPhoto,
                            vehicleImageData: localVehicleImageData
                        )
                        
                        VehicleFieldSection(
                            title: "VEHICLE NODE (BRAND)",
                            placeholder: "e.g. Tesla",
                            text: $brand
                        )
                        
                        VehicleFieldSection(
                            title: "MODEL NAME",
                            placeholder: "e.g. Model 3",
                            text: $model
                        )
                        
                        HStack(spacing: 12) {
                            VehicleFieldSection(
                                title: "PRODUCTION YEAR",
                                placeholder: "2022",
                                text: $year,
                                keyboardType: .numberPad
                            )
                            .frame(maxWidth: .infinity)
                            
                            VehicleFieldSection(
                                title: "MILEAGE (KM)",
                                placeholder: "42000",
                                text: $mileage,
                                keyboardType: .numberPad
                            )
                            .frame(maxWidth: .infinity)
                        }
                        
                        VehicleFieldSection(
                            title: "17-character VIN",
                            placeholder: "JTDBE32K620123456",
                            text: $vin
                        )
                        
                        if let errorMessage = vehicleViewModel.errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.orange)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.top, 40)
                    .padding(.bottom, AppSpacing.xl)
                }
                
                PrimaryActionButton(
                    title: vehicleViewModel.isLoading
                    ? "SAVING..."
                    : (isEditing ? "SAVE CHANGES" : "INITIALIZE PROTOCOL"),
                    colors: isFormValid
                    ? [
                        AppColors.gradientStart,
                        AppColors.gradientEnd
                    ]
                    : [
                        AppColors.textSecondary.opacity(0.5),
                        AppColors.textSecondary.opacity(0.5)
                    ]
                ) {
                    guard isFormValid, let token = authViewModel.token else {
                        return
                    }
                    
                    Task {
                        if isEditing {
                            await vehicleViewModel.updateSelectedVehicle(
                                brand: brand,
                                model: model,
                                year: year,
                                mileage: mileage,
                                vin: vin,
                                token: token
                            )
                        } else {
                            await vehicleViewModel.createVehicle(
                                brand: brand,
                                model: model,
                                year: year,
                                mileage: mileage,
                                vin: vin,
                                token: token
                            )
                        }
                        
                        if vehicleViewModel.errorMessage == nil {
                            if let id = vehicleViewModel.activeVehicleId {
                                vehicleViewModel.setImage(localVehicleImageData, for: id)
                            }
                            
                            onClose?()
                        }
                    }
                }
                .disabled(!isFormValid || vehicleViewModel.isLoading)
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
                .background(AppColors.background)
            }
        }
        .onAppear {
            if isEditing, let vehicle = vehicleViewModel.activeVehicle {
                brand = vehicle.brand
                model = vehicle.model
                year = String(vehicle.year)
                mileage = String(vehicle.mileageKm)
                vin = vehicle.vin
                localVehicleImageData = vehicleViewModel.getImage(for: vehicle.id)
            } else {
                localVehicleImageData = nil
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    localVehicleImageData = data
                }
            }
        }
    }
    
    private struct VehicleInputField: View {
        
        let placeholder: String
        @Binding var text: String
        var keyboardType: UIKeyboardType = .default
        
        var body: some View {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textPrimary)
                .frame(minHeight: 24)
                .appCard()
        }
    }
    
    private struct VehicleFieldSection: View {
        
        let title: String
        let placeholder: String
        @Binding var text: String
        var keyboardType: UIKeyboardType = .default
        
        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(2)
                
                VehicleInputField(
                    placeholder: placeholder,
                    text: $text,
                    keyboardType: keyboardType
                )
            }
        }
    }
    
    private struct VehiclePhotoUploadField: View {
        
        @Binding var selectedPhoto: PhotosPickerItem?
        let vehicleImageData: Data?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                
                Text("UPLOAD VEHICLE PHOTO")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(2)
                
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    
                    HStack(spacing: 14) {
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .fill(AppColors.background)
                                .frame(width: 52, height: 52)
                            
                            if let data = vehicleImageData,
                               let uiImage = UIImage(data: data) {
                                
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppColors.primary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            
                            Text(vehicleImageData == nil
                                 ? "Add a photo to personalize your digital twin"
                                 : "Vehicle photo added"
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            
                            Text(vehicleImageData == nil
                                 ? "Tap to upload"
                                 : "Tap to change photo"
                            )
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.primary)
                        }
                        
                        Spacer()
                    }
                    .appCard()
                }
                .buttonStyle(.plain)
            }
        }
    }
}
