import Testing
import Foundation
@testable import Hummingbird

@Suite("Hummingbird Tests")
struct HummingbirdTests {
    
    @Test func singletonResolution() throws {
        let provider = ServiceProvider()
        let service = MyService()
        provider.registerSingleton(service)
        
        let resolved1: MyService = provider.resolve(MyService.self)
        let resolved2: MyService = provider.resolve(MyService.self)
        
        #expect(resolved1 === service)
        #expect(resolved2 === service)
        #expect(resolved1 === resolved2)
    }
    
    @Test func singletonFactoryResolution() throws {
        let provider = ServiceProvider()
        var instantiationCount = 0
        
        provider.registerSingleton(MyService.self) { _ in
            instantiationCount += 1
            return MyService()
        }
        
        #expect(instantiationCount == 0)
        
        let resolved1 = provider.resolve(MyService.self)
        #expect(instantiationCount == 1)
        
        let resolved2 = provider.resolve(MyService.self)
        #expect(instantiationCount == 1)
        
        #expect(resolved1 === resolved2)
    }
    
    @Test func transientResolution() throws {
        let provider = ServiceProvider()
        var instantiationCount = 0
        
        provider.registerTransient(MyService.self) { _ in
            instantiationCount += 1
            return MyService()
        }
        
        let resolved1 = provider.resolve(MyService.self)
        #expect(instantiationCount == 1)
        
        let resolved2 = provider.resolve(MyService.self)
        #expect(instantiationCount == 2)
        
        #expect(resolved1 !== resolved2)
    }
    
    @Test func propertyWrapperInjection() throws {
        let provider = ServiceProvider()
        let service = MyService()
        provider.registerSingleton(service)
        
        let consumer = ServiceConsumer(provider: provider)
        #expect(consumer.myService === service)
    }
    
    @Test func nestedDependencies() throws {
        let provider = ServiceProvider()
        provider.registerSingleton(Database.self) { _ in Database() }
        provider.registerSingleton(Repository.self) { provider in
            let db = provider.resolve(Database.self)
            return Repository(db: db)
        }
        
        let repo = provider.resolve(Repository.self)
        let db = provider.resolve(Database.self)
        #expect(repo.db === db)
    }
}

// MARK: - Test Helpers

class MyService: Servicing {
    typealias Service = MyService
    func service(using provider: ServiceProvider) -> MyService {
        return self
    }
}

class ServiceConsumer {
    @Service<MyService>
    var myService: MyService
    
    init(provider: ServiceProvider) {
        self._myService = Service<MyService>(provider: provider)
    }
}

class Database: Servicing {
    typealias Service = Database
    func service(using provider: ServiceProvider) -> Database {
        return self
    }
}

class Repository: Servicing {
    typealias Service = Repository
    let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    func service(using provider: ServiceProvider) -> Repository {
        return self
    }
}
