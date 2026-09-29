import CareerDomain
import Foundation
import PersistenceSync
import Testing

@Test func workspaceArchiveRoundTripsDeterministically() throws {
    let workspace = Workspace(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let archive = WorkspaceArchive(
        exportedAt: Date(timeIntervalSince1970: 1_800_000_000),
        workspace: workspace
    )
    let codec = WorkspaceArchiveCodec()
    let first = try codec.encode(archive)
    let second = try codec.encode(archive)
    #expect(first == second)
    #expect(try codec.decode(first) == archive)
}

@Test func futureArchiveSchemaIsRejectedWithoutDataMutation() throws {
    let json = Data("{\"schemaVersion\":999,\"exportedAt\":\"2027-01-15T08:00:00Z\",\"workspace\":{}}".utf8)
    do {
        _ = try WorkspaceArchiveCodec().decode(json)
        Issue.record("Expected a future schema to be rejected")
    } catch {
        #expect(error as? EngineError == .incompatibleSchema(999))
    }
}

@Test func threeWayMergeNeverSilentlyDropsConcurrentChanges() {
    #expect(ThreeWayMerge.resolve(base: "A", local: "B", remote: "A") == .merged("B"))
    #expect(ThreeWayMerge.resolve(base: "A", local: "B", remote: "C") == .conflict(local: "B", remote: "C"))
}

