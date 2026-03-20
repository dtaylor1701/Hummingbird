/// A property wrapper that provides easy access to registered services by their type.
@propertyWrapper
public struct Service<T>: Sendable {
  private let provider: ServiceProvider
  
  public var wrappedValue: T {
    return provider.resolve(T.self)
  }
  
  public init(provider: ServiceProvider = .shared) {
    self.provider = provider
  }
}
