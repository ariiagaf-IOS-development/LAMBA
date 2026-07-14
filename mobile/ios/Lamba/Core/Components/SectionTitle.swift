//
//  SectionTitle.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct SectionTitle: View {
    
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}
