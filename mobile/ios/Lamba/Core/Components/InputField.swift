//
//  InputField.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct InputField: View {
    
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}
