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
A convenient way to inject dependencies into your classes or structures. By using the `@Service` property wrapper, you can access registered services without manual boilerplate.

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

Define a service by conforming to the `Servicing` protocol. A service can be its own definition, or you can use a separate struct/enum as a "token" to resolve a protocol.

```swift
import Hummingbird

class MyService: Servicing {
    typealias Service = MyService
    
    func service(using provider: ServiceProvider) -> MyService {
        return self
    }
    
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

**Singleton (Lazy/Factory):**
```swift
ServiceProvider.shared.registerSingleton(MyService.self) { provider in
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
    @Service<MyService>
    var myService: MyService

    func doSomething() {
        myService.performTask()
    }
}
```

## Advanced Usage

### Protocol-Oriented Injection

Define a protocol and a service "token" that conforms to `Servicing`.

```swift
protocol Database {
    func save()
}

struct DatabaseService: Servicing {
    typealias Service = Database
    
    func service(using provider: ServiceProvider) -> Database {
        return RealDatabase()
    }
}

// Registration
ServiceProvider.shared.registerSingleton(DatabaseService.self) { provider in
    return RealDatabase()
}

// Injection
class MyRepo {
    @Service<DatabaseService>
    var db: Database
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
