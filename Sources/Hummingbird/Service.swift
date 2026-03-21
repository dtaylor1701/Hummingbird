import Foundation

/// A macro that automatically resolves a service from the container.
@attached(accessor)
public macro Service() = #externalMacro(module: "HummingbirdMacros", type: "ServiceMacro")
