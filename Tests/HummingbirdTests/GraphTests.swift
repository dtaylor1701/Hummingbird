import Testing
import Hummingbird
import Foundation

@Suite("Dependency Graph Macro Tests")
struct GraphTests {
    
    // --- Mocking Setup ---
    protocol MessageService { func getMessage() -> String }
    class LiveMessageService: MessageService { func getMessage() -> String { "Live" } }
    class MockMessageService: MessageService { func getMessage() -> String { "Mock" } }
    
    // --- Strategy A: Subclassing ---
    @DependencyGraph
    class BaseGraph {
        @Provider func provideMessage() -> MessageService { LiveMessageService() }
    }
    
    class OverriddenGraph: BaseGraph {
        override func provideMessage() -> MessageService { MockMessageService() }
    }
    
    @Test("Strategy A: Graph Subclassing")
    func subclassing() {
        let live = BaseGraph()
        let mock = OverriddenGraph()
        
        #expect(live.message.getMessage() == "Live")
        #expect(mock.message.getMessage() == "Mock")
    }
    
    // --- Strategy B: Protocols ---
    protocol GraphInterface { var message: MessageService { get } }
    
    @DependencyGraph
    struct LiveStructGraph: GraphInterface {
        @Provider func provideMessage() -> MessageService { LiveMessageService() }
    }
    
    @DependencyGraph
    struct MockStructGraph: GraphInterface {
        @Provider func provideMessage() -> MessageService { MockMessageService() }
    }
    
    @Test("Strategy B: Protocol-based Graphs")
    func protocols() {
        let live: GraphInterface = LiveStructGraph()
        let mock: GraphInterface = MockStructGraph()
        
        #expect(live.message.getMessage() == "Live")
        #expect(mock.message.getMessage() == "Mock")
    }
    
    // --- Strategy C: Configurable ---
    @DependencyGraph
    struct ConfigurableGraph {
        let useMock: Bool
        @Provider func provideMessage() -> MessageService {
            useMock ? MockMessageService() : LiveMessageService()
        }
    }
    
    @Test("Strategy C: Configurable Graphs")
    func configurable() {
        let live = ConfigurableGraph(useMock: false)
        let mock = ConfigurableGraph(useMock: true)
        
        #expect(live.message.getMessage() == "Live")
        #expect(mock.message.getMessage() == "Mock")
    }
    
    // --- Strategy D: @Implemented ---
    @DependencyGraph
    class AutoGraph {
        @Implemented(by: LiveMessageService.self)
        var message: MessageService
    }
    
    @Test("Strategy D: @Implemented Attribute")
    func implemented() {
        let graph = AutoGraph()
        #expect(graph.message is LiveMessageService)
    }
}

// Separate types to avoid container collisions
class SingletonCounter {
    nonisolated(unsafe) static var count = 0
    init() { Self.count += 1 }
}

class TransientCounter {
    nonisolated(unsafe) static var count = 0
    init() { Self.count += 1 }
}

@DependencyGraph
class ScopingGraph {
    @Provider(scope: .singleton) func provideSingleton() -> SingletonCounter { SingletonCounter() }
    @Provider(scope: .transient) func provideTransient() -> TransientCounter { TransientCounter() }
}

@Suite("Scoping Verification")
struct ScopingTests {
    @Test("Singleton vs Transient Scopes")
    func verification() {
        SingletonCounter.count = 0
        TransientCounter.count = 0
        let graph = ScopingGraph()
        
        // Singleton check
        let s1 = graph.singleton
        let s2 = graph.singleton
        #expect(s1 === s2)
        #expect(SingletonCounter.count == 1)
        
        // Transient check
        let t1 = graph.transient
        let t2 = graph.transient
        #expect(t1 !== t2)
        #expect(TransientCounter.count == 2)
    }
}
