import Foundation

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
  
  // MARK: - Type-based Registration
  
  /// Registers a service as a singleton using the service type itself as the key.
  public func registerSingleton<T>(_ instance: T, for serviceType: T.Type = T.self) {
    lock.lock()
    defer { lock.unlock() }
    let id = ObjectIdentifier(serviceType)
    let typeName = String(describing: serviceType)
    instances[id] = instance
    registrations[id] = Registration(typeName: typeName, factory: { _ in instance }, lifecycle: .singleton)
  }
  
  /// Registers a service as a singleton with a factory closure using the service type as the key.
  public func registerSingleton<T>(_ serviceType: T.Type = T.self, factory: @escaping (ServiceProvider) -> T) {
    lock.lock()
    defer { lock.unlock() }
    let id = ObjectIdentifier(serviceType)
    let typeName = String(describing: serviceType)
    registrations[id] = Registration(typeName: typeName, factory: factory, lifecycle: .singleton)
    instances.removeValue(forKey: id)
  }
  
  /// Registers a service as a transient instance with a factory closure using the service type as the key.
  public func registerTransient<T>(_ serviceType: T.Type = T.self, factory: @escaping (ServiceProvider) -> T) {
    lock.lock()
    defer { lock.unlock() }
    let id = ObjectIdentifier(serviceType)
    let typeName = String(describing: serviceType)
    registrations[id] = Registration(typeName: typeName, factory: factory, lifecycle: .transient)
    instances.removeValue(forKey: id)
  }
  
  /// Registers a service with a factory closure using the service type as the key (defaults to transient).
  public func register<T>(_ serviceType: T.Type = T.self, factory: @escaping (ServiceProvider) -> T) {
    registerTransient(serviceType, factory: factory)
  }
  
  /// Clears all registrations and instances. Useful for unit testing.
  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    registrations.removeAll()
    instances.removeAll()
  }
  
  // MARK: - Token-based Registration (Convenience for Servicing types)
  
  /// Registers a service as a singleton where the service is its own provider.
  public func registerSingleton<T: Servicing>(_ service: T) where T.Service == T {
    registerSingleton(service, for: T.self)
  }
  
  /// Registers a service as a singleton using its Servicing provider.
  public func registerSingleton<T: Servicing>(_ provider: T) {
    registerSingleton(provider.service(using: self), for: T.Service.self)
  }
  
  /// Registers a service as a singleton using a Servicing token.
  public func registerSingleton<T: Servicing>(_ token: T.Type, factory: @escaping (ServiceProvider) -> T.Service) {
    registerSingleton(T.Service.self, factory: factory)
  }
  
  // MARK: - Resolution
  
  /// Resolves a service of the given type.
  public func resolve<T>(_ serviceType: T.Type = T.self) -> T {
    let id = ObjectIdentifier(serviceType)
    
    lock.lock()
    
    // Check for already instantiated singleton
    if let instance = instances[id] as? T {
      lock.unlock()
      return instance
    }
    
    guard let registration = registrations[id] else {
      lock.unlock()
      fatalError("Hummingbird: Service type \(serviceType) not registered")
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
    
    guard let typedInstance = instance as? T else {
      lock.unlock()
      fatalError("Hummingbird: Factory for \(serviceType) returned incompatible type \(type(of: instance))")
    }
    
    if registration.lifecycle == .singleton {
      instances[id] = typedInstance
    }
    
    lock.unlock()
    return typedInstance
  }
}
