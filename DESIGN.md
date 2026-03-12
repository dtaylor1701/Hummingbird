# Hummingbird Design Document

## 1. High-Level Architecture & System Design
Hummingbird is a lightweight, modular service management and dependency injection (DI) framework for Swift applications. It follows a **Service Locator** pattern variant combined with modern Swift features like **Property Wrappers** to provide a decoupled and type-safe architecture.

The system is organized into a single library target that manages the registration, resolution, and lifecycle of application services. By centralizing service resolution through a `ServiceProvider`, the architecture promotes high cohesion and low coupling between components.

## 2. Core Design Philosophies, Patterns, and Principles
- **Decoupling:** Components do not instantiate their dependencies directly; they request them from a central provider.
- **Type Safety:** Leverages Swift's `associatedtype` and Generics to ensure that service resolution is verified at compile-time wherever possible.
- **Modularity:** Services are defined by protocols, allowing for easy swapping of implementations (e.g., mocking for tests).
- **Inversion of Control (IoC):** The `ServiceProvider` manages the lifecycle of services, reducing the burden on individual components.
- **Protocol-Oriented Design:** The core of the system relies on the `Servicing` protocol to define standard behaviors across all managed components.

## 3. Technical Environment
- **Language:** Swift 5.6+
- **Build System:** Swift Package Manager (SPM)
- **Dependency Management:** Zero external dependencies to maintain a small footprint and minimize supply chain risks.
- **Platforms:** Supports macOS, iOS, tvOS, and watchOS (via standard Swift Package support).

## 4. Data Models & Relationships
The primary "models" in Hummingbird are the Service definitions.
- **Servicing Protocol:** The base contract for all services.
- **ServiceProvider:** A singleton or container instance that maintains a registry of service instances or factories.
- **Service Property Wrapper:** The bridge between the `ServiceProvider` and the consumer classes.

### Relationships:
- Consumers (Classes/Structs) **contain** `@Service` property wrappers.
- `@Service` wrappers **query** the `ServiceProvider`.
- `ServiceProvider` **manages** objects conforming to `Servicing`.

## 5. Key Components & Interactions
### 5.1 Servicing Protocol
The foundational protocol that all services must implement.
```swift
protocol Servicing {
    associatedtype Service
    func service(using provider: ServiceProvider) -> Service
}
```

### 5.2 ServiceProvider
The central registry responsible for:
- Registering service implementations.
- Resolving services based on type.
- Managing instance lifecycles (e.g., Singletons vs. Transients).

### 5.3 @Service Property Wrapper
Provides a syntactic sugar for dependency injection, allowing developers to declare dependencies inline without manual initialization logic.

### Interactions:
1. **Registration:** During application bootstrap, services are registered with the `ServiceProvider`.
2. **Injection:** When a class is instantiated, its `@Service` properties resolve their values from the provider.
3. **Execution:** The consumer calls methods on the resolved service interface.

## 6. Technical Specifications
### 6.1 Error Handling
- **Resolution Failures:** Since Swift property wrappers currently don't support throwing during initialization, resolution failures typically result in a runtime assertion or fatal error in debug mode to catch misconfigurations early.
- **Type Mismatches:** Handled via Swift's strong typing system at compile-time.

### 6.2 Concurrency Model
- The `ServiceProvider` is designed to be thread-safe, utilizing internal synchronization (such as dispatch queues or locks) to ensure that service resolution is safe across multiple threads.

### 6.3 State Management
- Services can be registered as **Singletons** (one instance shared globally) or **Transients** (a new instance created for every resolution).

## 7. Testing Infrastructure & Strategy
### 7.1 Unit Testing
- **Framework:** XCTest.
- **Mocking:** The protocol-based design allows for easy creation of mock services.
- **Isolation:** Tests should use an isolated `ServiceProvider` instance to prevent state leakage between test cases.

### 7.2 Integration Testing
- Verifying that multiple services can be registered and resolved correctly within a single container.
- Testing the lifecycle management (ensuring singletons are only instantiated once).

## 8. Security, Scalability, and Performance
### 8.1 Security
- **Access Control:** Core components use `public` and `open` modifiers strictly where needed to prevent unauthorized modification of the service registry.

### 8.2 Scalability
- The flat registry structure ensures that lookups remain fast ($O(1)$ on average using hash maps) even as the number of services grows.

### 8.3 Performance
- **Lazy Initialization:** Services are typically instantiated only when first requested, reducing application startup time.
- **Memory Footprint:** Minimal overhead due to the lack of external dependencies and optimized Swift generic implementation.
