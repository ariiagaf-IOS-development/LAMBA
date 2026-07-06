//
//  TimelineView.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI
import Combine
import PhotosUI

struct TimelineView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    @StateObject private var timelineRepository = TimelineRepository()
    @StateObject private var tripTracker = TripTrackingRepository()
    @StateObject private var eventPhotoStore = EventPhotoStore()
    @State private var selectedFilter: TimelineFilter = .all
    @State private var isAddingEvent = false
    @State private var isStartingTrip = false
    @State private var isEndingTrip = false
    @State private var selectedEvent: VehicleEvent?
    @State private var tripClock = Date()
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            Group {
                if vehicleViewModel.activeVehicle == nil {
                    noVehicleView
                } else if timelineRepository.isLoading && timelineRepository.events.isEmpty {
                    ProgressView()
                        .tint(AppColors.primary)
                } else {
                    content
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeaderView(
                config: .init(
                    title: "ARCHIVE LOG",
                    leftIcon: "clock.fill",
                    rightIcon: "plus",
                    showsBackButton: false
                ),
                actions: .init(
                    onRightTap: {
                        isAddingEvent = true
                    }
                )
            )
        }
        .task(id: vehicleViewModel.activeVehicleId) {
            await loadTimeline()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            tripClock = date
        }
        .fullScreenCover(isPresented: $isAddingEvent) {
            AddEventView(
                repository: timelineRepository,
                photoStore: eventPhotoStore,
                onClose: {
                    isAddingEvent = false
                }
            )
            .environmentObject(authViewModel)
            .environmentObject(vehicleViewModel)
        }
        .sheet(isPresented: $isStartingTrip) {
            StartTripView(
                vehicle: vehicleViewModel.activeVehicle,
                isSaving: tripTracker.isSaving,
                errorMessage: tripTracker.errorMessage,
                onClose: {
                    isStartingTrip = false
                },
                onSubmit: { startMileage in
                    Task {
                        await startTrip(startMileageKm: startMileage)
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isEndingTrip) {
            EndTripView(
                activeTrip: tripTracker.activeTrip(for: vehicleViewModel.activeVehicleId),
                currentMileage: vehicleViewModel.activeVehicle?.mileageKm ?? 0,
                isSaving: tripTracker.isSaving,
                errorMessage: tripTracker.errorMessage,
                onClose: {
                    isEndingTrip = false
                },
                onSubmit: { draft in
                    Task {
                        await endTrip(
                            endMileageKm: draft.endMileageKm,
                            cost: draft.cost,
                            note: draft.note
                        )
                    }
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $selectedEvent) { event in
            TimelineEventDetailView(
                event: event,
                photos: eventPhotoStore.photos(for: event.id)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                ScreenHeroView(
                    title: "LIFECYCLE",
                    accentTitle: "STREAM",
                    subtitle: "Trips, refueling, repairs and maintenance events in one place.",
                    topPadding: 12
                )
                
                VStack(spacing: AppSpacing.lg) {
                    if let errorMessage = timelineRepository.errorMessage {
                        TimelineErrorCard(message: errorMessage) {
                            Task { await loadTimeline() }
                        }
                    }
                    
                    if let errorMessage = tripTracker.errorMessage {
                        TimelineErrorCard(message: errorMessage) {
                            Task { await loadTimeline() }
                        }
                    }
                    
                    TimelineStatsGrid(
                        stats: timelineRepository.stats,
                        events: timelineRepository.events
                    )
                    
                    TripTrackingCard(
                        vehicle: vehicleViewModel.activeVehicle,
                        activeTrip: tripTracker.activeTrip(for: vehicleViewModel.activeVehicleId),
                        currentDate: tripClock,
                        isSaving: tripTracker.isSaving,
                        onStart: {
                            isStartingTrip = true
                        },
                        onEnd: {
                            isEndingTrip = true
                        }
                    )
                    
                    if !tripHistoryEvents.isEmpty {
                        TripHistoryStrip(events: tripHistoryEvents)
                    }
                    
                    if let latestEvent = timelineRepository.events.first {
                        Button {
                            selectedEvent = latestEvent
                        } label: {
                            LatestTimelineEventCard(event: latestEvent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    TimelineFilterBar(selectedFilter: $selectedFilter)
                    
                    if filteredEvents.isEmpty {
                        TimelineEmptyState {
                            isAddingEvent = true
                        }
                    } else {
                        TimelineMonthList(
                            groupedEvents: groupedEvents,
                            deletingEventIds: timelineRepository.deletingEventIds,
                            photoProvider: { eventPhotoStore.photos(for: $0.id) },
                            onSelect: { event in
                                selectedEvent = event
                            },
                            onDelete: { event in
                                Task {
                                    await deleteEvent(event)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable {
            await loadTimeline()
        }
    }
    
    private var filteredEvents: [VehicleEvent] {
        timelineRepository.events.filter { event in
            switch selectedFilter {
            case .all:
                return true
            case .trip:
                return event.type == .trip
            case .refuel:
                return event.type == .refuel
            case .repair:
                return event.type == .repair
            case .maintenance:
                return event.type == .maintenance
            case .other:
                return ![.trip, .refuel, .repair, .maintenance].contains(event.type)
            }
        }
    }
    
    private var groupedEvents: [TimelineMonthGroup] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
            event.monthKey
        }
        
        return grouped
            .map { key, events in
                TimelineMonthGroup(
                    title: key,
                    events: events.sorted { $0.eventSortDate > $1.eventSortDate }
                )
            }
            .sorted { lhs, rhs in
                (lhs.events.first?.eventSortDate ?? .distantPast) > (rhs.events.first?.eventSortDate ?? .distantPast)
            }
    }
    
    private var tripHistoryEvents: [VehicleEvent] {
        timelineRepository.events
            .filter { $0.type == .trip }
            .prefix(4)
            .map { $0 }
    }
    
    private var noVehicleView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "car.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AppColors.primary)
            
            Text("No vehicle selected")
                .font(AppTypography.h2)
                .foregroundStyle(AppColors.textPrimary)
            
            Text("Add or select a vehicle to view lifecycle events.")
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.xl)
    }
    
    private func loadTimeline() async {
        guard let vehicleId = vehicleViewModel.activeVehicleId,
              let token = authViewModel.token else {
            timelineRepository.clear()
            return
        }
        
        await timelineRepository.loadTimeline(vehicleId: vehicleId, token: token)
    }
    
    private func deleteEvent(_ event: VehicleEvent) async {
        guard let vehicleId = vehicleViewModel.activeVehicleId,
              let token = authViewModel.token else {
            return
        }
        
        let didDelete = await timelineRepository.deleteEvent(
            vehicleId: vehicleId,
            eventId: event.id,
            token: token
        )
        
        if didDelete {
            eventPhotoStore.removePhotos(for: event.id)
        }
    }
    
    private func startTrip(startMileageKm: Int) async {
        guard let vehicle = vehicleViewModel.activeVehicle,
              let token = authViewModel.token else {
            return
        }
        
        let didStart = await tripTracker.startTrip(
            vehicle: vehicle,
            startMileageKm: max(0, startMileageKm),
            token: token
        )
        
        if didStart {
            isStartingTrip = false
        }
    }
    
    private func endTrip(
        endMileageKm: Int,
        cost: Double?,
        note: String?
    ) async {
        guard let vehicle = vehicleViewModel.activeVehicle,
              let activeTrip = tripTracker.activeTrip(for: vehicle.id),
              let token = authViewModel.token else {
            return
        }
        
        let closedAt = Date()
        let sanitizedEndMileage = max(endMileageKm, activeTrip.startMileageKm)
        let distance = sanitizedEndMileage - activeTrip.startMileageKm
        let duration = TripTrackingFormatter.duration(from: activeTrip.startedAt, to: closedAt)
        var descriptionParts = [
            "Started \(TripTrackingFormatter.shortDateTime(activeTrip.startedAt))",
            "Ended \(TripTrackingFormatter.shortDateTime(closedAt))",
            "Duration \(duration)",
            "Distance \(distance.formatted()) km"
        ]
        
        if let note {
            descriptionParts.append(note)
        }
        
        let event = VehicleEventRequest(
            type: .trip,
            title: distance > 0 ? "Trip: \(distance.formatted()) km" : "Trip completed",
            description: descriptionParts.joined(separator: " - "),
            eventDate: closedAt.iso8601String,
            mileageKm: sanitizedEndMileage,
            cost: cost,
            fuelLiters: nil,
            metadata: nil
        )
        
        let didClose = await tripTracker.endTrip(
            vehicleId: vehicle.id,
            tripId: activeTrip.tripId,
            closedAt: closedAt,
            event: event,
            token: token,
            timelineRepository: timelineRepository,
            vehicleViewModel: vehicleViewModel,
            vehicle: vehicle,
            endMileageKm: sanitizedEndMileage
        )
        
        if didClose {
            isEndingTrip = false
            await loadTimeline()
        }
    }
}

@MainActor
private final class TripTrackingRepository: ObservableObject {
    @Published private var activeTrips: [Int: ActiveTrip] = [:]
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    
    private let cacheKey = "local_active_trips_by_vehicle_id"
    
    init() {
        loadActiveTrips()
    }
    
    func activeTrip(for vehicleId: Int?) -> ActiveTrip? {
        guard let vehicleId else { return nil }
        return activeTrips[vehicleId]
    }
    
    func startTrip(
        vehicle: VehicleResponse,
        startMileageKm: Int,
        token: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        
        let startedAt = Date()
        
        do {
            let trip = try await TimelineAPIService.shared.startTrip(
                vehicleId: vehicle.id,
                request: StartTripRequest(
                    startAt: startedAt.iso8601String,
                    startMileageKm: startMileageKm
                ),
                token: token
            )
            
            activeTrips[vehicle.id] = ActiveTrip(
                tripId: trip.id,
                vehicleId: vehicle.id,
                startMileageKm: trip.startMileageKm,
                startedAt: trip.startAt.iso8601Date ?? startedAt
            )
            saveActiveTrips()
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
    
    func endTrip(
        vehicleId: Int,
        tripId: Int?,
        closedAt: Date,
        event: VehicleEventRequest,
        token: String,
        timelineRepository: TimelineRepository,
        vehicleViewModel: VehicleViewModel,
        vehicle: VehicleResponse,
        endMileageKm: Int
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        
        if let tripId {
            do {
                _ = try await TimelineAPIService.shared.endTrip(
                    vehicleId: vehicleId,
                    tripId: tripId,
                    request: EndTripRequest(
                        endAt: closedAt.iso8601String,
                        endMileageKm: endMileageKm
                    ),
                    token: token
                )
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
                return false
            }
        }
        
        let didCreateEvent = await timelineRepository.createEvent(
            vehicleId: vehicleId,
            token: token,
            event: event
        )
        
        guard didCreateEvent else {
            errorMessage = timelineRepository.errorMessage
            isSaving = false
            return false
        }
        
        let didUpdateMileage: Bool
        
        if tripId == nil {
            didUpdateMileage = await vehicleViewModel.updateMileage(
                for: vehicle,
                to: endMileageKm,
                token: token
            )
        } else {
            await vehicleViewModel.refreshVehicles(token: token)
            didUpdateMileage = true
        }
        
        guard didUpdateMileage else {
            errorMessage = vehicleViewModel.errorMessage
            isSaving = false
            return false
        }
        
        activeTrips.removeValue(forKey: vehicleId)
        saveActiveTrips()
        isSaving = false
        return true
    }
    
    private func saveActiveTrips() {
        do {
            let encoded = try JSONEncoder().encode(activeTrips)
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadActiveTrips() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        
        do {
            activeTrips = try JSONDecoder().decode([Int: ActiveTrip].self, from: data)
        } catch {
            activeTrips = [:]
        }
    }
}

private struct TripTrackingCard: View {
    let vehicle: VehicleResponse?
    let activeTrip: ActiveTrip?
    let currentDate: Date
    let isSaving: Bool
    let onStart: () -> Void
    let onEnd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                Image(systemName: activeTrip == nil ? "play.fill" : "location.fill.viewfinder")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(activeTrip == nil ? AppColors.primary : AppColors.green)
                    .frame(width: 48, height: 48)
                    .background((activeTrip == nil ? AppColors.primary : AppColors.green).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(activeTrip == nil ? "TRIP TRACKER" : "ACTIVE TRIP")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.3)
                    
                    Text(title)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                
                Spacer()
                
                Text(activeTrip == nil ? "READY" : "LIVE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(activeTrip == nil ? AppColors.primary : AppColors.green)
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background((activeTrip == nil ? AppColors.primary : AppColors.green).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: AppSpacing.md) {
                TripTrackingMetric(title: activeTrip == nil ? "CURRENT KM" : "START KM", value: mileageText)
                TripTrackingMetric(title: "STARTED", value: startText)
                TripTrackingMetric(title: "DURATION", value: durationText)
            }
            
            Button {
                activeTrip == nil ? onStart() : onEnd()
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: activeTrip == nil ? "play.fill" : "stop.fill")
                    }
                    
                    Text(activeTrip == nil ? "START TRIP" : "END TRIP")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1.2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(activeTrip == nil ? AppColors.primary : AppColors.red)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vehicle == nil || isSaving)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke((activeTrip == nil ? AppColors.bubbleBorder : AppColors.green.opacity(0.24)), lineWidth: 1)
        )
    }
    
    private var title: String {
        if activeTrip != nil {
            return "Trip in progress"
        }
        
        return "Start a mileage-based trip"
    }
    
    private var startText: String {
        guard let activeTrip else { return "NOW" }
        return TripTrackingFormatter.shortDateTime(activeTrip.startedAt)
    }
    
    private var mileageText: String {
        guard let activeTrip else {
            return vehicle.map { "\($0.mileageKm.formatted()) km" } ?? "--"
        }
        
        return "\(activeTrip.startMileageKm.formatted()) km"
    }
    
    private var durationText: String {
        guard let activeTrip else { return "--" }
        return TripTrackingFormatter.duration(from: activeTrip.startedAt, to: currentDate)
    }
}

private struct TripTrackingMetric: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(AppColors.textMuted)
                .tracking(1)
            
            Text(value)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct TripHistoryStrip: View {
    let events: [VehicleEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("TRIP HISTORY")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AppColors.textMuted)
                .tracking(1.4)
            
            VStack(spacing: AppSpacing.sm) {
                ForEach(events) { event in
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: VehicleEventType.trip.iconName)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                            
                            Text(event.eventDate.timelineDayText.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.textSecondary)
                                .tracking(0.8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        
                        Spacer()
                        
                        if let cost = event.cost, cost > 0 {
                            Text(cost.formatted(.currency(code: "RUB").precision(.fractionLength(0))))
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(AppColors.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
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
        }
    }
}

private struct StartTripView: View {
    let vehicle: VehicleResponse?
    let isSaving: Bool
    let errorMessage: String?
    let onClose: () -> Void
    let onSubmit: (Int) -> Void
    
    @State private var startMileage = ""
    
    private var currentMileage: Int {
        vehicle?.mileageKm ?? 0
    }
    
    private var parsedMileage: Int {
        Int(startMileage.filter { $0.isNumber }) ?? currentMileage
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                TripSheetHeader(
                    label: "START TRIP",
                    title: "Fix start point",
                    onClose: onClose
                )
                
                HStack(spacing: AppSpacing.md) {
                    TripTrackingMetric(title: "VEHICLE", value: vehicleName)
                    TripTrackingMetric(title: "START TIME", value: "NOW")
                }
                
                EventTextFieldSection(
                    title: "CURRENT ODOMETER (KM)",
                    placeholder: "\(currentMileage.formatted())",
                    text: $startMileage,
                    keyboardType: .numberPad
                )
                
                TripSheetInfoRow(
                    icon: "speedometer",
                    text: "Enter the car's total odometer reading. This becomes the start point for trip distance."
                )
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                PrimaryActionButton(
                    title: isSaving ? "STARTING TRIP..." : "START TRIP",
                    colors: [AppColors.gradientStart, AppColors.gradientEnd]
                ) {
                    onSubmit(parsedMileage)
                }
                .disabled(vehicle == nil || isSaving)
            }
            .padding(AppSpacing.xl)
        }
        .onAppear {
            if startMileage.isEmpty {
                startMileage = "\(currentMileage)"
            }
        }
    }
    
    private var vehicleName: String {
        guard let vehicle else { return "--" }
        return "\(vehicle.brand) \(vehicle.model)"
    }
}

private struct EndTripView: View {
    let activeTrip: ActiveTrip?
    let currentMileage: Int
    let isSaving: Bool
    let errorMessage: String?
    let onClose: () -> Void
    let onSubmit: (TripEndDraft) -> Void
    
    @State private var endMileage = ""
    @State private var cost = ""
    @State private var note = ""
    
    private var startMileage: Int {
        activeTrip?.startMileageKm ?? currentMileage
    }
    
    private var parsedMileage: Int {
        Int(endMileage.filter { $0.isNumber }) ?? currentMileage
    }
    
    private var distance: Int {
        max(0, parsedMileage - startMileage)
    }
    
    private var isMileageValid: Bool {
        parsedMileage >= startMileage
    }
    
    private var parsedCost: Double? {
        let normalized = cost
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        
        return Double(normalized)
    }
    
    private var cleanNote: String? {
        note.trimmingCharacters(in: .whitespacesAndNewlines).emptyToNil
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        TripSheetHeader(
                            label: "END TRIP",
                            title: "Close active route",
                            onClose: onClose
                        )
                        
                        TripDistancePreviewCard(
                            startMileage: startMileage,
                            currentMileage: parsedMileage,
                            distance: distance,
                            isValid: isMileageValid
                        )
                        
                        if let activeTrip {
                            TripTimingSummaryCard(
                                startedAt: activeTrip.startedAt,
                                duration: TripTrackingFormatter.duration(from: activeTrip.startedAt)
                            )
                        }
                        
                        EventTextFieldSection(
                            title: "CURRENT ODOMETER (KM)",
                            placeholder: "\(max(currentMileage, startMileage).formatted())",
                            text: $endMileage,
                            keyboardType: .numberPad
                        )
                        
                        EventTextFieldSection(
                            title: "TRIP COST (RUB)",
                            placeholder: "0.00",
                            text: $cost,
                            keyboardType: .decimalPad
                        )
                        
                        EventTextFieldSection(
                            title: "NOTE",
                            placeholder: "Add route details, parking, tolls...",
                            text: $note,
                            axis: .vertical
                        )
                        
                        TripSheetInfoRow(
                            icon: "minus.forwardslash.plus",
                            text: "Enter the car's total odometer now. The app calculates trip distance from it."
                        )
                        
                        if !isMileageValid {
                            TripSheetInfoRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "Current odometer cannot be lower than start km.",
                                tint: AppColors.red
                            )
                        }
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.orange)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                }
                
                PrimaryActionButton(
                    title: isSaving ? "SAVING TRIP..." : "SAVE TRIP",
                    colors: isMileageValid
                    ? [AppColors.gradientStart, AppColors.gradientEnd]
                    : [AppColors.textSecondary.opacity(0.5), AppColors.textSecondary.opacity(0.5)]
                ) {
                    onSubmit(
                        TripEndDraft(
                            endMileageKm: parsedMileage,
                            cost: parsedCost,
                            note: cleanNote
                        )
                    )
                }
                .disabled(isSaving || activeTrip == nil || !isMileageValid)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
                .background(
                    AppColors.background
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: -8)
                )
            }
        }
        .onAppear {
            if endMileage.isEmpty {
                endMileage = "\(max(currentMileage, startMileage))"
            }
        }
    }
}

private struct TripEndDraft {
    let endMileageKm: Int
    let cost: Double?
    let note: String?
}

private struct TripDistancePreviewCard: View {
    let startMileage: Int
    let currentMileage: Int
    let distance: Int
    let isValid: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(isValid ? AppColors.primary : AppColors.red)
                    .frame(width: 48, height: 48)
                    .background((isValid ? AppColors.primary : AppColors.red).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("CALCULATED DISTANCE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.2)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(distance.formatted())")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(isValid ? AppColors.textPrimary : AppColors.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        
                        Text("km")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: AppSpacing.md) {
                TripTrackingMetric(title: "START KM", value: "\(startMileage.formatted())")
                TripTrackingMetric(title: "NOW KM", value: "\(currentMileage.formatted())")
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke((isValid ? AppColors.primary : AppColors.red).opacity(0.16), lineWidth: 1)
        )
    }
}

private struct TripTimingSummaryCard: View {
    let startedAt: Date
    let duration: String
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            TripTrackingMetric(
                title: "STARTED AT",
                value: TripTrackingFormatter.shortDateTime(startedAt)
            )
            
            TripTrackingMetric(
                title: "DURATION",
                value: duration
            )
        }
    }
}

private struct TripSheetHeader: View {
    let label: String
    let title: String
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppColors.textMuted)
                    .tracking(1.4)
                
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TripSheetInfoRow: View {
    let icon: String
    let text: String
    var tint: Color = AppColors.primary
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.1))
                .clipShape(Circle())
            
            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct TimelineMonthGroup: Identifiable {
    let title: String
    let events: [VehicleEvent]
    
    var id: String { title }
}

@MainActor
private final class EventPhotoStore: ObservableObject {
    @Published private(set) var photosByEventId: [Int: [Data]] = [:]
    
    private let cacheKey = "local_event_photos_by_event_id"
    private let maxPhotosPerEvent = 6
    
    init() {
        load()
    }
    
    func photos(for eventId: Int) -> [Data] {
        photosByEventId[eventId] ?? []
    }
    
    func setPhotos(_ photos: [Data], for eventId: Int) {
        let trimmed = Array(photos.prefix(maxPhotosPerEvent))
        
        if trimmed.isEmpty {
            photosByEventId.removeValue(forKey: eventId)
        } else {
            photosByEventId[eventId] = trimmed
        }
        
        save()
    }
    
    func removePhotos(for eventId: Int) {
        photosByEventId.removeValue(forKey: eventId)
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(photosByEventId)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("Failed to save event photos:", error.localizedDescription)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        
        do {
            photosByEventId = try JSONDecoder().decode([Int: [Data]].self, from: data)
        } catch {
            photosByEventId = [:]
        }
    }
}

private struct TimelineStatsGrid: View {
    let stats: VehicleEventStats?
    let events: [VehicleEvent]
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            TimelineHeroStatCard(
                title: "TOTAL EVENTS",
                value: totalEvents,
                unit: "logs",
                icon: "list.bullet.rectangle"
            )
            
            TimelineHeroStatCard(
                title: "TOTAL COST",
                value: totalCost,
                unit: "rub",
                icon: "creditcard.fill"
            )
        }
    }
    
    private var totalEvents: String {
        "\(stats?.totalEvents ?? events.count)"
    }
    
    private var totalCost: String {
        let cost = stats?.totalCost ?? events.compactMap(\.cost).reduce(0, +)
        return cost.formatted(.number.precision(.fractionLength(0)))
    }
}

