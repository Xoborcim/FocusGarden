#if !SKIP
import SwiftData
import SwiftUI

enum PersistenceController {
    static let sharedContainer: ModelContainer = makeContainer()

    /// Local SwiftData store. CloudKit is off because a Personal Team cannot
    /// provision the iCloud capability. Flip `cloudKitDatabase` to `.automatic`
    /// and add the iCloud entitlement after joining the paid Apple Developer Program.
    static func makeContainer() -> ModelContainer {
        let schema = Schema(FocusGardenSchema.models)
        let configuration = ModelConfiguration(
            "FocusGardenLite2",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: ModelConfiguration.CloudKitDatabase.none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let local = ModelConfiguration(
                "FocusGardenLite2Local",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: ModelConfiguration.CloudKitDatabase.none
            )
            return try! ModelContainer(for: schema, configurations: [local])
        }
    }

    static func inMemory() -> ModelContainer {
        let schema = Schema(FocusGardenSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: ModelConfiguration.CloudKitDatabase.none)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}
#else
import Foundation
import SwiftUI

public final class ModelContext {
    public init(_ container: Any? = nil) {}
    public func fetch<T>(_ descriptor: FetchDescriptor<T>? = nil) throws -> [T] { [] }
    public func insert<T>(_ model: T) {}
    public func delete<T>(_ model: T) {}
    public func save() throws {}
}

public final class ModelContainer {
    public var mainContext: ModelContext { ModelContext() }
    public init(for models: Any? = nil, configurations: Any? = nil) throws {}
    public init(_ models: Any?...) throws {}
}

public struct FetchDescriptor<T> {
    public var predicate: Any?
    public var sortBy: [SortDescriptor<T>]
    public init(predicate: Any? = nil, sortBy: [SortDescriptor<T>] = []) {
        self.predicate = predicate
        self.sortBy = sortBy
    }
}

public struct SortDescriptor<T> {
    public init(_ keyPath: Any? = nil, order: Any? = nil) {}
}

public enum SortOrder {
    case forward
    case reverse
}

private struct ModelContextKey: EnvironmentKey {
    static let defaultValue: ModelContext = ModelContext()
}

extension EnvironmentValues {
    public var modelContext: ModelContext {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
    }
}

extension View {
    public func modelContainer(_ container: ModelContainer) -> some View {
        self.environment(\.modelContext, container.mainContext)
    }
}

enum PersistenceController {
    static let sharedContainer: ModelContainer = makeContainer()
    static func makeContainer() -> ModelContainer { ModelContainer() }
    static func inMemory() -> ModelContainer { ModelContainer() }
}
#endif

