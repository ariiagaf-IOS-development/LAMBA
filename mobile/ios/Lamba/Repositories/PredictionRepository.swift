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
            async let predictionsResponse = apiService.getPredictions(vehicleId: vehicleId, token: token)
            async let dashboardResponse = apiService.getDashboard(vehicleId: vehicleId, token: token)
            
            let (loadedPredictions, loadedDashboard) = try await (
                predictionsResponse,
                dashboardResponse
            )
            predictions = loadedPredictions.predictions
            dashboard = loadedDashboard
            
            if predictions.isEmpty, !loadedDashboard.allPredictions.isEmpty {
                predictions = loadedDashboard.allPredictions
            }
        } catch {
            errorMessage = error.localizedDescription
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
