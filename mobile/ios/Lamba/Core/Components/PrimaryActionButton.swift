//
//  PrimaryActionButton.swift
//  Lamba
//
//  Created by Арина Агафонова on 19.06.2026.
//

import SwiftUI

struct PrimaryActionButton: View {
    
    let title: String
    let colors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .tracking(1.5)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
        }
    }
}
