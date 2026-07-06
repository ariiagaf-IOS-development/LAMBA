//
//  PredictionRepository.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation
import Combine

@MainActor
final class PredictionRepository: ObservableObject {
    
    @Published private(set) var predictions: [Prediction] = []
    @Published private(set) var parts: [VehiclePart] = []
    @Published private(set) var dashboard: VehicleDashboard?
    @Published private(set) var eventStats: VehicleEventStats?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var debugStatus: String?
    @Published var errorMessage: String?
    
    private let apiService: PredictionAPIService
    
    init(apiService: PredictionAPIService) {
        self.apiService = apiService
    }
    
    convenience init() {
        self.init(apiService: .shared)
    }
    
    func loadCareData(vehicleId: Int, token: String) async {
        isLoading = true
        errorMessage = nil
        
        await reloadCarePayload(vehicleId: vehicleId, token: token)
        
        isLoading = false
    }
    
    func refreshCareData(vehicleId: Int, token: String) async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            let refreshedPredictions = try await apiService.refreshPredictions(vehicleId: vehicleId, token: token)
            
            if !refreshedPredictions.predictions.isEmpty {
                predictions = refreshedPredictions.predictions
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        await reloadCarePayload(vehicleId: vehicleId, token: token)
        
        isRefreshing = false
    }
    
    private func reloadCarePayload(vehicleId: Int, token: String) async {
        var debugLines: [String] = []
        
        do {
            let loadedDashboard = try await apiService.getDashboard(vehicleId: vehicleId, token: token)
            dashboard = loadedDashboard
            debugLines.append(
                "dashboard ok: all_predictions \(loadedDashboard.allPredictions.count), summary \(loadedDashboard.predictionSummary == nil ? "no" : "yes")"
            )
        } catch {
            dashboard = nil
            debugLines.append("dashboard error: \(error.localizedDescription)")
        }
        
        do {
            let loadedPredictions = try await apiService.getPredictions(vehicleId: vehicleId, token: token)
            predictions = loadedPredictions.predictions
            errorMessage = nil
            debugLines.append("predictions ok: \(loadedPredictions.predictions.count)")
        } catch {
            predictions = []
            errorMessage = error.localizedDescription
            debugLines.append("predictions error: \(error.localizedDescription)")
        }
        
        if predictions.isEmpty, let dashboard, !dashboard.allPredictions.isEmpty {
            predictions = dashboard.allPredictions
            errorMessage = nil
            debugLines.append("used dashboard fallback: \(dashboard.allPredictions.count)")
        }
        
        do {
            let loadedParts = try await apiService.getVehicleParts(vehicleId: vehicleId, token: token).parts
            parts = loadedParts
            debugLines.append("parts ok: \(loadedParts.count)")
        } catch {
            parts = []
            debugLines.append("parts error: \(error.localizedDescription)")
        }
        
        do {
            let loadedStats = try await TimelineAPIService.shared
                .getEventStats(vehicleId: vehicleId, token: token)
                .stats
            eventStats = loadedStats
            debugLines.append("stats ok: \(loadedStats.totalEvents) events")
        } catch {
            eventStats = nil
            debugLines.append("stats error: \(error.localizedDescription)")
        }
        
        debugStatus = debugLines.joined(separator: "\n")
    }
    
    func clear() {
        predictions = []
        parts = []
        dashboard = nil
        eventStats = nil
        debugStatus = nil
        errorMessage = nil
    }
}
