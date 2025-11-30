// MARK: - ViewModels
// ObservableObjects powering the SwiftUI views

import Foundation
import SwiftUI
import CoreLocation

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var step: Int = 0
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var notificationGranted: Bool = false
    @Published var selectedTypes: Set<ProviderType> = Set(ProviderType.allCases)
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    func requestLocationPermission() {
        // Stub for real location manager
        locationStatus = .authorizedWhenInUse
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func requestNotificationPermission() {
        Task {
            notificationGranted = await NotificationManager.shared.requestPermission()
            UINotificationFeedbackGenerator().notificationOccurred(notificationGranted ? .success : .error)
        }
    }

    func toggle(type: ProviderType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func complete() {
        hasCompletedOnboarding = true
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var outages: [Outage] = []
    @Published var filteredOutages: [Outage] = []
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var selectedProviderType: ProviderType? = nil
    @Published var statusFilter: OutageStatus? = nil
    @Published var addresses: [Address] = []

    let repository: AppRepository
    private let location: CLLocationCoordinate2D

    init(repository: AppRepository, location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 38.4237, longitude: 27.1428)) {
        self.repository = repository
        self.location = location
    }

    func load(addresses: [Address]) {
        self.addresses = addresses
        Task { await fetchOutages() }
    }

    func fetchOutages() async {
        isLoading = true
        error = nil
        let result = await repository.getOutagesForCurrentLocation(latitude: location.latitude, longitude: location.longitude)
        switch result {
        case .success(let data):
            outages = data
            applyFilters()
        case .failure:
            error = .network
        }
        isLoading = false
    }

    func applyFilters() {
        var data = outages
        if let type = selectedProviderType {
            data = data.filter { $0.type == type }
        }
        if let status = statusFilter {
            switch status {
            case .planned:
                data = data.filter { $0.status == .planned || $0.isUpcoming }
            case .unplanned:
                data = data.filter { $0.status == .unplanned && $0.isActiveNow }
            case .resolved:
                data = data.filter { $0.isPast }
            }
        }
        filteredOutages = data
    }

    func refresh() async {
        await fetchOutages()
    }
}

@MainActor
class AddressesViewModel: ObservableObject {
    @Published var addresses: [Address] = []
    private let storageKey = "savedAddresses"

    init() {
        load()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey), let decoded = try? JSONDecoder().decode([Address].self, from: data) {
            addresses = decoded
        } else {
            addresses = [Address(id: UUID(), label: "Ev", fullText: "Karabağlar, İzmir", latitude: 38.384, longitude: 27.128, isPrimary: true)]
            persist()
        }
    }

    func persist() {
        if let data = try? JSONEncoder().encode(addresses) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addAddress(label: String, fullText: String, coordinate: CLLocationCoordinate2D) {
        let new = Address(id: UUID(), label: label, fullText: fullText, latitude: coordinate.latitude, longitude: coordinate.longitude, isPrimary: addresses.isEmpty)
        addresses.append(new)
        persist()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func delete(at offsets: IndexSet) {
        addresses.remove(atOffsets: offsets)
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        addresses.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func setPrimary(_ address: Address) {
        addresses = addresses.map { item in
            var mutable = item
            mutable.isPrimary = item.id == address.id
            return mutable
        }
        persist()
    }
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var outages: [Outage] = []
    @Published var range: Int = 7
    @Published var selectedType: ProviderType? = nil

    func load(outages: [Outage]) {
        self.outages = outages
    }

    var filtered: [Outage] {
        let startDate = Calendar.current.date(byAdding: .day, value: -range, to: Date()) ?? Date()
        return outages.filter { outage in
            outage.startDate >= startDate && (selectedType == nil || outage.type == selectedType!)
        }
    }

    var planCount: Int { filtered.filter { $0.status == .planned }.count }
    var unplannedCount: Int { filtered.filter { $0.status == .unplanned }.count }

    var busiestDay: String {
        let grouped = Dictionary(grouping: filtered) { Calendar.current.component(.day, from: $0.startDate) }
        let best = grouped.max { $0.value.count < $1.value.count }
        return "Gün \(best?.key ?? 0)"
    }

    var calmDay: String {
        let grouped = Dictionary(grouping: filtered) { Calendar.current.component(.day, from: $0.startDate) }
        let best = grouped.min { $0.value.count < $1.value.count }
        return "Gün \(best?.key ?? 0)"
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @AppStorage("showPast") var showPast: Bool = true
    @AppStorage("notificationElectricity") var notificationElectricity: Bool = true
    @AppStorage("notificationWater") var notificationWater: Bool = true
    @AppStorage("notificationGas") var notificationGas: Bool = true
    @AppStorage("notificationInternet") var notificationInternet: Bool = true

    func clearCache() {
        NotificationManager.shared.cancelAll()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

@MainActor
class OutageDetailViewModel: ObservableObject {
    @Published var outage: Outage
    @Published var reports: [UserReport] = []
    private let repository: AppRepository

    init(outage: Outage, repository: AppRepository) {
        self.outage = outage
        self.repository = repository
        self.reports = sampleReports()
    }

    func addReport(isPowerBack: Bool, comment: String?) {
        let report = UserReport(id: UUID(), outageId: outage.id, addressId: nil, timestamp: Date(), comment: comment, isPowerBack: isPowerBack)
        reports.append(report)
        Task { await repository.send(report: report) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func sampleReports() -> [UserReport] {
        [
            UserReport(id: UUID(), outageId: outage.id, addressId: nil, timestamp: Date().addingTimeInterval(-600), comment: "Bizde de kesildi", isPowerBack: false),
            UserReport(id: UUID(), outageId: outage.id, addressId: nil, timestamp: Date().addingTimeInterval(-1200), comment: "Su zayıf akıyor", isPowerBack: false)
        ]
    }
}
