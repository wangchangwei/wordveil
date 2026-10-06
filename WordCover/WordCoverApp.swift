import SwiftUI
import SwiftData

@main
struct WordCoverApp: App {
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .chinese

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .tint(AppTheme.accent)
        }
        .modelContainer(for: StudyCard.self)
    }
}
