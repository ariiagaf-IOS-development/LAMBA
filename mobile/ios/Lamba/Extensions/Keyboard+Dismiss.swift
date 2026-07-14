//
//  Keyboard+Dismiss.swift
//  Lamba
//
//  Created by Арина Агафонова on 28.06.2026.
//

import SwiftUI

extension UIApplication {
    func hideKeyboard() {
        sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.hideKeyboard()
        }
    }
}