private struct TimelineHeroStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppColors.primary)
                .frame(width: 48, height: 48)
                .background(Color(hex: "EEF5FE"))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppColors.textMuted)
                    .tracking(1.1)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    
                    Text(unit)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 186, alignment: .leading)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.xl)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 48))
        .overlay(
            RoundedRectangle(cornerRadius: 48)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct LatestTimelineEventCard: View {
    let event: VehicleEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: event.type.iconName)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(event.type.tintColor)
                    .frame(width: 48, height: 48)
                    .background(event.type.tintColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.eventDate.timelineDayText.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.1)
                        .lineLimit(1)
                    
                    Text(event.type.title.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(event.type.tintColor)
                        .tracking(1.2)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let cost = event.cost, cost > 0 {
                    Text(cost.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .frame(maxWidth: 96, alignment: .trailing)
                }
            }
            
            Text(event.title)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: AppSpacing.md) {
                LatestEventMeta(title: "MILEAGE", value: mileageText)
                LatestEventMeta(title: "COST", value: costText)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(event.type.tintColor.opacity(0.18), lineWidth: 1)
        )
    }
    
    private var mileageText: String {
        guard let mileage = event.mileageKm else { return "--" }
        return "\(mileage.formatted()) km"
    }
    
    private var costText: String {
        guard let cost = event.cost, cost > 0 else { return "--" }
        return "\(cost.formatted(.number.precision(.fractionLength(0)))) rub"
    }
}

