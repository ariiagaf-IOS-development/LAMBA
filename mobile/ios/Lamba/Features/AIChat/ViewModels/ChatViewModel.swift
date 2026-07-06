//
//  ChatViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 28.06.2026.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ChatViewModel: ObservableObject {
    
    @Published var messages: [ChatUIMessage] = []
    @Published var inputText: String = ""
    @Published var pendingPhotoData: Data?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var isVehicleOnboardingActive: Bool = false
    @Published var shouldShowCreatedVehicleCard: Bool = false
    @Published var createdVehicleCardAnchorId: UUID?

    private var onboardingStep: VehicleOnboardingStep = .brand
    private var onboardingDraft = VehicleOnboardingDraft()
    
    let suggestedQuestions: [String] = [
        "What is my current condition?",
        "What maintenance should I check next?",
        "Do I have any risky parts?",
        "What should I do before a long trip?"
    ]
    
    private var loadedVehicleId: Int?
    
    private var cachedMessagesByVehicleId: [Int: [ChatUIMessage]] = [:]
    
    private let repository: ChatRepository
    
    private let localCacheKey = "local_chat_messages_by_vehicle_id"
    
    init(repository: ChatRepository) {
        self.repository = repository
    }
    
    convenience init() {
        self.init(repository: ChatRepository())
    }
    
    func loadHistory(
        vehicle: VehicleResponse?,
        token: String?,
        forceReload: Bool = false
    ) async {
        loadLocalCacheIfNeeded()
        
        guard let vehicle else {
            if messages.isEmpty {
                showEmptyVehicleGreeting()
            }
            return
        }

        isVehicleOnboardingActive = false
        onboardingStep = .completed
        shouldShowCreatedVehicleCard = false
        createdVehicleCardAnchorId = nil
        
        if let cachedMessages = cachedMessagesByVehicleId[vehicle.id],
           (!forceReload || messages.isEmpty) {
            messages = cachedMessages
        }
        
        if !forceReload,
           loadedVehicleId == vehicle.id,
           !messages.isEmpty {
            return
        }
        
        guard let token else {
            errorMessage = "Please sign in again to continue chatting."
            return
        }
        
        loadedVehicleId = vehicle.id
        isLoading = true
        errorMessage = nil
        
        do {
            let history = try await repository.loadHistory(
                vehicleId: vehicle.id,
                token: token
            )
            
            let backendMessages = history.map { message in
                ChatUIMessage(
                    role: ChatRole(rawValue: message.role.lowercased()) ?? .assistant,
                    text: message.displayText,
                    prediction: nil,
                    attachment: nil
                )
            }
            
            if backendMessages.isEmpty {
                if cachedMessagesByVehicleId[vehicle.id]?.isEmpty == false {
                    messages = cachedMessagesByVehicleId[vehicle.id] ?? []
                } else {
                    showVehicleGreeting(vehicle: vehicle)
                }
            } else {
                messages = mergedHistory(
                    backendMessages: backendMessages,
                    localMessages: cachedMessagesByVehicleId[vehicle.id] ?? []
                )
                cachedMessagesByVehicleId[vehicle.id] = messages
                saveLocalCache()
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
            
            if messages.isEmpty {
                showVehicleGreeting(vehicle: vehicle)
            }
        }
        
        isLoading = false
    }
    
    func sendMessage(
        vehicleViewModel: VehicleViewModel,
        token: String?
    ) async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingAttachment = pendingPhotoData.map { ChatMessageAttachment.chatPhoto(data: $0) }
        
        guard !trimmedText.isEmpty || pendingAttachment != nil else {
            return
        }
        
        if vehicleViewModel.activeVehicle == nil {
            inputText = ""
            
            if !isVehicleOnboardingActive {
                showEmptyVehicleGreeting()
            }
            
            await handleVehicleOnboardingAnswer(
                trimmedText,
                vehicleViewModel: vehicleViewModel,
                token: token
            )
            
            return
        }

        if isVehicleOnboardingActive {
            isVehicleOnboardingActive = false
            onboardingStep = .completed
        }
        
        guard let vehicle = vehicleViewModel.activeVehicle else {
            errorMessage = "Create a vehicle first so I can become your digital twin."
            return
        }
        
        guard let token else {
            errorMessage = "Please sign in again to continue chatting."
            return
        }
        
        let userMessage = ChatUIMessage(
            role: .user,
            text: trimmedText.isEmpty ? "Please inspect this photo." : trimmedText,
            prediction: nil,
            attachment: pendingAttachment
        )
        
        messages.append(userMessage)
        cachedMessagesByVehicleId[vehicle.id] = messages
        saveLocalCache()
        
        inputText = ""
        pendingPhotoData = nil
        isLoading = true
        errorMessage = nil
        
        do {
            let backendMessage = pendingAttachment == nil
            ? trimmedText
            : "\(trimmedText.isEmpty ? "Please inspect this photo." : trimmedText)\n\n[Photo attached in the mobile app.]"
            
            let response = try await repository.sendMessage(
                vehicleId: vehicle.id,
                message: backendMessage,
                token: token
            )
            
            let assistantMessage = ChatUIMessage(
                role: .assistant,
                text: response.assistantText,
                prediction: response.prediction,
                attachment: nil
            )

            messages.append(assistantMessage)
            cachedMessagesByVehicleId[vehicle.id] = messages
            saveLocalCache()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
        
        isLoading = false
    }
    
    func sendSuggestedQuestion(
        _ question: String,
        vehicleViewModel: VehicleViewModel,
        token: String?
    ) async {
        inputText = question
        await sendMessage(
            vehicleViewModel: vehicleViewModel,
            token: token
        )
    }
    
    func retryLastMessage(
        vehicleViewModel: VehicleViewModel,
        token: String?
    ) async {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else {
            return
        }
        
        inputText = lastUserMessage.text
        
        await sendMessage(
            vehicleViewModel: vehicleViewModel,
            token: token
        )
    }
    
    private func showVehicleGreeting(vehicle: VehicleResponse) {
        let personality = VehiclePersonality.inferred(
            brand: vehicle.brand,
            model: vehicle.model
        )
        
        messages = [
            ChatUIMessage(
                role: .assistant,
                text: "I am your \(vehicle.brand) \(vehicle.model) digital twin.\n\nPersonality core: **\(personality.title)**. \(personality.aiLine)\n\nAsk me about my condition, maintenance risks, repair history, or what I may need next.",
                prediction: nil,
                attachment: nil
            )
        ]
        
        cachedMessagesByVehicleId[vehicle.id] = messages
        saveLocalCache()
    }
    
    private func showEmptyVehicleGreeting() {
        isVehicleOnboardingActive = true
        shouldShowCreatedVehicleCard = false
        createdVehicleCardAnchorId = nil
        onboardingStep = .brand
        onboardingDraft = VehicleOnboardingDraft()
        
        messages = [
            ChatUIMessage(
                role: .assistant,
                text: "I do not exist yet — but we can create me together. Let’s start with my identity. What is my brand?",
                prediction: nil,
                attachment: nil
            )
        ]
    }
    
    private func saveLocalCache() {
        do {
            let encoded = try JSONEncoder().encode(cachedMessagesByVehicleId)
            UserDefaults.standard.set(encoded, forKey: localCacheKey)
        } catch {
            print("Failed to save local chat cache:", error.localizedDescription)
        }
    }

    private func loadLocalCacheIfNeeded() {
        guard cachedMessagesByVehicleId.isEmpty,
              let data = UserDefaults.standard.data(forKey: localCacheKey) else {
            return
        }
        
        do {
            cachedMessagesByVehicleId = try JSONDecoder().decode(
                [Int: [ChatUIMessage]].self,
                from: data
            )
        } catch {
            print("Failed to load local chat cache:", error.localizedDescription)
        }
    }
    
    private func handleVehicleOnboardingAnswer(
        _ answer: String,
        vehicleViewModel: VehicleViewModel,
        token: String?
    ) async {
        messages.append(
            ChatUIMessage(
                role: .user,
                text: answer,
                prediction: nil,
                attachment: nil
            )
        )
        
        switch onboardingStep {
        case .brand:
            onboardingDraft.brand = answer
            onboardingStep = .model
            
            messages.append(
                ChatUIMessage(
                    role: .assistant,
                    text: "Great. What is my model?",
                    prediction: nil,
                    attachment: nil
                )
            )
            
        case .model:
            onboardingDraft.model = answer
            onboardingStep = .year
            
            messages.append(
                ChatUIMessage(
                    role: .assistant,
                    text: "What year was I produced?",
                    prediction: nil,
                    attachment: nil
                )
            )
            
        case .year:
            let cleanYear = answer.filter { $0.isNumber }
            
            guard !cleanYear.isEmpty else {
                messages.append(
                    ChatUIMessage(
                        role: .assistant,
                        text: "Please send my production year as digits, for example 2022.",
                        prediction: nil,
                        attachment: nil
                    )
                )
                return
            }
            
            onboardingDraft.year = cleanYear
            onboardingStep = .mileage
            
            messages.append(
                ChatUIMessage(
                    role: .assistant,
                    text: "How many kilometers have I traveled so far?",
                    prediction: nil,
                    attachment: nil
                )
            )
            
        case .mileage:
            let cleanMileage = answer.filter { $0.isNumber }
            
            guard !cleanMileage.isEmpty else {
                messages.append(
                    ChatUIMessage(
                        role: .assistant,
                        text: "Please send my mileage as a number in kilometers, for example 42000.",
                        prediction: nil,
                        attachment: nil
                    )
                )
                return
            }
            
            onboardingDraft.mileage = cleanMileage
            onboardingStep = .vin
            
            messages.append(
                ChatUIMessage(
                    role: .assistant,
                    text: "What is my 17-character VIN?",
                    prediction: nil,
                    attachment: nil
                )
            )
            
        case .vin:
            let cleanVIN = answer
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            
            guard cleanVIN.count == 17 else {
                messages.append(
                    ChatUIMessage(
                        role: .assistant,
                        text: "Please send my VIN as exactly 17 characters. For example: JTDBE32K620123456.",
                        prediction: nil,
                        attachment: nil
                    )
                )
                return
            }
            
            onboardingDraft.vin = cleanVIN
            
            guard let token else {
                errorMessage = "Please sign in again so I can create my digital twin."
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            await vehicleViewModel.createVehicle(
                brand: onboardingDraft.brand,
                model: onboardingDraft.model,
                year: onboardingDraft.year,
                mileage: onboardingDraft.mileage,
                vin: onboardingDraft.vin,
                token: token
            )
            
            isLoading = false
            
            if vehicleViewModel.errorMessage == nil {
                onboardingStep = .completed
                isVehicleOnboardingActive = false
                shouldShowCreatedVehicleCard = true
                let personality = VehiclePersonality.inferred(
                    brand: onboardingDraft.brand,
                    model: onboardingDraft.model
                )
                
                let connectedMessage = ChatUIMessage(
                    role: .assistant,
                    text: "I am connected now. Your \(onboardingDraft.brand) \(onboardingDraft.model) digital twin is ready.\n\nPersonality detected: **\(personality.title)**. \(personality.subtitle)\n\n\(personality.aiLine)\n\nWould you like to upload my photo? Tap the attachment button below so I can recognize myself visually in your vehicle profile.",
                    prediction: nil,
                    attachment: nil
                )
                
                messages = [
                    connectedMessage
                ]
                
                createdVehicleCardAnchorId = connectedMessage.id
                
                if let vehicleId = vehicleViewModel.activeVehicleId {
                    cachedMessagesByVehicleId[vehicleId] = messages
                    saveLocalCache()
                    loadedVehicleId = vehicleId
                }
            } else {
                errorMessage = vehicleViewModel.errorMessage
            }
            
        case .completed:
            return
        }
    }
    
    func addAssistantMessage(_ text: String) {
        let message = ChatUIMessage(
            role: .assistant,
            text: text,
            prediction: nil,
            attachment: nil
        )
        
        messages.append(message)
        persistCurrentMessages()
    }
    
    func addVehiclePhotoMessage(vehicleId: Int) {
        let message = ChatUIMessage(
            role: .assistant,
            text: "Vehicle photo linked to this digital twin.",
            prediction: nil,
            attachment: .vehiclePhoto(vehicleId: vehicleId)
        )
        
        messages.append(message)
        loadedVehicleId = vehicleId
        persistCurrentMessages()
    }
    
    func attachPhotoToDraft(_ data: Data) {
        pendingPhotoData = data.normalizedChatPhotoData
    }
    
    func removeDraftPhoto() {
        pendingPhotoData = nil
    }
    
    private func persistCurrentMessages() {
        guard let loadedVehicleId else {
            return
        }
        
        cachedMessagesByVehicleId[loadedVehicleId] = messages
        saveLocalCache()
    }
    
    private func mergedHistory(
        backendMessages: [ChatUIMessage],
        localMessages: [ChatUIMessage]
    ) -> [ChatUIMessage] {
        var mergedMessages = backendMessages
        var previousLocalMessageHadChatPhoto = false
        
        for localMessage in localMessages {
            let shouldKeepLocalMessage =
            localMessage.attachment != nil ||
            (previousLocalMessageHadChatPhoto && localMessage.role == .assistant)
            
            guard shouldKeepLocalMessage else {
                previousLocalMessageHadChatPhoto = localMessage.attachment?.chatPhotoData != nil
                continue
            }
            
            if let existingIndex = mergedMessages.firstIndex(where: { backendMessage in
                backendMessage.role == localMessage.role &&
                backendMessage.text == localMessage.text
            }) {
                if localMessage.attachment != nil {
                    mergedMessages[existingIndex] = localMessage
                }
            } else {
                mergedMessages.append(localMessage)
            }
            
            previousLocalMessageHadChatPhoto = localMessage.attachment?.chatPhotoData != nil
        }
        
        return mergedMessages
    }
    
    private func friendlyMessage(for error: Error) -> String {
        let rawMessage = error.localizedDescription.lowercased()
        
        if rawMessage.contains("401") || rawMessage.contains("unauthorized") {
            return "My session link expired. Please sign in again so I can reconnect to your vehicle."
        }
        
        if rawMessage.contains("500") || rawMessage.contains("server") {
            return "My AI service is temporarily unavailable. Please try again later."
        }
        
        if rawMessage.contains("network") ||
            rawMessage.contains("internet") ||
            rawMessage.contains("offline") ||
            rawMessage.contains("connection") {
            return "I cannot reach the network right now. Please check your connection and try again."
        }
        
        if rawMessage.contains("404") || rawMessage.contains("not found") {
            return "My backend chat endpoint is not available yet. I can still stay linked to this vehicle, but real AI responses will work after the backend is connected."
        }
        
        return "Something went wrong while I was processing your request. Please try again."
    }
    
    func resetToNoVehicleState(previousVehicleId: Int?) {
        if let previousVehicleId {
            cachedMessagesByVehicleId.removeValue(forKey: previousVehicleId)
            saveLocalCache()
        }
        
        loadedVehicleId = nil
        shouldShowCreatedVehicleCard = false
        isVehicleOnboardingActive = true
        onboardingStep = .brand
        onboardingDraft = VehicleOnboardingDraft()
        errorMessage = nil
        isLoading = false
        
        messages = [
            ChatUIMessage(
                role: .assistant,
                text: "I do not exist yet — but we can create me together. Let’s start with my identity. What is my brand?",
                prediction: nil,
                attachment: nil
            )
        ]
    }
}

struct ChatUIMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    let text: String
    let prediction: ChatPrediction?
    let attachment: ChatMessageAttachment?
    
    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        prediction: ChatPrediction?,
        attachment: ChatMessageAttachment? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.prediction = prediction
        self.attachment = attachment
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case text
        case prediction
        case attachment
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(ChatRole.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        prediction = try container.decodeIfPresent(ChatPrediction.self, forKey: .prediction)
        attachment = try container.decodeIfPresent(ChatMessageAttachment.self, forKey: .attachment)
    }
}

