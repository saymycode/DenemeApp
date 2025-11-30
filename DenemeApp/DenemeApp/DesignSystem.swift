// MARK: - Design System
// Colors, typography, spacing, and reusable components

import SwiftUI

enum AppColors {
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let card = Color(UIColor.secondarySystemBackground)
    static let primary = Color(UIColor.systemIndigo)
    static let accent = Color(UIColor.systemTeal)
    static let warning = Color(UIColor.systemOrange)
    static let bad = Color(UIColor.systemRed)
    static let good = Color(UIColor.systemGreen)
    static let electricity = Color.yellow
    static let water = Color.blue
    static let naturalGas = Color.orange
    static let internet = Color.purple
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 20
    static let xl: CGFloat = 28
}

enum AppTypography {
    static func titleLarge() -> some ViewModifier {
        return FontModifier(font: .system(.largeTitle, design: .rounded), weight: .bold)
    }
    static func titleMedium() -> some ViewModifier {
        return FontModifier(font: .system(.title2, design: .rounded), weight: .semibold)
    }
    static func body() -> some ViewModifier {
        return FontModifier(font: .system(.body, design: .rounded), weight: .regular)
    }
    static func caption() -> some ViewModifier {
        return FontModifier(font: .system(.caption, design: .rounded), weight: .medium)
    }
}

struct FontModifier: ViewModifier {
    let font: Font
    let weight: Font.Weight
    func body(content: Content) -> some View {
        content.font(font.weight(weight))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, AppSpacing.m)
            .frame(maxWidth: .infinity)
            .background(AppColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

struct TagChipView: View {
    let text: String
    var color: Color = AppColors.accent
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.xs)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardModifier())
    }
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
