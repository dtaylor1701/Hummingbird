import Testing
import Hummingbird

@Suite("Integration Tests", .serialized)
struct IntegrationTests {
    
    init() {
        ServiceContainer.shared.reset()
    }

    protocol Storage { func save(_ data: String) }
    class DiskStorage: Storage { var saved = ""; func save(_ data: String) { saved = "Disk: \(data)" } }
    class MockStorage: Storage { var saved = ""; func save(_ data: String) { saved = "Mock: \(data)" } }
    
    @DependencyGraph
    class LiveGraph {
        @Provider func provideStorage() -> Storage { DiskStorage() }
    }
    
    @DependencyGraph
    class TestGraph {
        @Provider func provideStorage() -> Storage { MockStorage() }
    }
    
    class FeatureViewModel {
        @Service var storage: Storage
        func performAction() { storage.save("action") }
    }
    
    @Test("Context Swapping via TaskLocal")
    func contextSwapping() async {
        let live = LiveGraph()
        let mock = TestGraph()
        let vm = FeatureViewModel()
        
        // 1. Run in Live Context
        live.run {
            vm.performAction()
            let storage = live.container.resolve(Storage.self) as! DiskStorage
            #expect(storage.saved == "Disk: action")
        }
        
        // 2. Run in Mock Context
        mock.run {
            vm.performAction()
            let storage = mock.container.resolve(Storage.self) as! MockStorage
            #expect(storage.saved == "Mock: action")
        }
    }

    @Test("Scoped Scoping overrides Shared")
    func scopedOverridesShared() {
        let live = LiveGraph() // Auto-registers with shared
        let mock = TestGraph() // Auto-registers with shared (wins)
        let vm = FeatureViewModel()
        
        // Default (shared) should be Mock because it was last initialized
        vm.performAction()
        let sharedStorage = ServiceContainer.shared.resolve(Storage.self) as! MockStorage
        #expect(sharedStorage.saved == "Mock: action")
        
        // But .run should still use Live
        live.run {
            vm.performAction()
            let scopedStorage = ServiceContainer.active?.resolve(Storage.self) as! DiskStorage
            #expect(scopedStorage.saved == "Disk: action")
        }
    }
}
