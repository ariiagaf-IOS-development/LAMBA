//
//  AIChatView.swift
//  Lamba
//

import SwiftUI

struct AIChatView: View {
    
    @Binding var selectedTab: AppTab
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var isEditingCreatedVehicle = false
    @State private var showsClearHistoryAlert = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                chatHeader
                
                heroSection
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, 10)
                    .background(AppColors.background)
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                                                        
                            ForEach(chatViewModel.messages) { message in
                                ChatBubble(
                                    message: message,
                                    vehicleImageData: message.attachment?.vehiclePhotoId.flatMap {
                                        vehicleViewModel.getImage(for: $0)
                                    },
                                    chatPhotoData: message.attachment?.chatPhotoData
                                )
                                    .id(message.id)
                                
                                if chatViewModel.createdVehicleCardAnchorId == message.id,
                                   let vehicle = vehicleViewModel.activeVehicle {
                                    CreatedVehicleMiniCard(vehicle: vehicle) {
                                        isEditingCreatedVehicle = true
                                    }
                                    .id("createdVehicleCard")
                                }
                            }
                            
                            if vehicleViewModel.activeVehicle != nil,
                               chatViewModel.shouldShowSuggestedQuestions {
                                SuggestedQuestionsView(
                                    questions: chatViewModel.suggestedQuestions,
                                    onTap: { question in
                                        Task {
                                            await chatViewModel.sendSuggestedQuestion(
                                                question,
                                                vehicleViewModel: vehicleViewModel,
                                                token: authViewModel.token
                                            )
                                        }
                                    }
                                )
                            }
                            
                            if chatViewModel.isLoading {
                                TypingIndicator()
                                    .id("loading")
                            }
                            
                            if let errorMessage = chatViewModel.errorMessage {
                                ErrorChatCard(
                                    message: errorMessage,
                                    onRetry: {
                                        Task {
                                            await chatViewModel.retryLastMessage(
                                                vehicleViewModel: vehicleViewModel,
                                                token: authViewModel.token
                                            )
                                        }
                                    }
                                )
                                .id("error")
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.md)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: chatViewModel.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: chatViewModel.isLoading) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: chatViewModel.shouldShowCreatedVehicleCard) { _, _ in
                        scrollToBottom(proxy)
                    }
                }
            }
        }
        .task(id: vehicleViewModel.activeVehicleId) {
            await chatViewModel.loadHistory(
                vehicle: vehicleViewModel.activeVehicle,
                token: authViewModel.token
            )
        }
        .onChange(of: vehicleViewModel.activeVehicleId) { oldValue, newValue in
            if oldValue != nil, newValue == nil {
                chatViewModel.resetToNoVehicleState(previousVehicleId: oldValue)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .localSessionCachesDidClear)) { _ in
            chatViewModel.clearLocalSessionState()
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputBar(
                text: $chatViewModel.inputText,
                isLoading: chatViewModel.isLoading,
                isDisabled: false
            ) {
                Task {
                    await chatViewModel.sendMessage(
                        vehicleViewModel: vehicleViewModel,
                        token: authViewModel.token
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .background(AppColors.background.opacity(0.96))
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.hideKeyboard()
            }
        )
        .fullScreenCover(isPresented: $isEditingCreatedVehicle) {
            AddVehicleView(
                mode: .edit,
                onClose: {
                    isEditingCreatedVehicle = false
                }
            )
            .environmentObject(vehicleViewModel)
            .environmentObject(authViewModel)
        }
        .alert("Clear chat history?", isPresented: $showsClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            
            Button("Clear chat", role: .destructive) {
                Task {
                    await chatViewModel.clearHistory(
                        vehicle: vehicleViewModel.activeVehicle,
                        token: authViewModel.token
                    )
                }
            }
        } message: {
            Text("This removes the AI chat history for the selected vehicle from the backend and this device.")
        }
    }
    
    private var chatHeader: some View {
        ZStack {
            Text("LAMBA AI")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
                .textCase(.uppercase)
                .tracking(1.5)
            
            HStack {
                chatStatusPill
                
                Spacer()
                
                if vehicleViewModel.activeVehicle != nil {
                    Button {
                        showsClearHistoryAlert = true
                    } label: {
                        Image(systemName: chatViewModel.isClearingHistory ? "hourglass" : "trash.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(AppColors.red)
                            .frame(width: 34, height: 34)
                            .background(AppColors.red.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(chatViewModel.isLoading || chatViewModel.isClearingHistory)
                    .accessibilityLabel("Clear chat")
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(AppColors.card.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(AppColors.bubbleBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var chatStatusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vehicleViewModel.activeVehicle == nil ? AppColors.orange : AppColors.green)
                .frame(width: 6, height: 6)
            
            Text(vehicleViewModel.activeVehicle == nil ? "NO VEHICLE" : "LINK ACTIVE")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(vehicleViewModel.activeVehicle == nil ? AppColors.orange : AppColors.green)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(vehicleViewModel.activeVehicle == nil ? AppColors.orange.opacity(0.10) : Color(hex: "ECFDF5"))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.pill)
                .stroke(vehicleViewModel.activeVehicle == nil ? AppColors.orange.opacity(0.25) : Color(hex: "D0FAE5"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill))
    }
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HI, \(displayName.uppercased())")
                .font(AppTypography.h1)
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 0)
            
            Text(heroSubtitle)
                .font(AppTypography.h2)
                .italic()
                .foregroundColor(AppColors.primary)
                .frame(maxWidth: 280, alignment: .leading)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var displayName: String {
        let firstName = authViewModel.currentUser?.firstName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let firstName, !firstName.isEmpty {
            return firstName
        }
        
        return "there"
    }
    
    private var heroSubtitle: String {
        if let vehicle = vehicleViewModel.activeVehicle {
            return "Your \(vehicle.brand) \(vehicle.model) AI assistant is ready."
        }
        
        return "Add a vehicle first, and I will become its digital twin."
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

private struct ChatMessageText: View {
    
    let text: String
    let isUser: Bool
    
    var body: some View {
        formattedText
            .foregroundStyle(isUser ? .white : AppColors.textPrimary)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var formattedText: Text {
        Text(text.markdownBoldAttributedString())
    }
}

private struct ChatBubble: View {
    
    let message: ChatUIMessage
    let vehicleImageData: Data?
    let chatPhotoData: Data?
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 48)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 10) {
                if message.attachment?.vehiclePhotoId != nil {
                    ChatVehiclePhotoCard(imageData: vehicleImageData)
                } else {
                    if let chatPhotoData {
                        ChatAttachedPhotoCard(imageData: chatPhotoData, isUser: isUser)
                    }
                    
                    ChatMessageText(
                        text: message.text,
                        isUser: isUser
                    )
                    .padding(16)
                    .background(isUser ? AppColors.primary : AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xl)
                            .stroke(isUser ? Color.clear : AppColors.bubbleBorder, lineWidth: 1)
                    )
                }
                
                if let prediction = message.prediction {
                    PredictionInlineCard(prediction: prediction)
                }
            }
            
            if !isUser {
                Spacer(minLength: 48)
            }
        }
    }
}

private struct ChatAttachedPhotoCard: View {
    let imageData: Data
    let isUser: Bool
    
    var body: some View {
        Group {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xl)
                            .stroke(isUser ? Color.clear : AppColors.bubbleBorder, lineWidth: 1)
                    )
            }
        }
    }
}

