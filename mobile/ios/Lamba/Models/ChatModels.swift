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
    let message: String?
    let response: String?
    let answer: String?
    let role: String?
    let prediction: ChatPrediction?
    
    var assistantText: String {
        message ?? response ?? answer ?? "I could not generate a response."
    }
}

struct ChatHistoryResponse: Decodable {
    let messages: [ChatMessageResponse]
}

struct ChatMessageResponse: Decodable, Identifiable {
    let id: Int?
    let role: String
    let message: String?
    let content: String?
    let text: String?
    let createdAt: String?
    let prediction: ChatPrediction?
    
    var displayId: String {
        if let id {
            return String(id)
        }
        
        return UUID().uuidString
    }
    
    var displayText: String {
        message ?? content ?? text ?? ""
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
