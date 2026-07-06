//
//  CareOverviewView.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct CareOverviewView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    @StateObject private var predictionRepository = PredictionRepository()
    @State private var selectedPrediction: Prediction?
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            Group {
                if vehicleViewModel.activeVehicle == nil {
                    emptyVehicleView
                } else if predictionRepository.isLoading && predictionRepository.predictions.isEmpty {
                    ProgressView()
                        .tint(AppColors.primary)
                } else {
                    content
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeaderView(
                config: .init(
                    title: "VEHICLE CARE",
                    leftIcon: "heart.fill",
                    rightIcon: predictionRepository.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise",
                    showsBackButton: false
                ),
                actions: .init(
                    onRightTap: {
                        Task { await refreshCareData() }
                    }
                )
            )
        }
        .task(id: vehicleViewModel.activeVehicleId) {
            await loadCareData()
        }
        .onAppear {
            Task {
                await loadCareData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vehicleEventsDidChange)) { notification in
            guard let changedVehicleId = notification.object as? Int,
                  changedVehicleId == vehicleViewModel.activeVehicleId else {
                return
            }
            
            Task {
                await loadCareData()
            }
        }
        .sheet(item: $selectedPrediction) { prediction in
            PredictionDetailView(prediction: prediction)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                ScreenHeroView(
                    title: "VEHICLE",
                    accentTitle: "CARE",
                    subtitle: "Maintenance predictions and health insights for your car.",
                    topPadding: 12
                )
                
                VStack(spacing: AppSpacing.lg) {
                    if let errorMessage = predictionRepository.errorMessage {
                        ErrorCard(message: errorMessage) {
                            Task { await loadCareData() }
                        }
                    }
                    
                    CareStatsGrid(
                        dashboard: predictionRepository.dashboard,
                        eventStats: predictionRepository.eventStats,
                        predictions: predictionRepository.predictions
                    )
                    
                    if let focusPrediction {
                        FocusPredictionCard(prediction: focusPrediction) {
                            selectedPrediction = focusPrediction
                        }
                    }
                    
                    DashboardSummaryCard(
                        dashboard: predictionRepository.dashboard,
                        eventStats: predictionRepository.eventStats
                    )
                    
                    PredictiveEfficiencyCard(dashboard: predictionRepository.dashboard)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Text("PART STATUS")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(AppColors.textMuted)
                                .tracking(1.4)
                            
                            Spacer()
                            
                            Text("\(partStatusCount) PARTS")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(AppColors.primary)
                                .tracking(1.2)
                        }
                        
                        if predictionRepository.predictions.isEmpty,
                           !predictionRepository.parts.isEmpty {
                            ForEach(predictionRepository.parts) { part in
                                VehiclePartStatusRow(part: part)
                            }
                        } else if predictionRepository.predictions.isEmpty {
                            CarePredictionsEmptyCard(
                                isRefreshing: predictionRepository.isRefreshing
                            ) {
                                Task {
                                    await refreshCareData()
                                }
                            }
                        } else {
                            ForEach(predictionRepository.predictions) { prediction in
                                Button {
                                    selectedPrediction = prediction
                                } label: {
                                    PredictionRow(prediction: prediction)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(.top, 0)
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable {
            await refreshCareData()
        }
    }
    
    private var partStatusCount: Int {
        predictionRepository.predictions.isEmpty
        ? predictionRepository.parts.count
        : predictionRepository.predictions.count
    }
    
    private var focusPrediction: Prediction? {
        predictionRepository.predictions.first(where: { $0.riskLevel == .high })
        ?? predictionRepository.predictions.first(where: { $0.riskLevel == .medium })
        ?? predictionRepository.predictions.first
    }
    
    private var emptyVehicleView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "car.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AppColors.primary)
            
            Text("No vehicle selected")
                .font(AppTypography.h2)
                .foregroundStyle(AppColors.textPrimary)
            
            Text("Add or select a vehicle to see care predictions.")
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.xl)
    }
    
    private func loadCareData() async {
        guard let vehicleId = vehicleViewModel.activeVehicleId,
              let token = authViewModel.token else {
            predictionRepository.clear()
            return
        }
        
        await predictionRepository.loadCareData(vehicleId: vehicleId, token: token)
    }
    
    private func refreshCareData() async {
        guard let vehicleId = vehicleViewModel.activeVehicleId,
              let token = authViewModel.token else {
            return
        }
        
        await predictionRepository.refreshCareData(vehicleId: vehicleId, token: token)
    }
}

private struct CarePredictionsEmptyCard: View {
    let isRefreshing: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        AppCard(padding: AppSpacing.lg, cornerRadius: AppRadius.xl) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("PREDICTIONS PENDING")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.2)
                    
                    Text("No part predictions are available for this vehicle yet.")
                        .font(AppTypography.subtitle)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button(action: onRefresh) {
                        Text(isRefreshing ? "REFRESHING..." : "REFRESH PREDICTIONS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(AppColors.primary)
                            .tracking(1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                }
            }
        }
    }
}

