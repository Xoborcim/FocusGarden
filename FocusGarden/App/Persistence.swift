import SwiftData
import SwiftUI

enum PersistenceController {
    /// Local SwiftData store. CloudKit is off because a Personal Team cannot
    /// provision the iCloud capability. Flip `cloudKitDatabase` to `.automatic`
    /// and add the iCloud entitlement after joining the paid Apple Developer Program.
    static func makeContainer() -> ModelContainer {
        let schema = Schema(FocusGardenSchema.models)
        let configuration = ModelConfiguration(
            "FocusGardenLite2",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let local = ModelConfiguration(
                "FocusGardenLite2Local",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try! ModelContainer(for: schema, configurations: [local])
        }
    }

    static func inMemory() -> ModelContainer {
        let schema = Schema(FocusGardenSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}
