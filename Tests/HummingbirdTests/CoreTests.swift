import Testing
import Foundation
@testable import Hummingbird

@Suite("Core Registry Tests")
struct CoreTests {
    
    @Test("Basic Registration and Resolution")
    func registration() {
        let container = ServiceContainer()
        protocol MockService {}
        class MockServiceImpl: MockService {}
        
        container.register(MockService.self) { _ in MockServiceImpl() }
        let resolved = container.resolve(MockService.self)
        
        #expect(resolved is MockServiceImpl)
    }
    
    @Test("Manual Singleton Test")
    func manualSingleton() {
        let container = ServiceContainer()
        class Counter { var count = 0 }
        
        container.register(Counter.self, scope: .singleton) { _ in Counter() }
        
        let first = container.resolve(Counter.self)
        let second = container.resolve(Counter.self)
        
        #expect(first === second)
    }
    
    @Test("Singleton Scope Lifecycle")
    func singletonScope() {
        let container = ServiceContainer()
        class Counter { var count = 0 }
        
        container.register(Counter.self, scope: .singleton) { _ in Counter() }
        
        let first = container.resolve(Counter.self)
        let second = container.resolve(Counter.self)
        
        first.count += 1
        #expect(second.count == 1)
        #expect(first === second)
    }
    
    @Test("Transient Scope Lifecycle")
    func transientScope() {
        let container = ServiceContainer()
        class Counter { var count = 0 }
        
        container.register(Counter.self, scope: .transient) { _ in Counter() }
        
        let first = container.resolve(Counter.self)
        let second = container.resolve(Counter.self)
        
        first.count += 1
        #expect(first.count == 1)
        #expect(second.count == 0)
        #expect(first !== second)
    }
    
    @Test("Recursive Resolution Support")
    func recursion() {
        let container = ServiceContainer()
        protocol ServiceA {}
        protocol ServiceB {}
        class ServiceAImpl: ServiceA { init(b: ServiceB) {} }
        class ServiceBImpl: ServiceB {}
        
        container.register(ServiceB.self) { _ in ServiceBImpl() }
        container.register(ServiceA.self) { c in
            let b = c.resolve(ServiceB.self)
            return ServiceAImpl(b: b)
        }
        
        let a = container.resolve(ServiceA.self)
        #expect(a is ServiceAImpl)
    }
    
    @Test("Singleton Concurrency Test")
    func singletonConcurrency() async {
        let container = ServiceContainer()
        
        protocol ServiceA {}
        protocol ServiceB {}
        
        class ServiceAImpl: ServiceA { init() { Thread.sleep(forTimeInterval: 0.01) } }
        class ServiceBImpl: ServiceB { init() { Thread.sleep(forTimeInterval: 0.01) } }
        
        container.register(ServiceA.self, scope: .singleton) { _ in ServiceAImpl() }
        container.register(ServiceB.self, scope: .singleton) { _ in ServiceBImpl() }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = container.resolve(ServiceA.self) }
            group.addTask { _ = container.resolve(ServiceB.self) }
            group.addTask { _ = container.resolve(ServiceA.self) }
            group.addTask { _ = container.resolve(ServiceB.self) }
        }
        
        #expect(container.resolve(ServiceA.self) is ServiceAImpl)
        #expect(container.resolve(ServiceB.self) is ServiceBImpl)
    }

    @Test("Singleton Nil Caching")
    func singletonNilCaching() {
        let container = ServiceContainer()
        var count = 0
        
        container.register(String?.self, scope: .singleton) { _ in
            count += 1
            return nil
        }
        
        let first = container.resolve(String?.self)
        let second = container.resolve(String?.self)
        
        #expect(count == 1)
        #expect(first == nil)
        #expect(second == nil)
    }

    @Test("Manual Shared Registration")
    func manualShared() {
        let container = ServiceContainer()
        protocol MockService {}
        class MockServiceImpl: MockService {}
        
        container.register(MockService.self) { _ in MockServiceImpl() }
        
        // Before makeShared, shared container shouldn't have it
        // (Wait, shared might already have it if another test registered it, but ServiceContainer() is fresh)
        // Actually ServiceContainer.shared is a static constant, it persists across tests.
        // This is a bit problematic for isolation.
        
        container.makeShared()
        let resolved = ServiceContainer.shared.resolve(MockService.self)
        #expect(resolved is MockServiceImpl)
    }

    @Test("DependencyGraph makeShared")
    func macroMakeShared() {
        @DependencyGraph
        struct TestGraph {
            @Provider func provideString() -> String { "Shared" }
        }
        
        let graph = TestGraph()
        graph.makeShared()
        
        let resolved = ServiceContainer.shared.resolve(String.self)
        #expect(resolved == "Shared")
    }

    @Test("Thread Safety during Concurrent Access")
    func threadSafety() async {
        let container = ServiceContainer()
        
        actor SafeCounter {
            var count = 0
            func increment() { count += 1 }
        }
        
        let counter = SafeCounter()
        container.register(SafeCounter.self, scope: .singleton) { _ in counter }
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let c = container.resolve(SafeCounter.self)
                    await c.increment()
                }
            }
        }
        
        let finalCount = await counter.count
        #expect(finalCount == 100)
    }
}