private struct ChatVehiclePhotoCard: View {
    
    let imageData: Data?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(AppColors.primary.opacity(0.10))
                        .frame(width: 220, height: 132)
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(AppColors.primary)
                }
            }
            
            HStack(spacing: 10) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppColors.primary)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("PHOTO LINKED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textSecondary)
                        .tracking(1.1)
                    
                    Text("Saved to vehicle profile")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                }
            }
        }
        .padding(12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct PredictionInlineCard: View {
    
    let prediction: ChatPrediction
    
    private var riskText: String {
        prediction.riskLevel ?? "Unknown"
    }
    
    private var riskColor: Color {
        switch riskText.lowercased() {
        case "low":
            return AppColors.green
        case "medium":
            return AppColors.yellow
        case "high":
            return AppColors.orange
        default:
            return AppColors.primary
        }
    }
    
    private var confidenceText: String {
        guard let confidence = prediction.confidence else {
            return "Not available"
        }
        
        if confidence <= 1 {
            return "\(Int(confidence * 100))%"
        }
        
        return "\(Int(confidence))%"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(riskColor.opacity(0.14))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(riskColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("PREDICTION EXPLANATION")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textSecondary)
                        .tracking(1.2)
                    
                    Text("AI-generated maintenance insight")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                }
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                PredictionMetricPill(
                    title: "RISK",
                    value: riskText.uppercased(),
                    color: riskColor
                )
                
                PredictionMetricPill(
                    title: "CONFIDENCE",
                    value: confidenceText,
                    color: AppColors.primary
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("RECOMMENDED ACTION")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(1.2)
                
                Text(prediction.displayRecommendation)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

private struct PredictionMetricPill: View {
    
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(1)
            
            Text(value)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct TypingIndicator: View {
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("I am thinking...")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .appCard()
            
            Spacer()
        }
    }
}

private struct ErrorChatCard: View {
    
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.orange)
            
            Button {
                onRetry()
            } label: {
                Text("Retry")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .appCard()
    }
}

private struct SuggestedQuestionsView: View {
    
    let questions: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUGGESTED QUESTIONS")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(1.2)
            
            VStack(spacing: 8) {
                ForEach(questions, id: \.self) { question in
                    Button {
                        onTap(question)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColors.primary)
                            
                            Text(question)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textPrimary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .appCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CreatedVehicleMiniCard: View {
    
    let vehicle: VehicleResponse
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .fill(AppColors.primary.opacity(0.10))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("DIGITAL TWIN CREATED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textSecondary)
                        .tracking(1.1)
                    
                    Text("\(vehicle.brand) \(vehicle.model)")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    Text("\(vehicle.year) · \(vehicle.mileageKm) km")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                    
                    Text("Tap to add photo or edit profile")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AppColors.primary)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }
}

private struct ChatInputBar: View {
    
    @Binding var text: String
    
    let isLoading: Bool
    let isDisabled: Bool
    let onSend: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField(
                    "Ask your digital twin...",
                    text: $text,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textPrimary)
                .disabled(isDisabled || isLoading)
                
                Button {
                    UIApplication.shared.hideKeyboard()
                    onSend()
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? AppColors.primary : AppColors.textMuted.opacity(0.4))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: isLoading ? "hourglass" : "arrow.up")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(!canSend)
            }
        }
        .padding(10)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading &&
        !isDisabled
    }
}

private extension String {
    
    func markdownBoldAttributedString() -> AttributedString {
        let parts = boldPartsFromMarkdown()
        var result = AttributedString()
        
        for part in parts {
            var attributedPart = AttributedString(part.text)
            attributedPart.font = .system(size: 12, weight: part.isBold ? .bold : .regular)
            result += attributedPart
        }
        
        return result
    }
    
    func boldPartsFromMarkdown() -> [(text: String, isBold: Bool)] {
        var result: [(text: String, isBold: Bool)] = []
        var currentText = ""
        var isInsideBold = false
        
        var index = startIndex
        
        while index < endIndex {
            let nextIndex = self.index(after: index)
            
            if self[index] == "*",
               nextIndex < endIndex,
               self[nextIndex] == "*" {
                
                if !currentText.isEmpty {
                    result.append((currentText, isInsideBold))
                    currentText = ""
                }
                
                isInsideBold.toggle()
                index = self.index(after: nextIndex)
            } else {
                currentText.append(self[index])
                index = self.index(after: index)
            }
        }
        
        if !currentText.isEmpty {
            result.append((currentText, isInsideBold))
        }
        
        return result
    }
}
