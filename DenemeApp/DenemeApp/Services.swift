// MARK: - Services
// Data sources, repository, and notification manager

import Foundation
import SwiftUI
import UserNotifications

protocol OutageDataSource {
    func fetchProviders() async throws -> [Provider]
    func fetchOutages(around latitude: Double, longitude: Double) async throws -> [Outage]
    func fetchOutages(for address: Address) async throws -> [Outage]
    func fetchOutageHistory(for address: Address) async throws -> [Outage]
    func sendUserReport(_ report: UserReport) async throws
}

enum OutageDataError: Error, LocalizedError {
    case noConnection
    case server
    case empty

    var errorDescription: String? {
        switch self {
        case .noConnection: return "Bağlantı yok gibi görünüyor."
        case .server: return "Sunucu hata verdi."
        case .empty: return "Bu kriterlere uygun veri yok."
        }
    }
}

actor MockOutageDataSource: OutageDataSource {
    private var providers: [Provider]
    private var outages: [Outage]

    init(now: Date = Date()) {
        let electricityProvider = Provider(id: UUID(), name: "Gediz Elektrik", type: .electricity, serviceRegions: ["İzmir", "Manisa"], isSelected: true)
        let waterProvider = Provider(id: UUID(), name: "İZSU", type: .water, serviceRegions: ["İzmir"], isSelected: true)
        let gasProvider = Provider(id: UUID(), name: "İZGAZ", type: .naturalGas, serviceRegions: ["İzmit", "İzmir"], isSelected: false)
        let internetProvider = Provider(id: UUID(), name: "SüperNet", type: .internet, serviceRegions: ["İzmir", "Ankara"], isSelected: true)
        self.providers = [electricityProvider, waterProvider, gasProvider, internetProvider]

        let today = now
        let twoHours: TimeInterval = 60 * 60 * 2
        self.outages = [
            Outage(
                id: UUID(),
                provider: electricityProvider,
                type: .electricity,
                title: "Karabağlar bakım çalışması",
                description: "Planlı bakım sebebiyle Karabağlar ilçesinin bazı mahallelerinde elektrik kesintisi yaşanacak.",
                status: .planned,
                startDate: Calendar.current.date(byAdding: .hour, value: 1, to: today) ?? today,
                estimatedEndDate: Calendar.current.date(byAdding: .hour, value: 4, to: today),
                affectedAreas: ["Bozyaka", "Bahçelievler"],
                latitude: 38.384,
                longitude: 27.128,
                userReportedCount: 12,
                sourceUrl: URL(string: "https://gediz.com.tr")
            ),
            Outage(
                id: UUID(),
                provider: waterProvider,
                type: .water,
                title: "Konak acil arıza",
                description: "Ana hat arızası nedeniyle su kesintisi yaşanıyor. Ekipler müdahale ediyor.",
                status: .unplanned,
                startDate: Calendar.current.date(byAdding: .minute, value: -45, to: today) ?? today,
                estimatedEndDate: Calendar.current.date(byAdding: .hour, value: 2, to: today),
                affectedAreas: ["Alsancak", "Kordon", "Güzelyalı"],
                latitude: 38.432,
                longitude: 27.140,
                userReportedCount: 34,
                sourceUrl: URL(string: "https://izsu.gov.tr")
            ),
            Outage(
                id: UUID(),
                provider: internetProvider,
                type: .internet,
                title: "Bornova modem kesintisi",
                description: "Bölgesel modem kaynaklı kesinti. İnternet erişimi yavaş veya kesik olabilir.",
                status: .resolved,
                startDate: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                estimatedEndDate: Calendar.current.date(byAdding: .hour, value: -12, to: today),
                affectedAreas: ["Bornova", "Evka 3"],
                latitude: 38.459,
                longitude: 27.222,
                userReportedCount: 6,
                sourceUrl: URL(string: "https://supernet.com")
            ),
            Outage(
                id: UUID(),
                provider: gasProvider,
                type: .naturalGas,
                title: "Buca vana değişimi",
                description: "Planlı vana değişim çalışması yapılacaktır.",
                status: .planned,
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today,
                estimatedEndDate: Calendar.current.date(byAdding: .day, value: 1, to: today).addingTimeInterval(twoHours),
                affectedAreas: ["Şirinyer", "Kaynaklar"],
                latitude: 38.388,
                longitude: 27.174,
                userReportedCount: 0,
                sourceUrl: URL(string: "https://izgaz.com")
            )
        ]
    }

    private func simulateDelay() async throws {
        try await Task.sleep(nanoseconds: 450_000_000)
        if Bool.random() && Bool.random() {
            throw OutageDataError.noConnection
        }
    }

    func fetchProviders() async throws -> [Provider] {
        try await simulateDelay()
        return providers
    }

    func fetchOutages(around latitude: Double, longitude: Double) async throws -> [Outage] {
        try await simulateDelay()
        return outages
    }

    func fetchOutages(for address: Address) async throws -> [Outage] {
        try await simulateDelay()
        return outages.filter { _ in Bool.random() || true }
    }

    func fetchOutageHistory(for address: Address) async throws -> [Outage] {
        try await simulateDelay()
        return outages.filter { $0.isPast }
    }

    func sendUserReport(_ report: UserReport) async throws {
        try await simulateDelay()
    }
}

@MainActor
class AppRepository: ObservableObject {
    private let outageDataSource: OutageDataSource
    @Published var providers: [Provider] = []

    init(outageDataSource: OutageDataSource = MockOutageDataSource()) {
        self.outageDataSource = outageDataSource
    }

    func loadInitialData() async {
        do {
            providers = try await outageDataSource.fetchProviders()
        } catch {
            print("Provider load error: \(error)")
        }
    }

    func getOutagesForCurrentLocation(latitude: Double, longitude: Double) async -> Result<[Outage], Error> {
        do {
            let data = try await outageDataSource.fetchOutages(around: latitude, longitude: longitude)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }

    func getOutages(for address: Address) async -> Result<[Outage], Error> {
        do {
            let result = try await outageDataSource.fetchOutages(for: address)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    func getOutageHistory(for address: Address) async -> Result<[Outage], Error> {
        do {
            let result = try await outageDataSource.fetchOutageHistory(for: address)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    func send(report: UserReport) async {
        do {
            try await outageDataSource.sendUserReport(report)
        } catch {
            print("Report send failed: \(error)")
        }
    }
}

// MARK: - Notification manager
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func schedule(outage: Outage) async {
        guard outage.isUpcoming else { return }
        let triggerDate = outage.startDate.addingTimeInterval(-1800)
        if triggerDate < Date() { return }

        let content = UNMutableNotificationContent()
        content.title = "Yaklaşan kesinti: \(outage.title)"
        content.body = "\(outage.provider.name) \(outage.startDate.formatted(date: .omitted, time: .shortened))'de başlayacak."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerDate.timeIntervalSinceNow, repeats: false)
        let request = UNNotificationRequest(identifier: outage.id.uuidString, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("Notification scheduling failed: \(error)")
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
