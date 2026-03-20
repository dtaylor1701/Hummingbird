/// The foundational protocol that all services must implement if they wish to provide themselves as a service.
public protocol Servicing {
  /// The type of the service being provided.
  associatedtype Service
  
  /// Creates the service using the provided `ServiceProvider`.
  /// - Parameter provider: The provider to use for resolving dependencies.
  /// - Returns: An instance of the service.
  func service(using provider: ServiceProvider) -> Service
}
