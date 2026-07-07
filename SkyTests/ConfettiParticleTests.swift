// ConfettiParticleTests.swift
// Verifies the deterministic confetti model behind SkyConfettiBurst
// (S-VER-06 / S-CEL-02): reproducible bursts, parameter bounds, and the
// position/opacity envelopes.

import XCTest
@testable import Sky

final class ConfettiParticleTests: XCTestCase {

    func testBurstIsDeterministicForSameSeed() {
        let a = ConfettiParticle.burst(count: 28, seed: 42)
        let b = ConfettiParticle.burst(count: 28, seed: 42)
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedsProduceDifferentBursts() {
        let a = ConfettiParticle.burst(count: 28, seed: 1)
        let b = ConfettiParticle.burst(count: 28, seed: 2)
        XCTAssertNotEqual(a, b)
    }

    func testBurstParameterBounds() {
        let burst = ConfettiParticle.burst(count: 50, seed: 7)
        XCTAssertEqual(burst.count, 50)
        for p in burst {
            XCTAssertTrue((0...1).contains(p.start.x), "spawn x out of unit range")
            XCTAssertTrue((-0.05...0.15).contains(p.start.y), "spawn y outside top band")
            XCTAssertTrue((0.05...0.15).contains(p.velocity.dy), "fall speed not gentle")
            XCTAssertTrue((4...8).contains(p.size), "size outside prototype dot range")
            XCTAssertTrue((0...0.4).contains(p.delay), "stagger delay out of range")
            XCTAssertTrue((2.0...3.0).contains(p.lifetime), "lifetime out of range")
            XCTAssertTrue((0..<4).contains(p.colorIndex), "color index outside 4-token palette")
        }
        XCTAssertTrue(burst.contains { $0.isRect }, "expected some spinning rects")
        XCTAssertTrue(burst.contains { !$0.isRect }, "expected mostly circles")
    }

    func testParticleHiddenBeforeDelayAndAfterLifetime() {
        let p = ConfettiParticle.burst(count: 1, seed: 3)[0]
        XCTAssertNil(p.unitPosition(at: p.delay - 0.01))
        XCTAssertEqual(p.opacity(at: p.delay - 0.01), 0)
        XCTAssertNil(p.unitPosition(at: p.delay + p.lifetime + 0.01))
        XCTAssertEqual(p.opacity(at: p.delay + p.lifetime + 0.01), 0)
    }

    func testParticleFallsMonotonically() {
        let p = ConfettiParticle.burst(count: 1, seed: 9)[0]
        var lastY = -Double.infinity
        for step in 0...20 {
            let t = p.delay + p.lifetime * Double(step) / 20
            guard let pos = p.unitPosition(at: t) else { continue }
            XCTAssertGreaterThanOrEqual(Double(pos.y), lastY,
                                        "confetti must never fall upward")
            lastY = pos.y
        }
    }

    func testOpacityEnvelope() {
        let p = ConfettiParticle.burst(count: 1, seed: 11)[0]
        // Holds the prototype base opacity mid-life…
        let mid = p.opacity(at: p.delay + p.lifetime / 2)
        XCTAssertEqual(mid, ConfettiParticle.baseOpacity, accuracy: 1e-9)
        // …never exceeds it…
        for step in 0...40 {
            let t = p.delay + p.lifetime * Double(step) / 40
            XCTAssertLessThanOrEqual(p.opacity(at: t), ConfettiParticle.baseOpacity + 1e-9)
        }
        // …and reaches zero exactly at end of life.
        XCTAssertEqual(p.opacity(at: p.delay + p.lifetime), 0, accuracy: 1e-9)
    }
}