private struct LatestEventMeta: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(AppColors.textMuted)
                .tracking(1.1)
            
            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct TimelineFilterBar: View {
    @Binding var selectedFilter: TimelineFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(TimelineFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(selectedFilter == filter ? .white : AppColors.textSecondary)
                            .tracking(1.1)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(selectedFilter == filter ? AppColors.primary : AppColors.card)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.bubbleBorder, lineWidth: selectedFilter == filter ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct TimelineMonthList: View {
    let groupedEvents: [TimelineMonthGroup]
    let deletingEventIds: Set<Int>
    let photoProvider: (VehicleEvent) -> [Data]
    let onSelect: (VehicleEvent) -> Void
    let onDelete: (VehicleEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ForEach(groupedEvents) { group in
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(group.title)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.4)
                    
                    VStack(spacing: AppSpacing.md) {
                        ForEach(group.events) { event in
                            SwipeDeleteEventRow(
                                event: event,
                                photos: photoProvider(event),
                                isDeleting: deletingEventIds.contains(event.id),
                                onSelect: {
                                    onSelect(event)
                                },
                                onDelete: {
                                    onDelete(event)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SwipeDeleteEventRow: View {
    
    let event: VehicleEvent
    let photos: [Data]
    let isDeleting: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showsDeleteConfirmation = false
    
    private let revealWidth: CGFloat = 86
    
    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                showsDeleteConfirmation = true
            } label: {
                VStack(spacing: 6) {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .black))
                    }
                    
                    Text(isDeleting ? "..." : "DELETE")
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.8)
                }
                .foregroundStyle(.white)
                .frame(width: revealWidth)
                .frame(maxHeight: .infinity)
                .background(AppColors.red)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            
            TimelineEventCard(event: event, photos: photos)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            let translation = value.translation.width
                            offset = min(0, max(-revealWidth, translation))
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                offset = value.translation.width < -44 ? -revealWidth : 0
                            }
                        }
                )
                .onTapGesture {
                    if offset != 0 {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            offset = 0
                        }
                    } else {
                        onSelect()
                    }
                }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: offset)
        .confirmationDialog(
            "Delete this event?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Event", role: .destructive) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    offset = 0
                }
                
                onDelete()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the event from the vehicle timeline.")
        }
    }
}

