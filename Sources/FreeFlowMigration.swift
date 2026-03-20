import Foundation

enum FreeFlowMigration {
    private static let migrationDoneKey = "grain_migration_from_freeflow_done"
    private static let jottrMigrationDoneKey = "jottr_migration_from_grain_done"

    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }

        migrateUserDefaults()
        migrateAppSupportSettings()

        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }

    static func migrateGrainToJottrIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: jottrMigrationDoneKey) else { return }

        // Additional guard: skip migration if Jottr data already exists.
        // This prevents overwriting real user data if the migration-done key
        // was lost (e.g., Preferences reset, clean-install update path).
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let jottrDir = appSupport.appendingPathComponent("Jottr", isDirectory: true)
            let jottrSettings = jottrDir.appendingPathComponent(".settings")
            let jottrSnippets = jottrDir.appendingPathComponent("snippets.json")
            if fm.fileExists(atPath: jottrSettings.path) || fm.fileExists(atPath: jottrSnippets.path) {
                // Jottr data exists — mark migration as done without overwriting
                UserDefaults.standard.set(true, forKey: jottrMigrationDoneKey)
                return
            }
        }

        migrateGrainAppSupportToJottr()

        UserDefaults.standard.set(true, forKey: jottrMigrationDoneKey)
    }

    private static func migrateGrainAppSupportToJottr() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let grainDir = appSupport.appendingPathComponent("Grain", isDirectory: true)
        let jottrDir = appSupport.appendingPathComponent("Jottr", isDirectory: true)

        // Migrate .settings file
        let grainSettings = grainDir.appendingPathComponent(".settings")
        let jottrSettings = jottrDir.appendingPathComponent(".settings")

        if fm.fileExists(atPath: grainSettings.path) && !fm.fileExists(atPath: jottrSettings.path) {
            try? fm.createDirectory(at: jottrDir, withIntermediateDirectories: true)
            try? fm.copyItem(at: grainSettings, to: jottrSettings)
        }

        // Migrate snippets.json file
        let grainSnippets = grainDir.appendingPathComponent("snippets.json")
        let jottrSnippets = jottrDir.appendingPathComponent("snippets.json")

        if fm.fileExists(atPath: grainSnippets.path) && !fm.fileExists(atPath: jottrSnippets.path) {
            try? fm.createDirectory(at: jottrDir, withIntermediateDirectories: true)
            try? fm.copyItem(at: grainSnippets, to: jottrSnippets)
        }
    }

    private static func migrateUserDefaults() {
        guard let oldDefaults = UserDefaults(suiteName: "com.zachlatta.freeflow") else { return }

        let keysToMigrate: [String] = [
            "hasCompletedSetup",
            "hotkey_option",
            "custom_vocabulary",
            "selected_microphone_id",
            "custom_system_prompt",
            "custom_context_prompt",
            "custom_system_prompt_last_modified",
            "custom_context_prompt_last_modified"
        ]

        for key in keysToMigrate {
            if let value = oldDefaults.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
    }

    private static func migrateAppSupportSettings() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let oldDir = appSupport.appendingPathComponent("FreeFlow", isDirectory: true)
        let newDir = appSupport.appendingPathComponent("Grain", isDirectory: true)

        let oldSettings = oldDir.appendingPathComponent(".settings")
        let newSettings = newDir.appendingPathComponent(".settings")

        // Skip if old data doesn't exist or new .settings already exists
        guard fm.fileExists(atPath: oldSettings.path),
              !fm.fileExists(atPath: newSettings.path) else { return }

        try? fm.createDirectory(at: newDir, withIntermediateDirectories: true)
        try? fm.copyItem(at: oldSettings, to: newSettings)
    }
}
