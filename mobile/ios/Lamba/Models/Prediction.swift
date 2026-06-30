//
//  Prediction.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

enum RiskLevel: String, Decodable, CaseIterable {
    case low
    case medium
    case high
    
    var title: String {
        switch self {
        case .low:
            return "LOW"
        case .medium:
            return "MEDIUM"
        case .high:
            return "HIGH"
        }
    }
}

enum PredictionSource: String, Decodable {
    case ruleBased = "rule_based"
    case mock
    case mlService = "ml_service"
}

struct PredictionResponse: Decodable {
    let vehicleId: Int
    let predictions: [Prediction]
}

struct Prediction: Decodable, Identifiable {
    let id: Int
    let vehicleId: Int?
    let partName: String
    let partCategory: String?
    let partCode: String?
    let riskLevel: RiskLevel
    let riskScore: Int?
    let remainingKm: Int?
    let remainingDays: Int?
    let probability: Double?
    let confidence: Double?
    let recommendation: String?
    let explanation: String?
    let topFactors: [String]?
    let predictedNextDate: String?
    let predictedNextMileage: Int?
    let modelVersion: String?
    let source: PredictionSource?
    let createdAt: String?
    
    var displayConfidence: Double? {
        confidence ?? probability
    }
    
    var factorList: [String] {
        if let topFactors, !topFactors.isEmpty {
            return topFactors
        }
        
        let explanationFactors = explanation?
            .components(separatedBy: CharacterSet(charactersIn: ".;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if let explanationFactors, !explanationFactors.isEmpty {
            return Array(explanationFactors.prefix(3))
        }
        
        return [
            partCategory.map { "Part category: \($0)" },
            source.map { "Prediction source: \($0.rawValue.replacingOccurrences(of: "_", with: " "))" },
            modelVersion.map { "Model version: \($0)" }
        ].compactMap { $0 }
    }
}

struct VehicleDashboard: Decodable {
    let vehicle: DashboardVehicleSummary?
    let currentMileage: Int?
    let latestEvents: [DashboardEventPreview]
    let predictionSummary: DashboardPredictionSummary?
    let allPredictions: [Prediction]
    let status: String?
    let totalEventsCount: Int?
    let totalFuelExpenses: Double?
    let totalMaintenanceCost: Double?
    let totalRepairsCount: Int?
    
    private enum CodingKeys: String, CodingKey {
        case vehicle
        case currentMileage
        case latestEvents
        case predictionSummary
        case allPredictions
        case status
        case totalEventsCount
        case totalFuelExpenses
        case totalMaintenanceCost
        case totalRepairsCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicle = try container.decodeIfPresent(DashboardVehicleSummary.self, forKey: .vehicle)
        currentMileage = try container.decodeIfPresent(Int.self, forKey: .currentMileage)
        latestEvents = try container.decodeIfPresent([DashboardEventPreview].self, forKey: .latestEvents) ?? []
        predictionSummary = try container.decodeIfPresent(DashboardPredictionSummary.self, forKey: .predictionSummary)
        allPredictions = try container.decodeIfPresent([Prediction].self, forKey: .allPredictions) ?? []
        status = try container.decodeIfPresent(String.self, forKey: .status)
        totalEventsCount = try container.decodeIfPresent(Int.self, forKey: .totalEventsCount)
        totalFuelExpenses = try container.decodeIfPresent(Double.self, forKey: .totalFuelExpenses)
        totalMaintenanceCost = try container.decodeIfPresent(Double.self, forKey: .totalMaintenanceCost)
        totalRepairsCount = try container.decodeIfPresent(Int.self, forKey: .totalRepairsCount)
    }
}

struct DashboardVehicleSummary: Decodable {
    let id: Int
    let brand: String?
    let model: String?
    let year: Int?
    let mileageKm: Int?
    let vin: String?
}

struct DashboardEventPreview: Decodable, Identifiable {
    let id: Int
    let type: String?
    let title: String?
    let eventDate: String?
    let mileageKm: Int?
    let cost: Double?
}

struct DashboardPredictionSummary: Decodable {
    let partName: String?
    let partCategory: String?
    let riskLevel: RiskLevel?
    let riskScore: Int?
    let remainingKm: Int?
    let remainingDays: Int?
    let probability: Double?
    let recommendation: String?
    let modelVersion: String?
    let createdAt: String?
}
