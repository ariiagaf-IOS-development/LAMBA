//
//  AppCard.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct AppCard<Content: View>: View {
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(18)
    }
}
