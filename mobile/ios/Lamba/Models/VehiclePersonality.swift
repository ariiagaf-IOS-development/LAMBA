//
//  VehiclePersonality.swift
//  Lamba
//

import Foundation

enum VehiclePersonality: String, Codable, CaseIterable, Identifiable {
    case pickMe = "pick_me"
    case diva
    case zen
    case sprinter
    case nerd
    case oldSoul = "old_soul"
    case workhorse
    case rebel
    case bmwRoast = "bmw_roast"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .pickMe:
            return "PICK-ME"
        case .diva:
            return "DIVA"
        case .zen:
            return "ZEN"
        case .sprinter:
            return "SPRINTER"
        case .nerd:
            return "NERD"
        case .oldSoul:
            return "OLD SOUL"
        case .workhorse:
            return "WORKHORSE"
        case .rebel:
            return "REBEL"
        case .bmwRoast:
            return "BMW ROAST MODE"
        }
    }
    
    var subtitle: String {
        switch self {
        case .pickMe:
            return "Craves attention, compliments, and perfect diagnostics."
        case .diva:
            return "Stylish, dramatic, and allergic to being ignored."
        case .zen:
            return "Calm, smooth, and emotionally fuel-efficient."
        case .sprinter:
            return "Fast-minded, alert, and a little impatient."
        case .nerd:
            return "Data-obsessed, precise, and proud of every sensor."
        case .oldSoul:
            return "Wise, nostalgic, and loyal through every kilometer."
        case .workhorse:
            return "Practical, sturdy, and quietly carrying the whole team."
        case .rebel:
            return "Independent, sharp, and not here for boring routes."
        case .bmwRoast:
            return "A premium ego delivery system with blinkers installed purely for decoration."
        }
    }
    
    var aiLine: String {
        switch self {
        case .pickMe:
            return "Please notice my excellent condition."
        case .diva:
            return "I expect premium care and immediate admiration."
        case .zen:
            return "I prefer smooth routes and calm maintenance."
        case .sprinter:
            return "I am ready before you even open the map."
        case .nerd:
            return "I brought data, confidence scores, and opinions."
        case .oldSoul:
            return "I have stories in my mileage."
        case .workhorse:
            return "Give me a job and a clean service log."
        case .rebel:
            return "I know a better route."
        case .bmwRoast:
            return "BMW detected. I will now act expensive, offended, and allergic to turn signals."
        }
    }
    
    var iconName: String {
        switch self {
        case .pickMe:
            return "sparkles"
        case .diva:
            return "crown.fill"
        case .zen:
            return "leaf.fill"
        case .sprinter:
            return "bolt.fill"
        case .nerd:
            return "cpu.fill"
        case .oldSoul:
            return "clock.fill"
        case .workhorse:
            return "wrench.and.screwdriver.fill"
        case .rebel:
            return "flame.fill"
        case .bmwRoast:
            return "exclamationmark.bubble.fill"
        }
    }
    
    static func inferred(brand: String, model: String) -> VehiclePersonality {
        let signature = "\(brand) \(model)".lowercased()
        
        if signature.contains("bmw") {
            return .bmwRoast
        }
        
        if signature.contains("tesla") || signature.contains("model") || signature.contains("electric") {
            return .nerd
        }
        
        if signature.contains("mercedes") || signature.contains("porsche") || signature.contains("lexus") {
            return .diva
        }
        
        if signature.contains("mini") || signature.contains("fiat") || signature.contains("beetle") {
            return .pickMe
        }
        
        if signature.contains("mustang") || signature.contains("camaro") || signature.contains("dodge") {
            return .rebel
        }
        
        if signature.contains("toyota") || signature.contains("honda") || signature.contains("subaru") {
            return .zen
        }
        
        if signature.contains("ford") || signature.contains("truck") || signature.contains("transit") || signature.contains("van") {
            return .workhorse
        }
        
        if signature.contains("classic") || signature.contains("volga") || signature.contains("lada") {
            return .oldSoul
        }
        
        if signature.contains("sport") || signature.contains("rs") || signature.contains("amg") || signature.contains("gt") {
            return .sprinter
        }
        
        return .pickMe
    }
}

extension VehiclePersonality {
    init?(backendValue: String?) {
        guard let backendValue else {
            return nil
        }
        
        let normalized = backendValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        
        switch normalized {
        case "pick_me", "pickme":
            self = .pickMe
        case "diva":
            self = .diva
        case "zen":
            self = .zen
        case "sprinter", "sport":
            self = .sprinter
        case "nerd", "geek":
            self = .nerd
        case "old_soul", "oldsoul":
            self = .oldSoul
        case "workhorse":
            self = .workhorse
        case "rebel":
            self = .rebel
        case "bmw_roast", "bmw", "bmw_therapy":
            self = .bmwRoast
        default:
            return nil
        }
    }
}