private struct TimelineEventCard: View {
    let event: VehicleEvent
    let photos: [Data]
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: event.type.iconName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(event.type.tintColor)
                .frame(width: 48, height: 48)
                .background(event.type.tintColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.eventDate.timelineDayText.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.1)
                        
                        Text(event.type.title.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(event.type.tintColor)
                            .tracking(1.2)
                    }
                    
                    Spacer()
                    
                    if let cost = event.cost, cost > 0 {
                        Text(cost.formatted(.currency(code: "RUB").precision(.fractionLength(0))))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                
                Text(event.title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: AppSpacing.md) {
                    if let mileage = event.mileageKm {
                        EventMetaPill(icon: "speedometer", text: "\(mileage.formatted()) km")
                    }
                    
                    if let fuelLiters = event.displayFuelLiters {
                        EventMetaPill(icon: "fuelpump.fill", text: "\(fuelLiters.fuelLitersText) L")
                    }
                    
                    if !photos.isEmpty {
                        EventMetaPill(icon: "photo.fill", text: "\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                    }
                    
                    if let description = event.description, !description.isEmpty {
                        EventMetaPill(icon: "text.alignleft", text: description)
                    }
                }
                
                if !photos.isEmpty {
                    EventPhotoStrip(photos: photos)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct TimelineEventDetailView: View {
    let event: VehicleEvent
    let photos: [Data]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Image(systemName: event.type.iconName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(event.type.tintColor)
                        .frame(width: 54, height: 54)
                        .background(event.type.tintColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.type.title.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(event.type.tintColor)
                            .tracking(1.2)
                        
                        Text(event.title)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(event.eventDate.timelineDayText.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.1)
                    }
                    
                    Spacer(minLength: 0)
                }
                
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2),
                    spacing: AppSpacing.md
                ) {
                    TimelineDetailMetric(title: "MILEAGE", value: mileageText, tint: AppColors.primary)
                    TimelineDetailMetric(title: "COST", value: costText, tint: AppColors.orange)
                    TimelineDetailMetric(title: "FUEL", value: fuelText, tint: AppColors.teal)
                    TimelineDetailMetric(title: "PHOTOS", value: "\(photos.count)", tint: AppColors.green)
                }
                
                if !photos.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("ATTACHMENTS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.3)
                        
                        EventPhotoStrip(photos: photos)
                    }
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("DESCRIPTION")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.3)
                    
                    Text(descriptionText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xxl)
                        .stroke(AppColors.bubbleBorder, lineWidth: 1)
                )
            }
            .padding(AppSpacing.xl)
        }
        .background(AppColors.background)
    }
    
    private var mileageText: String {
        guard let mileage = event.mileageKm else { return "--" }
        return "\(mileage.formatted()) km"
    }
    
    private var costText: String {
        guard let cost = event.cost, cost > 0 else { return "--" }
        return cost.formatted(.currency(code: "RUB").precision(.fractionLength(0)))
    }
    
    private var fuelText: String {
        guard let fuelLiters = event.displayFuelLiters else { return "--" }
        return "\(fuelLiters.fuelLitersText) L"
    }
    
    private var descriptionText: String {
        guard let description = event.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else {
            return "No extra notes for this event."
        }
        
        return description
    }
}

