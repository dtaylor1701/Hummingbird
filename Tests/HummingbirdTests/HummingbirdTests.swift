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
    
    @Test func protocolImplementationSwapping() throws {
        let provider = ServiceProvider()
        
        protocol Storage: Sendable {
            func save(_ data: String)
        }
        
        struct MockStorage: Storage {
            func save(_ data: String) { print("Mock save: \(data)") }
        }
        
        struct RealStorage: Storage {
            func save(_ data: String) { print("Real save: \(data)") }
        }
        
        // Register mock
        provider.registerSingleton((any Storage).self) { _ in MockStorage() }
        let storage1 = provider.resolve((any Storage).self)
        #expect(storage1 is MockStorage)
        
        // Register real (overwrites)
        provider.registerSingleton((any Storage).self) { _ in RealStorage() }
        let storage2 = provider.resolve((any Storage).self)
        #expect(storage2 is RealStorage)
    }
    
    @Test func protocolsWithAssociatedTypes() throws {
        let provider = ServiceProvider()
        
        protocol PATRepository<T>: Sendable {
            associatedtype T
            func fetch() -> [T]
        }
        
        struct UserRepository: PATRepository {
            typealias T = String
            func fetch() -> [String] { ["User1", "User2"] }
        }
        
        provider.registerSingleton((any PATRepository<String>).self) { _ in
            UserRepository()
        }
        
        let resolved = provider.resolve((any PATRepository<String>).self)
        #expect(resolved.fetch() == ["User1", "User2"])
    }
}

// MARK: - Test Helpers

class MyService: Servicing, @unchecked Sendable {
    typealias Service = MyService
    func service(using provider: ServiceProvider) -> MyService {
        return self
    }
}

class ServiceConsumer {
    @Service var myService: MyService
    
    init(provider: ServiceProvider) {
        self._myService = Service(provider: provider)
    }
}

class Database: Servicing, @unchecked Sendable {
    typealias Service = Database
    func service(using provider: ServiceProvider) -> Database {
        return self
    }
}

class Repository: Servicing, @unchecked Sendable {
    typealias Service = Repository
    let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    func service(using provider: ServiceProvider) -> Repository {
        return self
    }
}
