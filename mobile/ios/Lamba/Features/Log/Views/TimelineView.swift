//
//  TimelineView.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct TimelineView: View {
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    @StateObject private var timelineRepository = TimelineRepository()
    @State private var selectedFilter: TimelineFilter = .all
    @State private var isAddingEvent = false
    
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
        .fullScreenCover(isPresented: $isAddingEvent) {
            AddEventView(
                repository: timelineRepository,
                onClose: {
                    isAddingEvent = false
                }
            )
            .environmentObject(authViewModel)
            .environmentObject(vehicleViewModel)
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
                    
                    TimelineStatsGrid(
                        stats: timelineRepository.stats,
                        events: timelineRepository.events
                    )
                    
                    if let latestEvent = timelineRepository.events.first {
                        LatestTimelineEventCard(event: latestEvent)
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
        
        _ = await timelineRepository.deleteEvent(
            vehicleId: vehicleId,
            eventId: event.id,
            token: token
        )
    }
}

private struct TimelineMonthGroup: Identifiable {
    let title: String
    let events: [VehicleEvent]
    
    var id: String { title }
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
                                isDeleting: deletingEventIds.contains(event.id),
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
    let isDeleting: Bool
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
            
            TimelineEventCard(event: event)
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
                    
                    if let description = event.description, !description.isEmpty {
                        EventMetaPill(icon: "text.alignleft", text: description)
                    }
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
    let onClose: () -> Void
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    @State private var type: VehicleEventType = .trip
    @State private var title = ""
    @State private var description = ""
    @State private var mileage = ""
    @State private var cost = ""
    @State private var date = Date()
    
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
            cost: parsedCost
        )
        
        let didCreate = await repository.createEvent(
            vehicleId: vehicleId,
            token: token,
            event: request
        )
        
        if didCreate {
            onClose()
        }
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

private extension VehicleEventType {
    static var formTypes: [VehicleEventType] {
        [.trip, .refuel, .repair, .maintenance, .inspection, .diagnostic, .note]
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
