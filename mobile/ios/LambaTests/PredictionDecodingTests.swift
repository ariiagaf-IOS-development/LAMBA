import XCTest
@testable import Lamba

@MainActor
final class PredictionDecodingTests: XCTestCase {
    func testPredictionResponseDecodesPartialBackendPayload() throws {
        let json = """
        {
          "predictions": [
            {
              "remaining_km": 2400,
              "probability": 0.72,
              "source": "experimental_backend"
            }
          ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(PredictionResponse.self, from: json)
        let prediction = try XCTUnwrap(response.predictions.first)
        
        XCTAssertNil(response.vehicleId)
        XCTAssertLessThan(prediction.id, 0)
        XCTAssertEqual(prediction.partName, "Vehicle part")
        XCTAssertNil(prediction.riskLevel)
        XCTAssertEqual(prediction.remainingKm, 2400)
        XCTAssertEqual(prediction.source, .mock)
    }
    
    func testPredictionResponseDefaultsMissingPredictionsToEmptyArray() throws {
        let json = #"{"vehicle_id": 7}"#.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(PredictionResponse.self, from: json)
        
        XCTAssertEqual(response.vehicleId, 7)
        XCTAssertTrue(response.predictions.isEmpty)
    }
    
    func testVehiclePartDecodesWithoutBackendIdOrName() throws {
        let json = """
        {
          "vehicle_id": 12,
          "category": "brakes",
          "last_service_mileage_km": 98000
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let part = try decoder.decode(VehiclePart.self, from: json)
        
        XCTAssertLessThan(part.id, 0)
        XCTAssertEqual(part.vehicleId, 12)
        XCTAssertEqual(part.name, "Vehicle part")
        XCTAssertEqual(part.category, "brakes")
        XCTAssertEqual(part.lastServiceMileageKm, 98000)
    }
    
    func testRiskLevelAcceptsBackendStatusSynonyms() throws {
        let decoder = JSONDecoder()
        
        XCTAssertEqual(try decoder.decode(RiskLevel.self, from: #""healthy""#.data(using: .utf8)!), .low)
        XCTAssertEqual(try decoder.decode(RiskLevel.self, from: #""warning""#.data(using: .utf8)!), .medium)
        XCTAssertEqual(try decoder.decode(RiskLevel.self, from: #""critical""#.data(using: .utf8)!), .high)
    }
}
