import Combine
import Foundation

public enum LeafClinicError: LocalizedError, Equatable, Sendable {
    case missingPlantNickname
    case caseNotFound
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingPlantNickname:
            "Plant nickname is required before saving. Add a name such as Pothos or Fiddle Leaf Fig, then try again."
        case .caseNotFound:
            "This leaf check could not be found. Return to the archive and choose the case again."
        case .persistenceFailed(let message):
            "The leaf check could not be saved. \(message)"
        }
    }
}

public struct LeafClinicArchive: Codable, Equatable, Sendable {
    public var cases: [PlantCase]
    public var premiumEntitlement: PremiumEntitlement

    public init(cases: [PlantCase] = [], premiumEntitlement: PremiumEntitlement = PremiumEntitlement()) {
        self.cases = cases
        self.premiumEntitlement = premiumEntitlement
    }
}

public protocol LeafClinicPersistence: Sendable {
    func loadArchive() throws -> LeafClinicArchive
    func saveArchive(_ archive: LeafClinicArchive) throws
}

public struct FileLeafClinicPersistence: LeafClinicPersistence {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = base.appendingPathComponent("LeafClinicWalkthrough", isDirectory: true)
                .appendingPathComponent("leaf-clinic-archive.json")
        }
    }

    public func loadArchive() throws -> LeafClinicArchive {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return LeafClinicArchive() }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.leafClinic.decode(LeafClinicArchive.self, from: data)
    }

    public func saveArchive(_ archive: LeafClinicArchive) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.leafClinic.encode(archive)
        try data.write(to: fileURL, options: [.atomic])
    }
}

private extension JSONEncoder {
    static var leafClinic: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var leafClinic: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
public final class LeafClinicStore: ObservableObject {
    @Published public private(set) var cases: [PlantCase]
    @Published public private(set) var premiumEntitlement: PremiumEntitlement
    @Published public var lastErrorMessage: String?
    private let persistence: LeafClinicPersistence

    public init(persistence: LeafClinicPersistence = FileLeafClinicPersistence()) {
        self.persistence = persistence
        do {
            let archive = try persistence.loadArchive()
            self.cases = archive.cases
            self.premiumEntitlement = archive.premiumEntitlement
        } catch {
            self.cases = []
            self.premiumEntitlement = PremiumEntitlement(storeKitUnavailableReason: "Local archive could not be read. New cases can still be drafted and saved again.")
            self.lastErrorMessage = LeafClinicError.persistenceFailed(error.localizedDescription).errorDescription
        }
    }

    public var activeCases: [PlantCase] { cases.filter { $0.status == .active || $0.status == .revisitDue } }
    public var recoveredCases: [PlantCase] { cases.filter { $0.status == .recovered } }
    public var revisitDueCases: [PlantCase] { cases.filter { $0.status == .revisitDue } }
    public var rescueInsights: [LeafRescueInsight] {
        activeCases
            .sorted { lhs, rhs in
                if lhs.status == rhs.status { return lhs.severity > rhs.severity }
                return lhs.status == .revisitDue
            }
            .map(LocalTriageEngine.rescueInsight)
    }
    public var primaryRescueInsight: LeafRescueInsight? { rescueInsights.first }

    @discardableResult
    public func createCase(from draft: LeafIntakeDraft, editedSteps: [CareStep]? = nil) throws -> PlantCase {
        let nickname = draft.plantNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else {
            lastErrorMessage = LeafClinicError.missingPlantNickname.errorDescription
            throw LeafClinicError.missingPlantNickname
        }
        let id = UUID()
        let snapshot = LeafSymptomSnapshot(
            caseId: id,
            moistureContext: draft.moistureContext,
            lightContext: draft.lightContext,
            soilContext: draft.soilContext,
            photoPlaceholderRef: draft.photoPlaceholderRef,
            note: draft.note
        )
        let baseSteps = LocalTriageEngine.recommendSteps(for: draft, caseId: id)
        var plantCase = PlantCase(
            id: id,
            plantNickname: nickname,
            symptomType: draft.symptomType,
            severity: draft.severity,
            status: .active,
            snapshot: snapshot,
            careSteps: editedSteps?.map { step in
                CareStep(
                    id: step.id,
                    caseId: id,
                    actionTitle: step.actionTitle,
                    rationale: step.rationale,
                    dueDay: step.dueDay,
                    completedAt: step.completedAt,
                    isSkipped: step.isSkipped
                )
            } ?? baseSteps
        )
        plantCase.status = plantCase.careSteps.contains(where: { $0.dueDay >= 7 }) ? .revisitDue : .active
        cases.insert(plantCase, at: 0)
        try persistOrSurfaceError()
        return plantCase
    }