private struct TimelineDetailMetric: View {
    let title: String
    let value: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(AppColors.textMuted)
                .tracking(1)
            
            Text(value)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct EventPhotoStrip: View {
    let photos: [Data]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(photos.prefix(6).enumerated()), id: \.offset) { _, data in
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 74, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(AppColors.bubbleBorder, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
}

private struct EventMetaPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
            
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColors.background)
        .clipShape(Capsule())
    }
}

private struct TimelineEmptyState: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(AppColors.primary)
            
            Text("No events yet")
                .font(AppTypography.h2)
                .foregroundStyle(AppColors.textPrimary)
            
            Text("Add the first trip, refuel, repair or maintenance event.")
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                onAdd()
            } label: {
                Text("ADD FIRST EVENT")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(1.3)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct TimelineErrorCard: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        AppCard(padding: AppSpacing.md, cornerRadius: AppRadius.lg) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AppColors.orange)
                
                Text(message)
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Retry", action: retry)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AppColors.primary)
            }
        }
    }
}

private struct AddEventView: View {
    @ObservedObject var repository: TimelineRepository
    @ObservedObject var photoStore: EventPhotoStore
    let onClose: () -> Void
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    @State private var type: VehicleEventType = .trip
    @State private var title = ""
    @State private var description = ""
    @State private var mileage = ""
    @State private var cost = ""
    @State private var fuelLiters = ""
    @State private var date = Date()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotoData: [Data] = []
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                AppHeaderView(
                    config: .init(
                        title: "NEURAL ENTRY"
                    ),
                    actions: .init(
                        onBackTap: onClose
                    )
                )
                
