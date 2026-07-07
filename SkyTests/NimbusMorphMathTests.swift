// NimbusMorphMathTests.swift
// Verifies the Nimbus state-morph interpolation (NimbusRendering.swift):
// endpoint fidelity (t = 0 / t = 1 reproduce the exact per-state models),
// crossfade-ramp behavior, and monotonic lerp.

import XCTest
@testable import Sky

final class NimbusMorphMathTests: XCTestCase {

    // MARK: - Endpoint fidelity

    func testLerpEndpointsReproduceStateModels() {
        for from in MascotState.allCases {
            for to in MascotState.allCases {
                let a = NimbusRenderModel.model(for: from)
                let b = NimbusRenderModel.model(for: to)
                XCTAssertEqual(NimbusRenderModel.lerp(a, b, 0), a,
                               "t=0 must equal the from-model (\(from) → \(to))")
                XCTAssertEqual(NimbusRenderModel.lerp(a, b, 1), b,
                               "t=1 must equal the to-model (\(from) → \(to))")
            }
        }
    }

    func testStateModelsMatchLegacyPalette() {
        // Spot-check the palette against the pre-morph NimbusConfig values.
        let fluffy = NimbusRenderModel.model(for: .fluffyWhite)
        XCTAssertEqual(fluffy.fill, NimbusRGBA(hex: "FFFFFF"))
        XCTAssertEqual(fluffy.shadow, NimbusRGBA(hex: "E8F0F5"))
        XCTAssertEqual(fluffy.cheekAlpha, 0.4)
        XCTAssertEqual(fluffy.expr, .happy)

        let rainy = NimbusRenderModel.model(for: .rainy)
        XCTAssertEqual(rainy.fill, NimbusRGBA(hex: "A8B5C2"))
        XCTAssertEqual(rainy.cheekAlpha, 0.3 * 0.6, accuracy: 1e-9)
        XCTAssertEqual(rainy.expr, .sad)
        XCTAssertEqual(rainy.rainOpacity, 1)
        XCTAssertEqual(rainy.sunOpacity, 0)

        let sunny = NimbusRenderModel.model(for: .sunny)
        XCTAssertEqual(sunny.sunOpacity, 1)
        XCTAssertEqual(sunny.highlightOpacity, 0.4)

        let grey = NimbusRenderModel.model(for: .cloudyGrey)
        XCTAssertEqual(grey.highlightOpacity, 0.15)
    }

    func testExpressionOverrideDrivesFaceGeometry() {
        // A sad override on a happy state must use the sad cheek layout + alpha.
        let overridden = NimbusRenderModel.model(for: .fluffyWhite, expressionOverride: .sad)
        XCTAssertEqual(overridden.expr, .sad)
        XCTAssertEqual(overridden.cheekAlpha, 0.4 * 0.6, accuracy: 1e-9)
        XCTAssertEqual(overridden.cheekLeft, CGPoint(x: 76, y: 86))
        XCTAssertEqual(overridden.highlightOpacity, 0.15)
    }

    // MARK: - Crossfade ramps

    func testCrossfadeRampEndpoints() {
        XCTAssertEqual(NimbusMorphMath.outgoingAlpha(0), 1)
        XCTAssertEqual(NimbusMorphMath.outgoingAlpha(0.45), 0)
        XCTAssertEqual(NimbusMorphMath.outgoingAlpha(1), 0)
        XCTAssertEqual(NimbusMorphMath.incomingAlpha(0), 0)
        XCTAssertEqual(NimbusMorphMath.incomingAlpha(0.55), 0)
        XCTAssertEqual(NimbusMorphMath.incomingAlpha(1), 1)
    }

    func testCrossfadeRampsNeverOverlap() {
        // At no point should outgoing + incoming ink both be visibly present
        // (the staggered windows [0, 0.45] and [0.55, 1] are disjoint).
        for step in 0...100 {
            let t = Double(step) / 100
            let out = NimbusMorphMath.outgoingAlpha(t)
            let inc = NimbusMorphMath.incomingAlpha(t)
            XCTAssertTrue(out == 0 || inc == 0,
                          "both ramps non-zero at t=\(t): out=\(out) in=\(inc)")
        }
    }

    func testCrossfadeRampsAreMonotonic() {
        var lastOut = 1.0
        var lastIn = 0.0
        for step in 0...100 {
            let t = Double(step) / 100
            let out = NimbusMorphMath.outgoingAlpha(t)
            let inc = NimbusMorphMath.incomingAlpha(t)
            XCTAssertLessThanOrEqual(out, lastOut + 1e-9, "outgoing not decreasing at t=\(t)")
            XCTAssertGreaterThanOrEqual(inc, lastIn - 1e-9, "incoming not increasing at t=\(t)")
            lastOut = out
            lastIn = inc
        }
    }

    // MARK: - Component lerps

    func testColorLerpMidpoint() {
        let black = NimbusRGBA(0, 0, 0)
        let white = NimbusRGBA(1, 1, 1)
        let mid = NimbusRGBA.lerp(black, white, 0.5)
        XCTAssertEqual(mid.r, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid.g, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid.b, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid.a, 1, accuracy: 1e-9)
    }

    func testQuadSpecLerpMidpoint() {
        let a = NimbusQuadSpec(a: .zero, b: CGPoint(x: 10, y: 0),
                               control: CGPoint(x: 5, y: -4), width: 2)
        let b = NimbusQuadSpec(a: CGPoint(x: 2, y: 2), b: CGPoint(x: 12, y: 2),
                               control: CGPoint(x: 7, y: 6), width: 3)
        let mid = NimbusQuadSpec.lerp(a, b, 0.5)
        XCTAssertEqual(mid.a, CGPoint(x: 1, y: 1))
        XCTAssertEqual(mid.b, CGPoint(x: 11, y: 1))
        XCTAssertEqual(mid.control, CGPoint(x: 6, y: 1))
        XCTAssertEqual(mid.width, 2.5)
    }

    func testEyeAndMouthSpecsPerExpression() {
        XCTAssertEqual(NimbusEyeSpec.spec(for: .happy), .circles)
        for expr in [NimbusExpression.neutral, .beaming, .sad] {
            guard case .arcs = NimbusEyeSpec.spec(for: expr) else {
                return XCTFail("\(expr) eyes should be arcs")
            }
        }
        XCTAssertEqual(NimbusMouthSpec.spec(for: .beaming), .beamingFill)
        guard case .stroked = NimbusMouthSpec.spec(for: .happy) else {
            return XCTFail("happy mouth should be stroked")
        }
    }
}
