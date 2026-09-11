import Foundation
#if !SKIP
import SwiftData

struct ICSImportService {
    var parser: ICSParser
    var container: ModelContainer

    func preview(data: Data) -> ICSParseResult {
        parser.parse(data: data)
    }

    func commit(result: ICSParseResult) async throws -> ICSImportCommit {
        try await withCheckedThrowingContinuation { continuation in
            let background = ModelContext(container)
            background.autosaveEnabled = false
            do {
                let existingBlocks = try background.fetch(FetchDescriptor<ClassBlock>())
                let existingAssessments = try background.fetch(FetchDescriptor<Assessment>())
                let blockFingerprints = Set(existingBlocks.map(\.fingerprint))
                let assessmentFingerprints = Set(existingAssessments.map(\.fingerprint))

                var insertedBlocks = 0
                var insertedAssessments = 0

                for preview in result.previews {
                    if blockFingerprints.contains(preview.fingerprint) { continue }
                    let course = try resolveCourse(
                        code: preview.courseCode,
                        title: preview.courseTitle,
                        context: background
                    )
                    let block = ClassBlock(
                        dayOfWeek: preview.dayOfWeek,
                        startTime: preview.startTime,
                        duration: preview.duration,
                        cognitiveWeight: preview.cognitiveWeight,
                        course: course,
                        meetingType: preview.meetingType,
                        fingerprint: preview.fingerprint,
                        summary: preview.sampleSummary,
                        validFrom: preview.validFrom,
                        validUntil: preview.validUntil
                    )
                    background.insert(block)
                    insertedBlocks += 1
                }

                for preview in result.assessments {
                    if assessmentFingerprints.contains(preview.fingerprint) { continue }
                    let course = try resolveCourse(
                        code: preview.courseCode,
                        title: preview.courseTitle,
                        context: background
                    )
                    let assessment = Assessment(
                        title: preview.title,
                        kind: preview.kind,
                        start: preview.start,
                        end: preview.end,
                        isAllDay: preview.isAllDay,
                        fingerprint: preview.fingerprint,
                        course: course
                    )
                    background.insert(assessment)
                    insertedAssessments += 1
                }

                try background.save()
                continuation.resume(returning: ICSImportCommit(
                    classBlocks: insertedBlocks,
                    assessments: insertedAssessments
                ))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func resolveCourse(code: String, title: String, context: ModelContext) throws -> Course {
        let existing = try context.fetch(FetchDescriptor<Course>())
        if let match = existing.first(where: { $0.code.caseInsensitiveCompare(code) == ComparisonResult.orderedSame }) {
            if match.title.isEmpty { match.title = title }
            return match
        }
        let course = Course(code: code, title: title)
        context.insert(course)
        return course
    }
}
#endif

struct ICSImportCommit: Equatable, Sendable {
    var classBlocks: Int
    var assessments: Int

    var insertedCount: Int { classBlocks + assessments }
}
