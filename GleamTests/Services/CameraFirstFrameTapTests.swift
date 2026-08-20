import Testing
@testable import Gleam

struct CameraFirstFrameTapTests {
    @Test func aFreshTapStaysSilentUntilAFrameArrives() async {
        let tap = CameraFirstFrameTap()
        let delivered = DeliveryFlag()
        let waiter = Task {
            for await _ in tap.frames {
                await delivered.mark()
                return
            }
        }

        await yieldRepeatedly()
        #expect(await delivered.isSet == false)

        tap.markFrameDelivered()
        await waiter.value
        #expect(await delivered.isSet)
    }

    @Test func aFrameThatLandedBeforeTheWaitStillSatisfiesIt() async {
        let tap = CameraFirstFrameTap()
        tap.markFrameDelivered()

        await confirmation { observed in
            for await _ in tap.frames {
                observed()
                return
            }
        }
    }

    @Test func aSecondSessionNeverSeesTheFirstSessionsFrame() async {
        let finished = CameraFirstFrameTap()
        finished.markFrameDelivered()

        let fresh = CameraFirstFrameTap()
        let delivered = DeliveryFlag()
        let waiter = Task {
            for await _ in fresh.frames {
                await delivered.mark()
                return
            }
        }

        await yieldRepeatedly()
        #expect(await delivered.isSet == false)

        waiter.cancel()
    }
}

private actor DeliveryFlag {
    private(set) var isSet = false

    func mark() {
        isSet = true
    }
}
