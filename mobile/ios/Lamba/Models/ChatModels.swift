//
//  ChatModels.swift
//  Lamba
//
//  Created by Арина Агафонова on 28.06.2026.
//

import Foundation

struct ChatMessageRequest: Encodable {
    let message: String
}

struct ChatResponse: Decodable {
    let message: ChatMessageResponse
    
    var assistantText: String {
        message.displayText
    }
    
    var prediction: ChatPrediction? {
        nil
    }
}

struct ChatHistoryResponse: Decodable {
    let count: Int?
    let limit: Int?
    let offset: Int?
    let vehicleId: Int?
    let messages: [ChatMessageResponse]
}

struct ChatMessageResponse: Decodable {
    let id: Int?
    let vehicleId: Int?
    let userId: Int?
    let role: String
    let message: String
    let createdAt: String?
    
    var displayText: String {
        message
    }
}

struct ChatPrediction: Codable {
    let riskLevel: String?
    let confidence: Double?
    let recommendedAction: String?
    let recommendation: String?
    
    var displayRecommendation: String {
        recommendedAction ?? recommendation ?? "No recommendation available."
    }
}
