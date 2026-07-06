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
    @Published private(set) var dashboard: VehicleDashboard?
    @Published private(set) var eventStats: VehicleEventStats?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
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
        
        do {
            let loadedDashboard = try await apiService.getDashboard(vehicleId: vehicleId, token: token)
            dashboard = loadedDashboard
        } catch {
            dashboard = nil
        }
        
        do {
            let loadedPredictions = try await apiService.getPredictions(vehicleId: vehicleId, token: token)
            predictions = loadedPredictions.predictions
        } catch {
            predictions = []
            errorMessage = error.localizedDescription
        }
        
        if predictions.isEmpty, let dashboard, !dashboard.allPredictions.isEmpty {
            predictions = dashboard.allPredictions
            errorMessage = nil
        }
        
        eventStats = try? await TimelineAPIService.shared
            .getEventStats(vehicleId: vehicleId, token: token)
            .stats
        
        isLoading = false
    }
    
    func refreshCareData(vehicleId: Int, token: String) async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            let refreshedPredictions = try await apiService.refreshPredictions(vehicleId: vehicleId, token: token)
            predictions = refreshedPredictions.predictions
            
            do {
                async let dashboardResponse = apiService.getDashboard(vehicleId: vehicleId, token: token)
                async let eventStatsResponse = TimelineAPIService.shared.getEventStats(vehicleId: vehicleId, token: token)
                
                let (loadedDashboard, loadedEventStats) = try await (dashboardResponse, eventStatsResponse)
                dashboard = loadedDashboard
                eventStats = loadedEventStats.stats
            } catch {
                dashboard = try? await apiService.getDashboard(vehicleId: vehicleId, token: token)
                eventStats = try? await TimelineAPIService.shared
                    .getEventStats(vehicleId: vehicleId, token: token)
                    .stats
            }
            
            if predictions.isEmpty, let dashboard, !dashboard.allPredictions.isEmpty {
                predictions = dashboard.allPredictions
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRefreshing = false
    }
    
    func clear() {
        predictions = []
        dashboard = nil
        eventStats = nil
        errorMessage = nil
    }
}
