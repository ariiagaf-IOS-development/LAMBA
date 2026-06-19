//
//  AIInputBar.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct AIInputBar: View {
    
    @Binding var text: String
    
    var body: some View {
        
        HStack(spacing: 12) {
            
            Circle()
                .fill(Color(hex: "F1F5F9"))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "plus")
                        .foregroundColor(Color(hex: "64748B"))
                )
            
            TextField("Ask LAMBA AI...", text: $text)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "111827"))
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "6366F1"),
                            Color(hex: "393B8B")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "arrow.up")
                        .foregroundColor(.white)
                )
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
}
