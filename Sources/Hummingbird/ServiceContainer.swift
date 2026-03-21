import Foundation

/// The scope of a service, determining its lifecycle within the container.
public enum ServiceScope: Sendable {
    case transient
    case singleton
}

/// A thread-safe container for registering and resolving services.
public final class ServiceContainer: @unchecked Sendable {
    
    /// The default global shared container.
    public static let shared = ServiceContainer()
    
    /// A Task-local container that takes precedence over the shared container.
    @TaskLocal public static var active: ServiceContainer?
    
    private var registrations: [ObjectIdentifier: Registration] = [:]
    private let lock = NSRecursiveLock()
    private let singletonLock = NSRecursiveLock()
    
    private static let resolutionStackKey = "com.hummingbird.resolutionStack"
    
    public init() {}
    
    public func register<T>(_ type: T.Type, scope: ServiceScope = .singleton, factory: @escaping (ServiceContainer) -> T) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = ObjectIdentifier(type)
        // Note: Last registration for a type wins.
        registrations[id] = Registration(scope: scope, factory: factory)
    }

    /// Copies all registrations from this container to the shared container.
    public func makeShared() {
        ServiceContainer.shared.lock.lock()
        self.lock.lock()
        defer {
            self.lock.unlock()
            ServiceContainer.shared.lock.unlock()
        }
        
        for (id, registration) in registrations {
            ServiceContainer.shared.registrations[id] = registration
        }
    }

    /// Clears all registrations and cached singleton instances from this container.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        registrations.removeAll()
    }
    
    public func resolve<T>(_ type: T.Type) -> T {
        let id = ObjectIdentifier(type)
        
        // --- Circular Dependency Detection ---
        var stack = (Thread.current.threadDictionary[ServiceContainer.resolutionStackKey] as? [ObjectIdentifier]) ?? []
        
        if stack.contains(id) {
            let cycleString = stack.map { String(describing: $0) }.joined(separator: " -> ")
            fatalError("Circular dependency detected: \(cycleString) -> \(id)")
        }
        
        stack.append(id)
        Thread.current.threadDictionary[ServiceContainer.resolutionStackKey] = stack
        
        defer {
            stack.removeLast()
            if stack.isEmpty {
                Thread.current.threadDictionary.removeObject(forKey: ServiceContainer.resolutionStackKey)
            } else {
                Thread.current.threadDictionary[ServiceContainer.resolutionStackKey] = stack
            }
        }
        // -------------------------------------
        
        lock.lock()
        let registration = registrations[id]
        lock.unlock()
        
        guard let registration = registration else {
            if self === ServiceContainer.shared {
                fatalError("Service '\(type)' is not registered in the shared container. This usually happens because no @DependencyGraph has been initialized.")
            } else {
                fatalError("Service '\(type)' is not registered in the current container.")
            }
        }
        
        if registration.scope == .singleton {
            singletonLock.lock()
            defer { singletonLock.unlock() }
            let instance = registration.resolve(within: self)
            return instance as! T
        } else {
            let instance = registration.resolve(within: self)
            return instance as! T
        }
    }
}

extension ServiceContainer {
    private final class Registration: @unchecked Sendable {
        let scope: ServiceScope
        let factory: (ServiceContainer) -> Any
        private var instance: Any?
        
        init(scope: ServiceScope, factory: @escaping (ServiceContainer) -> Any) {
            self.scope = scope
            self.factory = factory
        }
        
        func resolve(within container: ServiceContainer) -> Any {
            switch scope {
            case .transient:
                return factory(container)
            case .singleton:
                if let existing = instance {
                    return existing
                }
                
                let newInstance = factory(container)
                instance = newInstance
                return newInstance
            }
        }
    }
}
