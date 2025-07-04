import Foundation
import OrderedCollections
import AsyncAlgorithms

struct ConveyorStateMachine: Sendable {
    private enum WaiterState {
        case pendding
        case cancelled
    }
    
    private struct Waiter: Sendable, Hashable {
        let id: UInt64
        let continuation: CheckedContinuation<Void, Never>?
        
        static func placeHolder(id: UInt64) -> Waiter {
            Waiter(id: id, continuation: nil)
        }
        
        static func == (lhs: ConveyorStateMachine.Waiter, rhs: ConveyorStateMachine.Waiter) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    private enum State {
        case queue(running: Waiter, pendding: OrderedSet<Waiter>)
        case ready(OrderedSet<Waiter>)
        case idle
    }
    
    private var state = State.idle
    
    public init() {
        
    }
    
    enum SendSuspendedAction {
        case suspend
        case resume(removeID: UInt64, continuation: CheckedContinuation<Void, Never>?)
    }
    
    mutating func sendSuspend(id: UInt64, continuation: CheckedContinuation<Void, Never>) -> SendSuspendedAction {
        switch state {
        case .queue(let running, var pendding):
            if running == .placeHolder(id: id) {
                return .suspend
            }
            let waiter = Waiter(id: id, continuation: continuation)
            pendding.append(waiter)
            state = .queue(running: running, pendding: pendding)
            return .suspend
        case .ready(var pendding):
            let waiter = Waiter(id: id, continuation: continuation)
            pendding.append(waiter)
            let first = pendding.removeFirst()
            state = .queue(running: first, pendding: pendding)
            return .resume(removeID: id, continuation: continuation)
        case .idle:
            let waiter = Waiter(id: id, continuation: continuation)
            state = .queue(running: waiter, pendding: OrderedSet<Waiter>())
            return .resume(removeID: id, continuation: continuation)
        }
    }
    
    enum SendCancelledAction {
        case none
        case resume(removeID: UInt64, continuation: CheckedContinuation<Void, Never>?)
    }
    
    mutating func sendCancelled(id: UInt64) -> SendCancelledAction {
        switch state {
        case .queue(let running, var pendding):
            if running == .placeHolder(id: id) {
                let first = pendding.removeFirst()
                state = .queue(running: first, pendding: pendding)
                return .resume(removeID: first.id, continuation: first.continuation)
            }
            
            if let _ = pendding.remove(.placeHolder(id: id)) {
                state = .queue(running: running, pendding: pendding)
                return .none
            }
            
            return .none
        case .ready(var pendding):
            if let _ = pendding.remove(.placeHolder(id: id)) {
                if pendding.isEmpty {
                    state = .idle
                    return .none
                }
                
                let first = pendding.removeFirst()
                state = .queue(running: first, pendding: pendding)
                return .resume(removeID: first.id, continuation: first.continuation)
            }
            return .none
        case .idle:
            return .none
        }
    }
    
    enum SendFinishedAction {
        case none
        case resume(removeID: UInt64, continuation: CheckedContinuation<Void, Never>?)
    }
    
    mutating func sendFinished(id: UInt64) -> SendFinishedAction {
        switch state {
        case .queue(let running, var pendding):
            if running == .placeHolder(id: id) {
                if pendding.isEmpty {
                    state = .idle
                    return .none
                }
                let first = pendding.removeFirst()
                state = .queue(running: first, pendding: pendding)
                return .resume(removeID: first.id, continuation: first.continuation)
            }
            
            if let _ = pendding.remove(.placeHolder(id: id)) {
                state = .queue(running: running, pendding: pendding)
            }
            
            return .none
        case .ready(var pendding):
            let _ = pendding.remove(.placeHolder(id: id))
            if pendding.isEmpty {
                state = .idle
                return .none
            }
            
            let first = pendding.removeFirst()
            state = .queue(running: first, pendding: pendding)

            return .resume(removeID: first.id, continuation: first.continuation)
        case .idle:
            return .none
        }
    }
}
