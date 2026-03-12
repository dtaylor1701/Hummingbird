import Foundation

/// The foundational protocol that all services must implement.
/// It defines the service type and how it is created.
public protocol Servicing {
    /// The type of the service being provided.
    associatedtype Service
    
    /// Creates the service using the provided `ServiceProvider`.
    /// - Parameter provider: The provider to use for resolving dependencies.
    /// - Returns: An instance of the service.
    func service(using provider: ServiceProvider) -> Service
}

/// A central registry that manages the lifecycle and resolution of services.
public final class ServiceProvider: @unchecked Sendable {
    /// The default shared instance of the service provider.
    public static let shared = ServiceProvider()
    
    private let lock = NSRecursiveLock()
    
    private enum Lifecycle {
        case singleton
        case transient
    }
    
    private struct Registration {
        let typeName: String
        let factory: (ServiceProvider) -> Any
        let lifecycle: Lifecycle
    }
    
    private var registrations: [ObjectIdentifier: Registration] = [:]
    private var instances: [ObjectIdentifier: Any] = [:]
    
    /// Thread-local storage key for circular dependency detection.
    private let resolutionStackKey = "com.hummingbird.resolutionStack"
    
    public init() {}
    
    /// Registers a service as a singleton with a pre-existing instance.
    public func registerSingleton<T: Servicing>(_ instance: T.Service, for serviceType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(T.self)
        let typeName = String(describing: T.self)
        instances[id] = instance
        registrations[id] = Registration(typeName: typeName, factory: { _ in instance }, lifecycle: .singleton)
    }
    
    /// Registers a service as a singleton where the service is its own provider.
    public func registerSingleton<T: Servicing>(_ service: T) where T.Service == T {
        registerSingleton(service, for: T.self)
    }
    
    /// Registers a service as a singleton with a factory closure.
    public func registerSingleton<T: Servicing>(_ serviceType: T.Type, factory: @escaping (ServiceProvider) -> T.Service) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(T.self)
        let typeName = String(describing: T.self)
        registrations[id] = Registration(typeName: typeName, factory: factory, lifecycle: .singleton)
        instances.removeValue(forKey: id) // Clear any previous instance
    }
    
    /// Registers a service as a transient instance with a factory closure.
    public func registerTransient<T: Servicing>(_ serviceType: T.Type, factory: @escaping (ServiceProvider) -> T.Service) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(T.self)
        let typeName = String(describing: T.self)
        registrations[id] = Registration(typeName: typeName, factory: factory, lifecycle: .transient)
        instances.removeValue(forKey: id)
    }
    
    /// Registers a service with a factory closure (defaults to transient).
    public func register<T: Servicing>(_ serviceType: T.Type, factory: @escaping (ServiceProvider) -> T.Service) {
        registerTransient(serviceType, factory: factory)
    }
    
    /// Resolves a service of the given type.
    public func resolve<T: Servicing>(_ serviceType: T.Type) -> T.Service {
        let id = ObjectIdentifier(T.self)
        
        lock.lock()
        
        // Check for already instantiated singleton
        if let instance = instances[id] as? T.Service {
            lock.unlock()
            return instance
        }
        
        guard let registration = registrations[id] else {
            lock.unlock()
            fatalError("Hummingbird: Service \(T.self) not registered")
        }
        
        // Circular dependency detection
        var stack = Thread.current.threadDictionary[resolutionStackKey] as? [ObjectIdentifier] ?? []
        if stack.contains(id) {
            lock.unlock()
            let path = stack.compactMap { registrations[$0]?.typeName }.joined(separator: " -> ")
            fatalError("Hummingbird: Circular dependency detected: \(path) -> \(registration.typeName)")
        }
        
        stack.append(id)
        Thread.current.threadDictionary[resolutionStackKey] = stack
        
        defer {
            stack.removeLast()
            if stack.isEmpty {
                Thread.current.threadDictionary.removeObject(forKey: resolutionStackKey)
            } else {
                Thread.current.threadDictionary[resolutionStackKey] = stack
            }
        }
        
        // Create the instance
        let instance = registration.factory(self)
        
        guard let typedInstance = instance as? T.Service else {
            lock.unlock()
            fatalError("Hummingbird: Factory for \(T.self) returned incompatible type \(type(of: instance))")
        }
        
        if registration.lifecycle == .singleton {
            instances[id] = typedInstance
        }
        
        lock.unlock()
        return typedInstance
    }
}

/// A property wrapper that provides easy access to registered services.
@propertyWrapper
public struct Service<T: Servicing> {
    private let provider: ServiceProvider
    
    public var wrappedValue: T.Service {
        return provider.resolve(T.self)
    }
    
    public init(provider: ServiceProvider = .shared) {
        self.provider = provider
    }
}
