import Testing
@testable import AsyncConveyor
import Foundation

enum TestError: Error {
    case invalid(String)
}

@Suite("ConveyorStateMachine", .serialized)
struct StateMachineTests {
    @Test func testInitialResumeFromIdle() async throws {
        var stateMachine = ConveyorStateMachine()
        let id: UInt64 = 1
        
        let cont = fakeContinuation()
        let action = stateMachine.sendSuspend(id: id, continuation: cont)
        
        switch action {
        case .resume(let removedid, _):
            #expect(removedid == id)
        default:
            throw TestError.invalid("Expected resume from idle")
        }
    }
    
    @Test func testSecondSuspendGetsSuspended() async throws {
        var sm = ConveyorStateMachine()
        let cont1 = fakeContinuation()
        let cont2 = fakeContinuation()
        
        _ = sm.sendSuspend(id: 1, continuation: cont1)
        let action2 = sm.sendSuspend(id: 2, continuation: cont2)
        
        switch action2 {
        case .suspend:
            break
        default:
            throw TestError.invalid("Second suspend should not resume immediately")
        }
    }
    
    @Test func testFinishWakeNextTask() async throws {
        var sm = ConveyorStateMachine()
        let cont1 = fakeContinuation()
        let cont2 = fakeContinuation()
        
        _ = sm.sendSuspend(id: 1, continuation: cont1)
        _ = sm.sendSuspend(id: 2, continuation: cont2)
        
        let finishAction = sm.sendFinished(id: 1)
        switch finishAction {
        case .resume(let removeID, _):
            #expect(removeID == 2)
        default:
            throw TestError.invalid("sendFinished should resume next waiting task")
        }
    }
    
    @Test func testCancelRunningPromotesNext() async throws {
        var sm = ConveyorStateMachine()
        let cont1 = fakeContinuation()
        let cont2 = fakeContinuation()
        
        _ = sm.sendSuspend(id: 1, continuation: cont1)
        _ = sm.sendSuspend(id: 2, continuation: cont2)
        
        let cancelAct = sm.sendCancelled(id: 1)
        switch cancelAct {
        case .resume(let removedid, _):
            #expect(removedid == 2)
        default:
            throw TestError.invalid("sendCancelled should resume next task when cancelling running")
        }
    }

    @Test func testCancelNonRunningDoesNothing() async throws {
        var sm = ConveyorStateMachine()
        let cont1 = fakeContinuation()
        let cont2 = fakeContinuation()
        
        _ = sm.sendSuspend(id: 1, continuation: cont1)
        _ = sm.sendSuspend(id: 2, continuation: cont2)
        
        let cancelAct = sm.sendCancelled(id: 2)
        switch cancelAct {
        case .none:
            break
        default:
            throw TestError.invalid("Cancelling non-running task should not invoke resume")
        }
    }
    
    // MARK: - Helpers
    private func fakeContinuation() -> CheckedContinuation<Void, Never> {
        var continuation: CheckedContinuation<Void, Never>!
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                continuation = c
                semaphore.signal()
            }
        }
        semaphore.wait()
        return continuation
    }
}