enum ChatMessageAttachment: Codable, Equatable {
    case vehiclePhoto(vehicleId: Int)
    case chatPhoto(data: Data)
    
    var vehiclePhotoId: Int? {
        if case .vehiclePhoto(let vehicleId) = self {
            return vehicleId
        }
        
        return nil
    }
    
    var chatPhotoData: Data? {
        if case .chatPhoto(let data) = self {
            return data
        }
        
        return nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case vehicleId
        case data
        case vehiclePhoto
        case chatPhoto
        case unlabeled = "_0"
    }
    
    private enum AttachmentType: String, Codable {
        case vehiclePhoto
        case chatPhoto
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let type = try? container.decode(AttachmentType.self, forKey: .type) {
            switch type {
            case .vehiclePhoto:
                self = .vehiclePhoto(vehicleId: try container.decode(Int.self, forKey: .vehicleId))
            case .chatPhoto:
                self = .chatPhoto(data: try container.decode(Data.self, forKey: .data))
            }
            return
        }
        
        if let legacyVehicle = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .vehiclePhoto) {
            if let vehicleId = try? legacyVehicle.decode(Int.self, forKey: .vehicleId) {
                self = .vehiclePhoto(vehicleId: vehicleId)
                return
            }
            
            if let vehicleId = try? legacyVehicle.decode(Int.self, forKey: .unlabeled) {
                self = .vehiclePhoto(vehicleId: vehicleId)
                return
            }
        }
        
        if let legacyPhoto = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .chatPhoto),
           let data = (try? legacyPhoto.decode(Data.self, forKey: .data)) ??
           (try? legacyPhoto.decode(Data.self, forKey: .unlabeled)) {
            self = .chatPhoto(data: data)
            return
        }
        
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unknown chat attachment format.")
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .vehiclePhoto(let vehicleId):
            try container.encode(AttachmentType.vehiclePhoto, forKey: .type)
            try container.encode(vehicleId, forKey: .vehicleId)
        case .chatPhoto(let data):
            try container.encode(AttachmentType.chatPhoto, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

enum VehicleOnboardingStep {
    case brand
    case model
    case year
    case mileage
    case vin
    case completed
}

struct VehicleOnboardingDraft {
    var brand: String = ""
    var model: String = ""
    var year: String = ""
    var mileage: String = ""
    var vin: String = ""
}

enum ChatRole: String, Codable {
    case user
    case assistant
}

private extension Data {
    var normalizedChatPhotoData: Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: self) else {
            return self
        }
        
        let maxSide: CGFloat = 1400
        let size = image.size
        let scale = Swift.min(1, maxSide / Swift.max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        return resized.jpegData(compressionQuality: 0.8) ?? self
        #else
        return self
        #endif
    }
}
