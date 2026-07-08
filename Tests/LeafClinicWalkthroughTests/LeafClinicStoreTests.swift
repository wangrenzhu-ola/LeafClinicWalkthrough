import Foundation
@testable import LeafClinicWalkthrough
import XCTest

@MainActor
final class LeafClinicStoreTests: XCTestCase {
    func testCreateEditAndDeletePlantCase() throws {
        let persistence = try temporaryPersistence()
        let store = LeafClinicStore(persistence: persistence)
        let plantCase = try store.createCase(from: LeafIntakeDraft(plantNickname: "Pothos", symptomType: .yellowEdges))

        XCTAssertEqual(store.cases.count, 1)
        XCTAssertEqual(store.cases[0].plantNickname, "Pothos")
        XCTAssertFalse(store.cases[0].careSteps.isEmpty)

        let firstStep = try XCTUnwrap(store.cases[0].careSteps.first)
        try store.updateCareStep(caseId: plantCase.id, stepId: firstStep.id, actionTitle: "Move plant two feet from the window", rationale: "Edited after checking the afternoon sun.")
        XCTAssertEqual(store.cases[0].careSteps[0].actionTitle, "Move plant two feet from the window")

        var editedCase = store.cases[0]
        editedCase.symptomType = .drooping
        editedCase.snapshot.moistureContext = "Soil is dry below the first knuckle"
        try store.updateCase(editedCase)
        XCTAssertEqual(store.cases[0].symptomType, .drooping)
        XCTAssertEqual(store.cases[0].snapshot.moistureContext, "Soil is dry below the first knuckle")

        try store.deleteCase(id: plantCase.id)
        XCTAssertTrue(store.cases.isEmpty)
    }

    func testPersistenceSurvivesStoreReopen() throws {
        let persistence = try temporaryPersistence()
        let store = LeafClinicStore(persistence: persistence)
        let plantCase = try store.createCase(from: LeafIntakeDraft(plantNickname: "Calathea", symptomType: .curling))
        try store.addRevisitNote(caseId: plantCase.id, afterStatus: "Leaf is less curled.", decision: .watch, note: "Keep humidity tray for two more days.")

        let reopenedStore = LeafClinicStore(persistence: persistence)
        XCTAssertEqual(reopenedStore.cases.count, 1)
        XCTAssertEqual(reopenedStore.cases[0].plantNickname, "Calathea")
        XCTAssertEqual(reopenedStore.cases[0].revisitNotes.count, 1)
        XCTAssertEqual(reopenedStore.cases[0].careSteps.last?.dueDay, 7)
    }

    func testMissingNicknameSurfacesRecoverableError() throws {
        let store = LeafClinicStore(persistence: try temporaryPersistence())
        XCTAssertThrowsError(try store.createCase(from: LeafIntakeDraft(plantNickname: ""))) { error in
            XCTAssertEqual(error as? LeafClinicError, .missingPlantNickname)
        }
        XCTAssertEqual(store.lastErrorMessage, LeafClinicError.missingPlantNickname.errorDescription)

        var savedCase = try store.createCase(from: LeafIntakeDraft(plantNickname: "Pothos", symptomType: .yellowEdges))
        savedCase.plantNickname = " "
        XCTAssertThrowsError(try store.updateCase(savedCase)) { error in
            XCTAssertEqual(error as? LeafClinicError, .missingPlantNickname)
        }
        XCTAssertEqual(store.lastErrorMessage, LeafClinicError.missingPlantNickname.errorDescription)
    }

    func testLocalTriageIsEditableSkippableAndConfirmable() throws {
        let store = LeafClinicStore(persistence: try temporaryPersistence())
        let draft = LeafIntakeDraft(plantNickname: "Snake Plant", symptomType: .spots)
        var editedSteps = LocalTriageEngine.recommendSteps(for: draft, caseId: UUID())
        editedSteps[0].actionTitle = "Wipe the spotted leaf and keep it dry"
        editedSteps[1].isSkipped = true

        let plantCase = try store.createCase(from: draft, editedSteps: editedSteps)
        XCTAssertEqual(plantCase.careSteps[0].actionTitle, "Wipe the spotted leaf and keep it dry")
        XCTAssertTrue(plantCase.careSteps[1].isSkipped)
        XCTAssertTrue(LocalTriageEngine.confidenceCopy(for: draft).contains("not a professional diagnosis"))
    }

    func testPremiumBoundaryUsesLiteralIAPBlockerUntilProductsExist() {
        let boundary = PremiumStoreKitBoundary()

        XCTAssertEqual(boundary.productIds, ["leafclinic.premium.monthly", "leafclinic.premium.yearly"])
        XCTAssertEqual(boundary.blocker, "app_store_connect_iap_evidence_missing")
        XCTAssertTrue(boundary.unavailableFallbackCopy.contains("StoreKit products are not configured"))
    }

    private func temporaryPersistence() throws -> FileLeafClinicPersistence {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LeafClinicTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileLeafClinicPersistence(fileURL: directory.appendingPathComponent("archive.json"))
    }
}
