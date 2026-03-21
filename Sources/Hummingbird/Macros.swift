import Foundation

/// A macro that turns a type into a dependency injection graph.
/// It generates a storage container, an initializer, and computed properties.
@attached(member, names: named(init), named(container), named(run), arbitrary)
public macro DependencyGraph() = #externalMacro(module: "HummingbirdMacros", type: "DependencyGraphMacro")

/// A marker macro for a provider method in a `@DependencyGraph`.
/// - Parameter scope: The lifecycle scope of the service. Defaults to `.singleton`.
@attached(peer)
public macro Provider(scope: ServiceScope = .singleton) = #externalMacro(module: "HummingbirdMacros", type: "ProviderMacro")

/// A macro used on a property in a `@DependencyGraph` to specify its implementation.
/// Usage: `@Implemented(by: MyService.self, scope: .transient) var service: ServiceProtocol`
/// - Parameters:
///   - by: The concrete type that implements the protocol.
///   - scope: The lifecycle scope of the service. Defaults to `.singleton`.
@attached(accessor)
public macro Implemented(by: Any.Type, scope: ServiceScope = .singleton) = #externalMacro(module: "HummingbirdMacros", type: "ImplementedMacro")