private struct CareStatsGrid: View {
    let dashboard: VehicleDashboard?
    let eventStats: VehicleEventStats?
    let predictions: [Prediction]
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            CareStatCard(
                title: "REPAIR COST",
                value: repairCost,
                unit: "rub",
                icon: "wrench.adjustable.fill"
            )
            
            CareStatCard(
                title: "NEXT CHECK",
                value: nextCheckValue,
                unit: nextCheckUnit,
                icon: "gauge.with.dots.needle.67percent"
            )
        }
    }
    
    private var repairCost: String {
        let statsCost = eventStats?.repairCost
        let cost = statsCost.flatMap { $0 > 0 ? $0 : nil } ?? dashboard?.totalMaintenanceCost
        
        guard let cost else { return "--" }
        return cost.formatted(.number.precision(.fractionLength(0)))
    }
    
    private var nextCheckValue: String {
        if let date = nextPredictionDate {
            return date.shortCompactDateText
        }
        
        if let mileage = nextPredictionMileage {
            return mileage.formatted()
        }
        
        return "Pending"
    }
    
    private var nextCheckUnit: String {
        if nextPredictionDate != nil {
            return ""
        }
        
        if nextPredictionMileage != nil {
            return "km"
        }
        
        return ""
    }
    
    private var nextPredictionDate: String? {
        predictions
            .compactMap(\.predictedNextDate)
            .sortedByISODate()
            .first
    }
    
    private var nextPredictionMileage: Int? {
        predictions.compactMap(\.predictedNextMileage).min()
    }
}

private struct CareStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppColors.primary)
                .frame(width: 48, height: 48)
                .background(Color(hex: "EEF5FE"))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppColors.textMuted)
                    .tracking(1.1)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 186, alignment: .leading)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.xl)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 48))
        .overlay(
            RoundedRectangle(cornerRadius: 48)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct FocusPredictionCard: View {
    let prediction: Prediction
    let onDetails: () -> Void
    
    var body: some View {
        Button(action: onDetails) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    RiskIcon(level: prediction.riskLevel)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(prediction.partName)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Text(attentionText)
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(prediction.riskLevel.riskColor)
                            .tracking(1.1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(percentValue)
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text("%")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                    }
                }
                
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 10) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.primary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NEURAL PROJECTION")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(AppColors.textMuted)
                                .tracking(1.1)
                            
                            Text(remainingText)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    
                    Spacer()
                    
                    Text("View details")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppColors.primary)
                }
            }
            .padding(AppSpacing.lg)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(prediction.riskLevel.riskColor.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var attentionText: String {
        switch prediction.riskLevel {
        case .low:
            return "SYSTEM STABLE"
        case .medium:
            return "WATCH CLOSELY"
        case .high:
            return "ATTENTION REQUIRED"
        }
    }
    
    private var percentValue: String {
        guard let probability = prediction.probability else { return "--" }
        let normalized = probability <= 1 ? probability * 100 : probability
        return normalized.formatted(.number.precision(.fractionLength(0)))
    }
    
    private var remainingText: String {
        if let km = prediction.remainingKm {
            return "\(km.formatted()) km remaining"
        }
        
        if let days = prediction.remainingDays {
            return "\(days) days remaining"
        }
        
        return "Projection pending"
    }
}

private struct PredictiveEfficiencyCard: View {
    let dashboard: VehicleDashboard?
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PREDICTIVE EFFICIENCY")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.2)
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(statusColor)
                }
                
                Text("Digital twin suggests peak parameters for the next service cycle.")
                    .font(AppTypography.subtitle)
                    .italic()
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
    
    private var statusText: String {
        guard let level = dashboard?.predictionSummary?.riskLevel else {
            return "SYNCING"
        }
        
        switch level {
        case .low:
            return "+4.2% OPTIMIZED"
        case .medium:
            return "CHECK ADVISED"
        case .high:
            return "ACTION NEEDED"
        }
    }
    
    private var statusColor: Color {
        dashboard?.predictionSummary?.riskLevel?.riskColor ?? AppColors.primary
    }
}

