#if !SKIP
import SwiftData

enum FocusGardenSchema {
    static let models: [any PersistentModel.Type] = [
        FocusTask.self,
        Course.self,
        ClassBlock.self,
        Assessment.self,
        AppStateRecord.self,
        GardenPlant.self,
        ActivityLog.self
    ]
}
#else
enum FocusGardenSchema {
    static let models: [Any.Type] = []
}
#endif
