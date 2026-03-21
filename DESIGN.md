# Design Document: Hummingbird Dependency Injection Framework

## 1. Overview
Hummingbird is a lightweight, protocol-oriented Dependency Injection (DI) framework for Swift. It leverages Swift Macros to provide a type-safe, "Macro-First" interface that eliminates boilerplate while ensuring compile-time integrity.

## 2. Key Features
- **Macro-Generated Graphs**: Transform simple types into robust DI graphs with `@DependencyGraph`.
- **Flexible Scoping**: Support for `singleton` and `transient` lifecycles at the property and method level.
- **Zero-Boilerplate Registration**: Use `@Implemented(by:)` to bind protocols to implementations.
- **Context-Aware Resolution**: Seamlessly swap implementations for entire execution blocks using `TaskLocal`.
- **Value & Reference Types**: Full support for both `struct` and `class` based dependency graphs.
- **Thread-Safety & Cycle Detection**: Built-in protection against concurrent access and circular dependencies.

## 3. Core Architecture

### 3.1 `ServiceContainer`
The internal engine of Hummingbird. It is a thread-safe registry that manages:
- **Scopes**: `singleton` (reused instance) and `transient` (new instance per resolution).
- **Type Collisions**: Identifies services by their type. Only one provider/implementation can be registered per type within a single container (last one wins).

### 3.2 `@DependencyGraph` Macro
The primary entry point. When applied to a `struct` or `class`, it generates a private storage container and type-safe accessors.

### 3.3 `@Implemented(by:scope:)`
A property-level macro to specify a concrete implementation and its scope.
```swift
@Implemented(by: FirebaseAnalytics.self, scope: .singleton)
var analytics: AnalyticsService
```

### 3.4 `@Provider(scope:)`
A method-level macro for custom initialization with a specific scope.
```swift
@Provider(scope: .transient)
func provideNetwork() -> NetworkService { ... }
```

---

## 4. Swapping & Mocking Strategies
(See README.md for detailed examples)
- Protocol-Based Swapping
- Configurable Graphs
- Context-Aware Swapping (`graph.run { ... }`)