                ScreenHeroView(
                    title: "SELECT",
                    accentTitle: "PROTOCOL",
                    subtitle: "Initialize a new event log to synchronize with your digital twin.",
                    topPadding: 12
                )
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        EventFieldSection(title: "EVENT TYPE") {
                            Picker("Event Type", selection: $type) {
                                ForEach(VehicleEventType.formTypes) { eventType in
                                    Text(eventType.title).tag(eventType)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.md)
                            .background(AppColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.xl)
                                    .stroke(AppColors.bubbleBorder, lineWidth: 1)
                            )
                        }
                        
                        EventTextFieldSection(
                            title: "EVENT TITLE",
                            placeholder: titlePlaceholder,
                            text: $title
                        )
                        
                        EventTextFieldSection(
                            title: "DESCRIPTION",
                            placeholder: "Describe technical updates...",
                            text: $description,
                            axis: .vertical
                        )
                        
                        if type.supportsPhotoAttachments {
                            EventPhotoPickerSection(
                                selectedItems: $selectedPhotoItems,
                                photos: selectedPhotoData
                            )
                        }
                        
                        if type == .refuel {
                            EventTextFieldSection(
                                title: "FUEL LITERS",
                                placeholder: "45.5",
                                text: $fuelLiters,
                                keyboardType: .decimalPad
                            )
                        }
                        
