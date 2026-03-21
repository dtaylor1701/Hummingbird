# Hummingbird 🐦

A lightweight, protocol-oriented Dependency Injection (DI) framework for Swift, powered by modern Swift Macros.

## Key Features

- **Flexible Scoping**: Specify `singleton` or `transient` lifecycles at the source.
- **Macro-First API**: Automated graph generation using `@DependencyGraph`.
- **Zero-Boilerplate**: Bind implementations to protocols directly on properties with `@Implemented(by:)`.
- **Compile-Time Safety**: Verifies that your dependencies are correctly registered.
- **Context-Aware Swapping**: Easily swap implementations for testing using `graph.run { ... }`.
- **Modern Swift**: Fully compatible with Swift 6 Concurrency and Swift Testing.

## Quick Start

### 1. Create your Dependency Graph
Apply `@DependencyGraph` to a struct or class. Use `scope` to control instance lifecycles.

```swift
@DependencyGraph
struct AppGraph {
    // Singleton by default
    @Implemented(by: FirebaseAnalytics.self)
    var analytics: AnalyticsService
    
    // Explicitly transient (new instance every time)
    @Implemented(by: NetworkServiceImpl.self, scope: .transient)
    var network: NetworkService
    
    // Custom provider with scope
    @Provider(scope: .singleton)
    func provideDatabase() -> Database {
        return SQLiteDatabase(path: "path/to/db")
    }
}
```

### 2. Resolve Dependencies
```swift
class MainViewModel {
    @Service var analytics: AnalyticsService
    
    func onAppear() {
        analytics.log(event: "appeared")
    }
}
```

### 3. Initialize & Inject
To make your graph available to `@Service` properties, you have two options:

#### A. Global Registration
Call `makeShared()` during app initialization to register the graph's services as the global default. This is ideal for most applications.

```swift
@main
struct MyApp: App {
    let graph = AppGraph()
    
    init() {
        graph.makeShared()
    }
}
```

#### B. Context-Aware Injection
Use `graph.run { ... }` to provide a specific graph's services to an entire execution block. This is perfect for unit tests or swapping contexts (e.g., development vs. production).

```swift
func testLoginFlow() {
    let mockGraph = MockGraph()
    mockGraph.run {
        let vm = LoginViewModel()
        vm.login() // Uses services from mockGraph
    }
}
```

---

## Scopes

Hummingbird supports two scopes:
- **`.singleton` (Default)**: The service is instantiated once per graph and the same instance is returned for all subsequent resolutions.
- **`.transient`**: A new instance is created every time the service is resolved.

## Type Collisions
Hummingbird uses the **Type** as the lookup key. If you have multiple providers or `@Implemented` properties returning the same type, the last one registered will win.

## Requirements
- iOS 16.0+ / macOS 13.0+
- Swift 6.0+
- Xcode 16.0+

## License
MIT
