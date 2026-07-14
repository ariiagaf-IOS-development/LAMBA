import XCTest
@testable import Lamba

@MainActor
final class VehiclePersonalityTests: XCTestCase {
    func testBMWUsesPremiumDramaProfilesByMileage() {
        XCTAssertEqual(
            VehiclePersonality.inferred(
                brand: "BMW",
                model: "X5",
                year: 2021,
                mileageKm: 80_000
            ),
            .capriciousStar
        )
        
        XCTAssertEqual(
            VehiclePersonality.inferred(
                brand: "BMW",
                model: "X5",
                year: 2017,
                mileageKm: 180_000
            ),
            .formerStar
        )
    }
    
    func testLadaUsesLocalCharacterProfilesByAgeAndMileage() {
        XCTAssertEqual(
            VehiclePersonality.inferred(
                brand: "Lada",
                model: "Granta",
                year: 2023,
                mileageKm: 15_000
            ),
            .boardBuddy
        )
        
        XCTAssertEqual(
            VehiclePersonality.inferred(
                brand: "Lada",
                model: "Niva",
                year: 2010,
                mileageKm: 210_000
            ),
            .oldGrumbler
        )
    }
    
    func testNewLowMileageVehicleUsesNewbieProfileBeforeBrandSpecificFallbacks() {
        XCTAssertEqual(
            VehiclePersonality.inferred(
                brand: "Toyota",
                model: "Corolla",
                year: 2026,
                mileageKm: 2_000
            ),
            .enthusiasticNewbie
        )
    }
}
