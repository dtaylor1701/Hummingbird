import Testing
import Hummingbird

@Suite("Integration Tests")
struct IntegrationTests {
    
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
            // We need to resolve from the container to check state since @Service is a getter
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
}
