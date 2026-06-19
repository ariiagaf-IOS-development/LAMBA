//
//  ChatMessage.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}
