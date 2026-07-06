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
    @State private var selectedPersonality: VehiclePersonality = .kindFriend
    @State private var didManuallySelectPersonality = false
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var localVehicleImageData: Data?
    
    private var isFormValid: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedYear != nil &&
        parsedMileage != nil &&
        isVinValid
    }
    
    private var parsedYear: Int? {
        let value = Int(year.filter { $0.isNumber })
        let nextYear = Calendar.current.component(.year, from: Date()) + 1
        
        guard let value, (1886...nextYear).contains(value) else {
            return nil
        }
        
        return value
    }
    
    private var parsedMileage: Int? {
        let value = Int(mileage.filter { $0.isNumber })
        guard let value, value >= 0 else { return nil }
        return value
    }
    
    private var normalizedVin: String {
        vin
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
    
    private var isVinValid: Bool {
        normalizedVin.count == 17 &&
        normalizedVin.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    private var inferredPersonality: VehiclePersonality {
        VehiclePersonality.inferred(
            brand: brand,
            model: model,
            year: parsedYear,
            mileageKm: parsedMileage
        )
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
                
                formContent
                
                saveButton
            }
        }
        .onAppear {
            vehicleViewModel.clearError()
            
            if isEditing, let vehicle = vehicleViewModel.activeVehicle {
                brand = vehicle.brand
                model = vehicle.model
                year = String(vehicle.year)
                mileage = String(vehicle.mileageKm)
                vin = vehicle.vin
                selectedPersonality = vehicleViewModel.personality(for: vehicle)
                didManuallySelectPersonality = vehicle.backendPersonality != nil
                localVehicleImageData = vehicleViewModel.getImage(for: vehicle.id)
            } else {
                syncInferredPersonality()
                localVehicleImageData = nil
            }
        }
        .onChange(of: brand) { _, _ in syncInferredPersonality() }
        .onChange(of: model) { _, _ in syncInferredPersonality() }
        .onChange(of: year) { _, _ in syncInferredPersonality() }
        .onChange(of: mileage) { _, _ in syncInferredPersonality() }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    localVehicleImageData = data
                }
            }
        }
    }
    
    private var formContent: some View {
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
                
                VehiclePersonalityFormSection(
                    selectedPersonality: $selectedPersonality,
                    inferredPersonality: inferredPersonality,
                    didManuallySelectPersonality: $didManuallySelectPersonality
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
    }
    
    private var saveButton: some View {
        PrimaryActionButton(
            title: vehicleViewModel.isLoading
            ? "SAVING..."
            : (isEditing ? "SAVE CHANGES" : "INITIALIZE PROTOCOL"),
            colors: isFormValid
            ? [AppColors.gradientStart, AppColors.gradientEnd]
            : [AppColors.textSecondary.opacity(0.5), AppColors.textSecondary.opacity(0.5)]
        ) {
            submit()
        }
        .disabled(!isFormValid || vehicleViewModel.isLoading)
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xl)
        .background(AppColors.background)
    }
    
    private func submit() {
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
                    vin: normalizedVin,
                    personality: selectedPersonality,
                    token: token
                )
            } else {
                await vehicleViewModel.createVehicle(
                    brand: brand,
                    model: model,
                    year: year,
                    mileage: mileage,
                    vin: normalizedVin,
                    personality: selectedPersonality,
                    token: token
                )
            }
            
            if vehicleViewModel.errorMessage == nil {
                if let id = vehicleViewModel.activeVehicleId,
                   let localVehicleImageData {
                    _ = await vehicleViewModel.uploadImage(
                        localVehicleImageData,
                        for: id,
                        token: token
                    )
                }
                
                onClose?()
            }
        }
    }
    
    private func syncInferredPersonality() {
        guard !didManuallySelectPersonality else { return }
        selectedPersonality = inferredPersonality
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
    
    private struct VehiclePersonalityFormSection: View {
        @Binding var selectedPersonality: VehiclePersonality
        let inferredPersonality: VehiclePersonality
        @Binding var didManuallySelectPersonality: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text("BEHAVIOR PROFILE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(2)
                
                Menu {
                    ForEach(VehiclePersonality.allCases) { personality in
                        Button {
                            selectedPersonality = personality
                            didManuallySelectPersonality = true
                        } label: {
                            Text(personality.title)
                        }
                    }
                    
                    Button {
                        selectedPersonality = inferredPersonality
                        didManuallySelectPersonality = false
                    } label: {
                        Text("Use detected profile")
                    }
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: selectedPersonality.iconName)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 48, height: 48)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selectedPersonality.title)
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            
                            Text(statusText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(AppColors.primary)
                    }
                    .appCard()
                }
                .buttonStyle(.plain)
            }
        }
        
        private var statusText: String {
            didManuallySelectPersonality
            ? "Selected manually. Will sync with backend on save."
            : "Detected from brand, age and mileage."
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
