//
//  ChatRepository.swift
//  Lamba
//

import Foundation

final class ChatRepository {
    
    private let apiService: ChatAPIService
    
    init(apiService: ChatAPIService = .shared) {
        self.apiService = apiService
    }
    
    func sendMessage(
        vehicleId: Int,
        message: String,
        token: String
    ) async throws -> ChatResponse {
        try await apiService.sendMessage(
            vehicleId: vehicleId,
            message: message,
            token: token
        )
    }
    
    func loadHistory(
        vehicleId: Int,
        token: String
    ) async throws -> [ChatMessageResponse] {
        try await apiService.getHistory(
            vehicleId: vehicleId,
            token: token
        )
    }
    
    func clearHistory(
        vehicleId: Int,
        token: String
    ) async throws {
        try await apiService.clearHistory(
            vehicleId: vehicleId,
            token: token
        )
    }
}
