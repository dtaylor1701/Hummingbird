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