private struct VehiclePartStatusRow: View {
    let part: VehiclePart
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppColors.primary)
                .frame(width: 48, height: 48)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(part.name)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(part.category?.uppercased() ?? "INSTALLED PART")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.1)
                    }
                    
                    Spacer()
                    
                    RiskBadge(level: nil)
                }
                
                HStack(spacing: AppSpacing.sm) {
                    if let mileage = part.lastServiceMileageKm ?? part.installedAtMileageKm {
                        CarePartMetaPill(icon: "speedometer", text: "\(mileage.formatted()) km")
                    }
                    
                    if let date = part.lastServiceDate {
                        CarePartMetaPill(icon: "calendar", text: date.shortCompactDateText)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch part.category?.lowercased() {
        case let category? where category.contains("brake"):
            return "exclamationmark.octagon.fill"
        case let category? where category.contains("fluid"):
            return "drop.fill"
        case let category? where category.contains("engine"):
            return "engine.combustion.fill"
        default:
            return "shippingbox.fill"
        }
    }
}

private struct CarePartMetaPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColors.background)
        .clipShape(Capsule())
    }
}

private struct DashboardSummaryCard: View {
    let dashboard: VehicleDashboard?
    let eventStats: VehicleEventStats?
    
    var body: some View {
        AppCard(padding: AppSpacing.lg, cornerRadius: AppRadius.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DIGITAL TWIN SUMMARY")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.4)
                        
                        Text(statusText)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(statusColor)
                    }
                    
                    Spacer()
                    
                    RiskBadge(level: dashboard?.predictionSummary?.riskLevel)
                }
                
                HStack(spacing: AppSpacing.sm) {
                    SummaryMetric(title: "LAST EVENT", value: lastEventTitle, icon: "calendar.badge.clock")
                    SummaryMetric(title: "EVENTS", value: eventsCount, icon: "list.bullet.rectangle")
                }
                
                HStack(spacing: AppSpacing.sm) {
                    SummaryMetric(title: "REPAIR COST", value: repairCost, icon: "wrench.and.screwdriver.fill")
                    SummaryMetric(title: "MILEAGE", value: mileage, icon: "speedometer")
                }
            }
        }
    }
    
    private var statusText: String {
        let rawStatus = dashboard?.status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        switch rawStatus {
        case "healthy", "ok", "good", "normal":
            return "Healthy"
        case "warning", "attention", "medium":
            return "Check advised"
        case "critical", "high", "danger":
            return "Action needed"
        case "syncing", "loading":
            return "Syncing"
        default:
            return riskBasedStatus
        }
    }
    
    private var statusColor: Color {
        dashboard?.predictionSummary?.riskLevel?.riskColor ?? AppColors.primary
    }
    
    private var riskBasedStatus: String {
        switch dashboard?.predictionSummary?.riskLevel {
        case .low:
            return "Healthy"
        case .medium:
            return "Check advised"
        case .high:
            return "Action needed"
        case nil:
            return dashboard == nil ? "Syncing" : "Ready"
        }
    }
    
    private var lastEventTitle: String {
        dashboard?.latestEvents.first?.title ?? "No events"
    }
    
    private var eventsCount: String {
        guard let count = dashboard?.totalEventsCount else { return "--" }
        return "\(count)"
    }
    
    private var repairCost: String {
        let statsCost = eventStats?.repairCost
        let cost = statsCost.flatMap { $0 > 0 ? $0 : nil } ?? dashboard?.totalMaintenanceCost
        
        guard let cost else { return "--" }
        return cost.formatted(.currency(code: "RUB").precision(.fractionLength(0)))
    }
    
    private var mileage: String {
        guard let mileage = dashboard?.currentMileage ?? dashboard?.vehicle?.mileageKm else { return "--" }
        return "\(mileage.formatted()) km"
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(AppColors.primary)
                .frame(width: 32, height: 32)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppColors.textMuted)
                    .tracking(1)
                
                Text(value)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

private struct PredictionRow: View {
    let prediction: Prediction
    
    var body: some View {
        AppCard(padding: AppSpacing.md, cornerRadius: AppRadius.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    RiskIcon(level: prediction.riskLevel)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(prediction.partName)
                            .font(AppTypography.h2)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Text(prediction.partCategory?.uppercased() ?? "VEHICLE PART")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.2)
                    }
                    
                    Spacer()
                    
                    RiskBadge(level: prediction.riskLevel)
                }
                
                HStack(spacing: AppSpacing.sm) {
                    PredictionMetric(
                        title: "REMAINING",
                        value: remainingText,
                        icon: "road.lanes"
                    )
                    
                    PredictionMetric(
                        title: "PROBABILITY",
                        value: probabilityText,
                        icon: "waveform.path.ecg"
                    )
                }
                
                Text(prediction.recommendation ?? "No recommendation yet.")
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    Text("View details")
                        .font(.system(size: 12, weight: .black))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .black))
                }
                .foregroundStyle(AppColors.primary)
            }
        }
    }
    
    private var remainingText: String {
        let km = prediction.remainingKm.map { "\($0.formatted()) km" }
        let days = prediction.remainingDays.map { "\($0) days" }
        return [km, days].compactMap { $0 }.joined(separator: " / ").nonEmpty ?? "--"
    }
    
    private var probabilityText: String {
        guard let probability = prediction.probability else { return "--" }
        return probability.percentText
    }
}