    public func updateCase(_ plantCase: PlantCase) throws {
        guard !plantCase.plantNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastErrorMessage = LeafClinicError.missingPlantNickname.errorDescription
            throw LeafClinicError.missingPlantNickname
        }
        guard let index = cases.firstIndex(where: { $0.id == plantCase.id }) else {
            lastErrorMessage = LeafClinicError.caseNotFound.errorDescription
            throw LeafClinicError.caseNotFound
        }
        cases[index] = plantCase
        try persistOrSurfaceError()
    }

    public func updateCareStep(caseId: UUID, stepId: UUID, actionTitle: String, rationale: String) throws {
        guard let caseIndex = cases.firstIndex(where: { $0.id == caseId }),
              let stepIndex = cases[caseIndex].careSteps.firstIndex(where: { $0.id == stepId }) else {
            lastErrorMessage = LeafClinicError.caseNotFound.errorDescription
            throw LeafClinicError.caseNotFound
        }
        cases[caseIndex].careSteps[stepIndex].actionTitle = actionTitle
        cases[caseIndex].careSteps[stepIndex].rationale = rationale
        try persistOrSurfaceError()
    }

    public func toggleStep(caseId: UUID, stepId: UUID) throws {
        guard let caseIndex = cases.firstIndex(where: { $0.id == caseId }),
              let stepIndex = cases[caseIndex].careSteps.firstIndex(where: { $0.id == stepId }) else {
            lastErrorMessage = LeafClinicError.caseNotFound.errorDescription
            throw LeafClinicError.caseNotFound
        }
        if cases[caseIndex].careSteps[stepIndex].completedAt == nil {
            cases[caseIndex].careSteps[stepIndex].completedAt = Date()
        } else {
            cases[caseIndex].careSteps[stepIndex].completedAt = nil
        }
        try persistOrSurfaceError()
    }

    public func skipStep(caseId: UUID, stepId: UUID) throws {
        guard let caseIndex = cases.firstIndex(where: { $0.id == caseId }),
              let stepIndex = cases[caseIndex].careSteps.firstIndex(where: { $0.id == stepId }) else {
            lastErrorMessage = LeafClinicError.caseNotFound.errorDescription
            throw LeafClinicError.caseNotFound
        }
        cases[caseIndex].careSteps[stepIndex].isSkipped.toggle()
        try persistOrSurfaceError()
    }

    public func addRevisitNote(caseId: UUID, afterStatus: String, decision: RevisitDecision, note: String) throws {
        guard let index = cases.firstIndex(where: { $0.id == caseId }) else {
            lastErrorMessage = LeafClinicError.caseNotFound.errorDescription
            throw LeafClinicError.caseNotFound
        }
        let revisit = RevisitNote(caseId: caseId, afterStatus: afterStatus, userDecision: decision, note: note)
        cases[index].revisitNotes.insert(revisit, at: 0)
        cases[index].status = decision == .recovered ? .recovered : .revisitDue
        try persistOrSurfaceError()
    }

    public func deleteCase(id: UUID) throws {
        let originalCount = cases.count
        cases.removeAll { $0.id == id }
        guard cases.count != originalCount else {
            lastErrorMessage = LeafClinicError.caseNotFound.errorDescription
            throw LeafClinicError.caseNotFound
        }
        try persistOrSurfaceError()
    }

    private func persistOrSurfaceError() throws {
        do {
            try persistence.saveArchive(LeafClinicArchive(cases: cases, premiumEntitlement: premiumEntitlement))
            lastErrorMessage = nil
        } catch {
            let leafError = LeafClinicError.persistenceFailed(error.localizedDescription)
            lastErrorMessage = leafError.errorDescription
            throw leafError
        }
    }
}
