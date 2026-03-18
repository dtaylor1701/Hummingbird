# Hummingbird

Hummingbird is a Swift library designed to provide a lightweight and modular architecture for service management and dependency injection.

## Overview

The core of Hummingbird revolves around the `Servicing` protocol and a centralized `ServiceProvider`, allowing for clean decoupling of components and easy service resolution through property wrappers.

## Components

### Servicing
The `Servicing` protocol defines a standard interface for any component that acts as a service. It utilizes an `associatedtype` to ensure type safety when resolving services through the provider.

### ServiceProvider
A central registry that manages the lifecycle and resolution of services within your application. It supports both **Singleton** (shared instance) and **Transient** (new instance per request) lifecycles.

### @Service Property Wrapper
A convenient way to inject dependencies into your classes or structures. By using the `@Service` property wrapper, you can access registered services directly by their type.

## Installation

### Swift Package Manager

To include Hummingbird in your project using Swift Package Manager, add it to the dependencies section of your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/Hummingbird", from: "1.0.0")
]
```

## Usage

### 1. Define a Service

You can define a service using a class, struct, or protocol.

```swift
import Hummingbird

protocol MyServicing: Sendable {
    func performTask()
}

class MyService: MyServicing {
    func performTask() {
        print("Task performed!")
    }
}
```

### 2. Register Your Service

You can register services as singletons or transients.

**Singleton (Pre-instantiated):**
```swift
ServiceProvider.shared.registerSingleton(MyService())
```

**Singleton (Protocol Mapping):**
```swift
ServiceProvider.shared.registerSingleton(MyService(), for: (any MyServicing).self)
```

**Singleton (Lazy/Factory):**
```swift
ServiceProvider.shared.registerSingleton(MyServicing.self) { provider in
    return MyService()
}
```

**Transient (New instance every time):**
```swift
ServiceProvider.shared.registerTransient(MyService.self) { provider in
    return MyService()
}
```

### 3. Inject and Use

Inject the service into your application code using the `@Service` property wrapper:

```swift
class MyController {
    @Service var myService: any MyServicing

    func doSomething() {
        myService.performTask()
    }
}
```

## Advanced Usage

### Protocols with Associated Types (PATs)

If you have a protocol with associated types, you can inject it directly using `@Service`.

```swift
protocol Repository<T> {
    associatedtype T
    func fetch() -> [T]
}

// Registration
ServiceProvider.shared.registerSingleton((any Repository<String>).self) { _ in
    UserRepository()
}

// Injection
class UserConsumer {
    @Service var repo: any Repository<String>
}
```

## Features

- **Thread-Safe**: `ServiceProvider` uses recursive locking to ensure safe access across threads.
- **Circular Dependency Detection**: Detects and reports circular dependencies at runtime with a clear error message.
- **Zero Dependencies**: Lightweight and fast compilation.

## Dependencies

- Swift 6.0+
- No external dependencies.

## License

This project is available under the MIT license. See the LICENSE file for more info.