private struct PredictionMetric: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(AppColors.textMuted)
                    .tracking(0.8)
                
                Text(value)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct PredictionDetailView: View {
    let prediction: Prediction
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(prediction.partName)
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text(prediction.partCategory?.uppercased() ?? "VEHICLE PART")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.4)
                    }
                    
                    Spacer()
                    
                    RiskBadge(level: prediction.riskLevel)
                }
                
                HStack(spacing: AppSpacing.sm) {
                    DetailMetric(title: "RISK", value: prediction.riskLevel.title, color: prediction.riskLevel.riskColor)
                    DetailMetric(title: "CONFIDENCE", value: confidenceText, color: AppColors.primary)
                }
                
                detailSection(title: "EXPLANATION", text: prediction.explanation ?? "No explanation provided by the backend.")
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("TOP FACTORS")
                    
                    if prediction.factorList.isEmpty {
                        Text("No top factors provided.")
                            .font(AppTypography.subtitle)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        ForEach(prediction.factorList, id: \.self) { factor in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(prediction.riskLevel.riskColor)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 6)
                                
                                Text(factor)
                                    .font(AppTypography.subtitle)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
                
                detailSection(title: "RECOMMENDED ACTION", text: prediction.recommendation ?? "Keep monitoring this part.")
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sectionTitle("SERVICE WINDOW")
                    
                    Text(serviceWindow)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .padding(AppSpacing.xl)
        }
        .background(AppColors.background)
    }
    
    private var confidenceText: String {
        guard let confidence = prediction.displayConfidence else { return "--" }
        return confidence.percentText
    }
    
    private var serviceWindow: String {
        let mileage = prediction.predictedNextMileage.map { "around \($0.formatted()) km" }
        let date = prediction.predictedNextDate.map { "by \($0.shortDateText)" }
        let remaining = prediction.remainingKm.map { "\($0.formatted()) km remaining" }
        
        return [mileage, date, remaining].compactMap { $0 }.joined(separator: ", ").nonEmpty ?? "No service window available."
    }
    
    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle(title)
            
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(AppColors.textMuted)
            .tracking(1.4)
    }
}

private struct DetailMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AppColors.textMuted)
                .tracking(1.2)
            
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

private struct RiskIcon: View {
    let level: RiskLevel
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(level.riskColor)
            .frame(width: 44, height: 44)
            .background(level.riskColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var iconName: String {
        switch level {
        case .low:
            return "checkmark.seal.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "exclamationmark.octagon.fill"
        }
    }
}

private struct RiskBadge: View {
    let level: RiskLevel?
    
    var body: some View {
        Text(level?.title ?? "READY")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(color)
            .tracking(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
    
    private var color: Color {
        level?.riskColor ?? AppColors.primary
    }
}

private struct ErrorCard: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        AppCard(padding: AppSpacing.md, cornerRadius: AppRadius.lg) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AppColors.red)
                
                Text(message)
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Retry", action: retry)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AppColors.primary)
            }
        }
    }
}

private extension RiskLevel {
    var riskColor: Color {
        switch self {
        case .low:
            return AppColors.riskLow
        case .medium:
            return AppColors.riskMedium
        case .high:
            return AppColors.riskHigh
        }
    }
}

private extension Double {
    var percentText: String {
        let normalized = self <= 1 ? self : self / 100
        return normalized.formatted(.percent.precision(.fractionLength(0)))
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
    
    var shortCompactDateText: String {
        let formatter = ISO8601DateFormatter()
        
        if let date = formatter.date(from: self) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        
        return shortDateText
    }
    
    var shortDateText: String {
        let formatter = ISO8601DateFormatter()
        
        if let date = formatter.date(from: self) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        
        return self
    }
    
    var careDateText: String {
        let formatter = ISO8601DateFormatter()
        
        if let date = formatter.date(from: self) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        
        return self
    }
}

private extension Array where Element == String {
    func sortedByISODate() -> [String] {
        let formatter = ISO8601DateFormatter()
        
        return sorted { lhs, rhs in
            let lhsDate = formatter.date(from: lhs) ?? .distantFuture
            let rhsDate = formatter.date(from: rhs) ?? .distantFuture
            return lhsDate < rhsDate
        }
    }
}
