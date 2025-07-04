import Foundation
import AsyncAlgorithms

public struct AsyncConveyor: Sendable, Equatable {
    private let stateMachine: ManagedCriticalState<ConveyorStateMachine>
    private let ids = ManagedCriticalState<UInt64>(0)
    
    public init() {
        self.stateMachine = ManagedCriticalState(ConveyorStateMachine())
    }
    
    private func generateId() -> UInt64 {
        self.ids.withCriticalRegion { ids in
            defer { ids &+= 1 }
            return ids
        }
    }
    
    public func run<T>(_ body: @Sendable @escaping () async throws -> T) async throws -> T {
        let newID = self.generateId()
        
        return try await withTaskCancellationHandler {
            // a suspension is needed
            await withCheckedContinuation({ continuation in
                let action = self.stateMachine.withCriticalRegion { stateMachine in
                    stateMachine.sendSuspend(id: newID, continuation: continuation)
                }
                
                switch action {
                case .suspend:
                    break
                case .resume(_, let nextContinuation):
                    nextContinuation?.resume()
                }
            })
            let completion: () -> () = {
                let action = self.stateMachine.withCriticalRegion { stateMachine in
                    stateMachine.sendFinished(id: newID)
                }
                switch action {
                case .none:
                    break
                case .resume(_, let continuation):
                    continuation?.resume()
                }
            }
            do {
                let value = try await body()
                completion()
                return value
            } catch {
                completion()
                throw error
            }
        } onCancel: {
            let action = self.stateMachine.withCriticalRegion { stateMachine in
                stateMachine.sendCancelled(id: newID)
            }
            
            switch action {
            case .none:
                break
            case .resume(_, let nextContinuation):
                nextContinuation?.resume()
            }
        }
    }
    
    public static func == (lhs: AsyncConveyor, rhs: AsyncConveyor) -> Bool {
        lhs.stateMachine.isEqual(to: rhs.stateMachine)
    }
}
