//
//  ChatViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 28.06.2026.
//

import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    
    @Published var messages: [ChatUIMessage] = []
    @Published var inputText: String = ""
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
    
    init(repository: ChatRepository = ChatRepository()) {
        self.repository = repository
    }
    
    func loadHistory(
        vehicle: VehicleResponse?,
        token: String?
    ) async {
        loadLocalCacheIfNeeded()

        guard let vehicle else {
            if messages.isEmpty {
                showEmptyVehicleGreeting()
            }
            return
        }
        
        if loadedVehicleId == vehicle.id && !messages.isEmpty {
            return
        }

        if let cachedMessages = cachedMessagesByVehicleId[vehicle.id] {
            messages = cachedMessages
            loadedVehicleId = vehicle.id
            return
        }

        loadedVehicleId = vehicle.id
        
        guard let token else {
            errorMessage = "Please sign in again to continue chatting."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let history = try await repository.loadHistory(
                vehicleId: vehicle.id,
                token: token
            )
            
            messages = history.map { message in
                ChatUIMessage(
                    role: ChatRole(rawValue: message.role.lowercased()) ?? .assistant,
                    text: message.displayText,
                    prediction: message.prediction
                )
            }
            
            cachedMessagesByVehicleId[vehicle.id] = messages
            
            saveLocalCache()
            
            if messages.isEmpty {
                showVehicleGreeting(vehicle: vehicle)
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
        
        guard !trimmedText.isEmpty else {
            return
        }
        
        if vehicleViewModel.activeVehicle == nil || isVehicleOnboardingActive {
            inputText = ""
            
            await handleVehicleOnboardingAnswer(
                trimmedText,
                vehicleViewModel: vehicleViewModel,
                token: token
            )
            
            return
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
            text: trimmedText,
            prediction: nil
        )
        
        messages.append(userMessage)
        cachedMessagesByVehicleId[vehicle.id] = messages
        saveLocalCache()
        
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await repository.sendMessage(
                vehicleId: vehicle.id,
                message: trimmedText,
                token: token
            )
            
            let assistantMessage = ChatUIMessage(
                role: .assistant,
                text: response.assistantText,
                prediction: response.prediction
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
        messages = [
            ChatUIMessage(
                role: .assistant,
                text: "I am your \(vehicle.brand) \(vehicle.model) digital twin. Ask me about my condition, maintenance risks, repair history, or what I may need next.",
                prediction: nil
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
                prediction: nil
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
                prediction: nil
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
                    prediction: nil
                )
            )
            
        case .model:
            onboardingDraft.model = answer
            onboardingStep = .year
            
            messages.append(
                ChatUIMessage(
                    role: .assistant,
                    text: "What year was I produced?",
                    prediction: nil
                )
            )
            
        case .year:
            let cleanYear = answer.filter { $0.isNumber }
            
            guard !cleanYear.isEmpty else {
                messages.append(
                    ChatUIMessage(
                        role: .assistant,
                        text: "Please send my production year as digits, for example 2022.",
                        prediction: nil
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
                    prediction: nil
                )
            )
            
        case .mileage:
            let cleanMileage = answer.filter { $0.isNumber }
            
            guard !cleanMileage.isEmpty else {
                messages.append(
                    ChatUIMessage(
                        role: .assistant,
                        text: "Please send my mileage as a number in kilometers, for example 42000.",
                        prediction: nil
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
                    prediction: nil
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
                        prediction: nil
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
                
                let connectedMessage = ChatUIMessage(
                    role: .assistant,
                    text: "I am connected now. Your \(onboardingDraft.brand) \(onboardingDraft.model) digital twin is ready. Would you like to upload my photo? Tap the attachment button below so I can recognize myself visually in your vehicle profile.",
                    prediction: nil
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
            prediction: nil
        )
        
        messages.append(message)
        
        if let loadedVehicleId {
            cachedMessagesByVehicleId[loadedVehicleId] = messages
            saveLocalCache()
        }
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
                prediction: nil
            )
        ]
    }
}

struct ChatUIMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    let text: String
    let prediction: ChatPrediction?
    
    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        prediction: ChatPrediction?
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.prediction = prediction
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
