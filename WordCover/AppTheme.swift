import SwiftUI

enum AppTheme {
    static let accent = Color(uiColor: .label)
    static let canvas = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let separator = Color(uiColor: .separator)
    static let softAccent = Color(uiColor: .tertiarySystemFill)
    // Keep editor outlines visible over photos in both appearances.
    static let ink = Color(white: 0.10)
}

struct StudyButtonStyle: ButtonStyle {
    var selected = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 12)
            .foregroundStyle(AppTheme.accent)
            .background(selected ? AppTheme.softAccent : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? AppTheme.accent : AppTheme.separator, lineWidth: selected ? 1 : 0.5)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.55 : 1) : 0.35)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct LanguageTabButtonStyle: ButtonStyle {
    var selected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? AppTheme.accent : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(selected ? AppTheme.accent : .clear)
                    .frame(height: 2)
                    .padding(.horizontal, 24)
            }
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: selected)
    }
}

struct LanguageToggleButton: View {
    @AppStorage(AppLanguage.storageKey) private var storedLanguage: AppLanguage = .chinese

    var body: some View {
        Button {
            storedLanguage = storedLanguage == .chinese ? .english : .chinese
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .fontWeight(.regular)
                Text(storedLanguage == .chinese ? "EN" : "中")
                    .font(.subheadline.weight(.medium))
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityIdentifier("language-toggle")
        .accessibilityLabel(storedLanguage.text(storedLanguage == .chinese ? "切换到英文" : "切换到中文"))
        .accessibilityValue(storedLanguage == .chinese ? "中文" : "English")
    }
}