                        HStack(spacing: AppSpacing.md) {
                            EventTextFieldSection(
                                title: "MILEAGE (KM)",
                                placeholder: vehicleViewModel.mileage.isEmpty ? "0" : vehicleViewModel.mileage,
                                text: $mileage,
                                keyboardType: .numberPad
                            )
                            
                            EventTextFieldSection(
                                title: "COST (RUB)",
                                placeholder: "0.00",
                                text: $cost,
                                keyboardType: .decimalPad
                            )
                        }
                        
                        EventFieldSection(title: "EVENT DATE") {
                            DatePicker("", selection: $date, displayedComponents: [.date])
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.md)
                                .background(AppColors.card)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.xl)
                                        .stroke(AppColors.bubbleBorder, lineWidth: 1)
                                )
                        }
                        
                        if let errorMessage = repository.errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
                
                PrimaryActionButton(
                    title: repository.isCreating ? "SYNCHRONIZING..." : "FINALIZE SYNC",
                    colors: isFormValid
                    ? [AppColors.gradientStart, AppColors.gradientEnd]
                    : [AppColors.textSecondary.opacity(0.5), AppColors.textSecondary.opacity(0.5)]
                ) {
                    Task { await submit() }
                }
                .disabled(!isFormValid || repository.isCreating)
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
                .background(AppColors.background)
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                await loadSelectedPhotos(from: newItems)
            }
        }
        .onChange(of: type) { _, newType in
            if !newType.supportsPhotoAttachments {
                selectedPhotoItems = []
                selectedPhotoData = []
            }
            
            if newType != .refuel {
                fuelLiters = ""
            }
        }
    }
    
    private var titlePlaceholder: String {
        switch type {
        case .trip:
            return "e.g. Commute to Studio"
        case .refuel:
            return "e.g. Supercharger V3"
        case .repair:
            return "e.g. Oil Filter Replacement"
        case .maintenance:
            return "e.g. Brake Inspection"
        default:
            return "e.g. Lifecycle Update"
        }
    }
    
    private var parsedCost: Double? {
        let normalized = cost
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        
        return Double(normalized)
    }
    
    private var parsedFuelLiters: Double? {
        let normalized = fuelLiters
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        
        return Double(normalized)
    }
    
    private var eventMetadata: [String: EventMetadataValue]? {
        guard type == .refuel,
              let parsedFuelLiters else {
            return nil
        }
        
        return ["fuel_liters": .double(parsedFuelLiters)]
    }
    
    private func submit() async {
        guard let vehicleId = vehicleViewModel.activeVehicleId,
              let token = authViewModel.token else {
            return
        }
        
        let request = VehicleEventRequest(
            type: type,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).emptyToNil,
            eventDate: date.iso8601String,
            mileageKm: Int(mileage.filter { $0.isNumber }),
            cost: parsedCost,
            fuelLiters: type == .refuel ? parsedFuelLiters : nil,
            metadata: eventMetadata
        )
        
        let createdEvent = await repository.createEventAndReturn(
            vehicleId: vehicleId,
            token: token,
            event: request
        )
        
        if let createdEvent {
            if !selectedPhotoData.isEmpty {
                photoStore.setPhotos(selectedPhotoData, for: createdEvent.id)
            }
            
            onClose()
        }
    }
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        var loadedPhotos: [Data] = []
        
        for item in items.prefix(6) {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }
            
            loadedPhotos.append(data.normalizedEventPhotoData)
        }
        
        selectedPhotoData = loadedPhotos
    }
}

