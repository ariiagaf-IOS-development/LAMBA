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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        switch rawValue {
        case "low", "healthy", "ok", "good", "normal":
            self = .low
        case "medium", "warning", "attention", "moderate":
            self = .medium
        case "high", "critical", "danger":
            self = .high
        default:
            self = .low
        }
    }
    
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        switch rawValue {
        case "rule_based":
            self = .ruleBased
        case "ml_service":
            self = .mlService
        default:
            self = .mock
        }
    }
}

struct PredictionResponse: Decodable {
    let vehicleId: Int?
    let predictions: [Prediction]
    
    private enum CodingKeys: String, CodingKey {
        case vehicleId
        case predictions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicleId = try container.decodeIfPresent(Int.self, forKey: .vehicleId)
        predictions = try container.decodeIfPresent([Prediction].self, forKey: .predictions) ?? []
    }
}

struct VehiclePartsResponse: Decodable {
    let parts: [VehiclePart]
}

struct VehiclePart: Decodable, Identifiable {
    let id: Int
    let vehicleId: Int?
    let name: String
    let category: String?
    let catalogCode: String?
    let installedAtMileageKm: Int?
    let lastServiceDate: String?
    let lastServiceMileageKm: Int?
    let createdAt: String?
    let updatedAt: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case vehicleId
        case name
        case category
        case catalogCode
        case installedAtMileageKm
        case lastServiceDate
        case lastServiceMileageKm
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicleId = try container.decodeIfPresent(Int.self, forKey: .vehicleId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Vehicle part"
        category = try container.decodeIfPresent(String.self, forKey: .category)
        catalogCode = try container.decodeIfPresent(String.self, forKey: .catalogCode)
        installedAtMileageKm = try container.decodeIfPresent(Int.self, forKey: .installedAtMileageKm)
        lastServiceDate = try container.decodeIfPresent(String.self, forKey: .lastServiceDate)
        lastServiceMileageKm = try container.decodeIfPresent(Int.self, forKey: .lastServiceMileageKm)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
            ?? StableFallbackId.make(vehicleId, name, catalogCode, createdAt)
    }
}

struct Prediction: Decodable, Identifiable {
    let id: Int
    let vehicleId: Int?
    let partName: String
    let partCategory: String?
    let partCode: String?
    let riskLevel: RiskLevel?
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
    
    private enum CodingKeys: String, CodingKey {
        case id
        case vehicleId
        case partName
        case partCategory
        case partCode
        case riskLevel
        case riskScore
        case remainingKm
        case remainingDays
        case probability
        case confidence
        case recommendation
        case explanation
        case topFactors
        case predictedNextDate
        case predictedNextMileage
        case modelVersion
        case source
        case createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicleId = try container.decodeIfPresent(Int.self, forKey: .vehicleId)
        partName = try container.decodeIfPresent(String.self, forKey: .partName) ?? "Vehicle part"
        partCategory = try container.decodeIfPresent(String.self, forKey: .partCategory)
        partCode = try container.decodeIfPresent(String.self, forKey: .partCode)
        riskLevel = try container.decodeIfPresent(RiskLevel.self, forKey: .riskLevel)
        riskScore = try container.decodeIfPresent(Int.self, forKey: .riskScore)
        remainingKm = try container.decodeIfPresent(Int.self, forKey: .remainingKm)
        remainingDays = try container.decodeIfPresent(Int.self, forKey: .remainingDays)
        probability = try container.decodeIfPresent(Double.self, forKey: .probability)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        topFactors = try container.decodeIfPresent([String].self, forKey: .topFactors)
        predictedNextDate = try container.decodeIfPresent(String.self, forKey: .predictedNextDate)
        predictedNextMileage = try container.decodeIfPresent(Int.self, forKey: .predictedNextMileage)
        modelVersion = try container.decodeIfPresent(String.self, forKey: .modelVersion)
        source = try container.decodeIfPresent(PredictionSource.self, forKey: .source)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
            ?? StableFallbackId.make(vehicleId, partName, partCode, createdAt)
    }
    
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

private enum StableFallbackId {
    static func make(_ parts: Any?...) -> Int {
        let value = parts
            .compactMap { $0 }
            .map { String(describing: $0) }
            .joined(separator: "|")
        
        let seed = value.isEmpty ? "care-item" : value
        let number = seed.unicodeScalars.reduce(17) { result, scalar in
            ((result &* 31) &+ Int(scalar.value)) & 0x3fffffff
        }
        
        return -max(1, number)
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
