import CareerDomain
import DocumentEngine
import Foundation

/// The single validated PDF that preview, sharing, and printing all consume.
/// It can only be built from a rendered document that passed export
/// validation, so every surface receives identical bytes.
public struct ExportArtifact: Equatable, Sendable {
    public let data: Data
    public let snapshotHash: UInt64
    public let pageCount: Int

    public init(
        rendered: RenderedDocument,
        snapshot: DocumentSnapshot,
        plan: LayoutPlan
    ) throws {
        let validation = ExportValidator.validate(artifact: rendered, snapshot: snapshot, plan: plan)
        guard validation.isValid else { throw EngineError.validation(validation.issues) }
        self.data = rendered.data
        self.snapshotHash = rendered.snapshotHash
        self.pageCount = rendered.pageCount
    }

    /// Writes the same bytes to a file for the share sheet or Files. The file
    /// is excluded from backup and protected until first user authentication.
    public func writeFile(named name: String, in directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = directory.appendingPathComponent(safeName).appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = url
            try mutable.setResourceValues(values)
        } catch {
            throw EngineError.internalFailure("The PDF could not be written to a file")
        }
        return url
    }
}