private struct EventFieldSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(2)
            
            content
        }
    }
}

private struct EventTextFieldSection: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var axis: Axis = .horizontal
    
    var body: some View {
        EventFieldSection(title: title) {
            TextField(placeholder, text: $text, axis: axis)
                .keyboardType(keyboardType)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(axis == .vertical ? 3...5 : 1...1)
                .padding(AppSpacing.md)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xl)
                        .stroke(AppColors.bubbleBorder, lineWidth: 1)
                )
        }
    }
}

private struct EventPhotoPickerSection: View {
    @Binding var selectedItems: [PhotosPickerItem]
    let photos: [Data]
    
    var body: some View {
        EventFieldSection(title: "ATTACH PHOTOS") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 6,
                    matching: .images
                ) {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 44, height: 44)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(photos.isEmpty ? "Add repair evidence" : "\(photos.count) photo\(photos.count == 1 ? "" : "s") selected")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Photos are saved locally until backend upload is available.")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(AppColors.primary)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xl)
                            .stroke(AppColors.bubbleBorder, lineWidth: 1)
                    )
                }
                
                if !photos.isEmpty {
                    EventPhotoStrip(photos: photos)
                }
            }
        }
    }
}

private extension VehicleEventType {
    static var formTypes: [VehicleEventType] {
        [.trip, .refuel, .repair, .maintenance, .inspection, .diagnostic, .note]
    }
    
    var supportsPhotoAttachments: Bool {
        switch self {
        case .repair, .maintenance, .inspection, .diagnostic, .partReplacement, .note:
            return true
        default:
            return false
        }
    }
    
    var iconName: String {
        switch self {
        case .trip:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .refuel:
            return "fuelpump.fill"
        case .repair:
            return "wrench.and.screwdriver.fill"
        case .maintenance:
            return "gearshape.2.fill"
        case .warning, .accident, .recall:
            return "exclamationmark.triangle.fill"
        case .inspection, .diagnostic:
            return "waveform.path.ecg"
        case .prediction:
            return "sparkles"
        case .partReplacement:
            return "shippingbox.fill"
        case .note:
            return "note.text"
        }
    }
    
    var tintColor: Color {
        switch self {
        case .trip:
            return AppColors.primary
        case .refuel:
            return AppColors.teal
        case .repair, .maintenance, .partReplacement:
            return AppColors.orange
        case .warning, .accident, .recall:
            return AppColors.red
        case .inspection, .diagnostic, .prediction:
            return AppColors.green
        case .note:
            return AppColors.textSecondary
        }
    }
}

extension VehicleEvent {
    var parsedEventDate: Date? {
        eventDate.iso8601Date
    }
    
    var eventSortDate: Date {
        parsedEventDate ?? .distantPast
    }
    
    var monthKey: String {
        eventSortDate.formatted(.dateTime.month(.wide).year())
    }
}

private extension String {
    var emptyToNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    var iso8601Date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: self) {
            return date
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }
    
    var timelineDayText: String {
        guard let date = iso8601Date else { return self }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

private extension Double {
    var fuelLitersText: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}

private extension Data {
    var normalizedEventPhotoData: Data {
        guard let image = UIImage(data: self) else {
            return self
        }
        
        let maxSide: CGFloat = 1200
        let size = image.size
        let scale = Swift.min(1, maxSide / Swift.max(size.width, size.height))
        let targetSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        return resizedImage.jpegData(compressionQuality: 0.78) ?? self
    }
}
