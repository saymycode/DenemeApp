// MARK: - Models
// Core data structures for Kesinti Radar

import Foundation
import SwiftUI

struct Address: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var fullText: String
    var latitude: Double
    var longitude: Double
    var isPrimary: Bool
}

enum ProviderType: String, Codable, CaseIterable, Identifiable {
    case electricity, water, naturalGas, internet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .electricity: return "Elektrik"
        case .water: return "Su"
        case .naturalGas: return "Doğalgaz"
        case .internet: return "İnternet"
        }
    }

    var symbolName: String {
        switch self {
        case .electricity: return "bolt.fill"
        case .water: return "drop.fill"
        case .naturalGas: return "flame.fill"
        case .internet: return "wifi"
        }
    }

    var tint: Color {
        switch self {
        case .electricity: return AppColors.electricity
        case .water: return AppColors.water
        case .naturalGas: return AppColors.naturalGas
        case .internet: return AppColors.internet
        }
    }
}

struct Provider: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: ProviderType
    var serviceRegions: [String]
    var isSelected: Bool
}

enum OutageStatus: String, Codable, CaseIterable, Identifiable {
    case planned, unplanned, resolved

    var id: String { rawValue }
    var label: String {
        switch self {
        case .planned: return "Planlı"
        case .unplanned: return "Plansız"
        case .resolved: return "Çözüldü"
        }
    }

    var chipColor: Color {
        switch self {
        case .planned: return AppColors.warning
        case .unplanned: return AppColors.bad
        case .resolved: return AppColors.good
        }
    }
}

struct Outage: Identifiable, Codable, Equatable {
    let id: UUID
    var provider: Provider
    var type: ProviderType
    var title: String
    var description: String
    var status: OutageStatus
    var startDate: Date
    var estimatedEndDate: Date?
    var affectedAreas: [String]
    var latitude: Double
    var longitude: Double
    var userReportedCount: Int
    var sourceUrl: URL?

    var isActiveNow: Bool {
        status != .resolved && startDate <= Date() && (estimatedEndDate == nil || estimatedEndDate ?? Date() > Date())
    }

    var isUpcoming: Bool {
        status != .resolved && startDate > Date()
    }

    var isPast: Bool {
        status == .resolved || (estimatedEndDate ?? Date()) < Date()
    }
}

struct UserReport: Identifiable, Codable, Equatable {
    let id: UUID
    var outageId: UUID
    var addressId: UUID?
    var timestamp: Date
    var comment: String?
    var isPowerBack: Bool
}

enum AppError: Error, LocalizedError {
    case network
    case decoding
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .network:
            return "Ağ hatası. Lütfen tekrar deneyin."
        case .decoding:
            return "Veri okunamadı."
        case .custom(let message):
            return message
        }
    }
}
