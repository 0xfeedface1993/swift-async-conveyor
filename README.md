# 🚚 AsyncConveyor

[![SwiftPM Compatible](https://img.shields.io/badge/SwiftPM-Compatible-blue?logo=swift)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20visionOS-lightgrey)](#)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**A lightweight Swift concurrency utility to ensure closures are executed serially, one at a time.**

`AsyncConveyor` is a concurrency control primitive that guarantees only one async block runs at a time. When multiple tasks invoke `run(_:)`, they are **automatically queued** and **executed in FIFO order**. Ideal for controlling access to critical resources like databases, files, or network sessions.

---

## 🔧 Features

- 🔁 **Serial execution** of async closures  
- ✅ Supports structured concurrency and cancellation handling  
- 🧵 Lock-free internal implementation using `ManagedCriticalState`  
- 🧪 Well-suited for unit testing and task coordination scenarios  
- 🧍 No external dependencies except Swift standard concurrency APIs  

---

## 📦 Requirements

- Swift 5.9+
- Concurrency enabled (Swift Concurrency runtime)
- Supported Platforms:
  - iOS 13+
  - macOS 10.15+
  - watchOS 6+
  - tvOS 13+

---

## 🚀 Installation

Use [Swift Package Manager](https://swift.org/package-manager/):

```swift
.package(url: "https://github.com/your-org/AsyncConveyor.git", from: "1.0.0")
```

Then add "AsyncConveyor" to your target dependencies.

---

## 🧑‍💻 Usage

```swift
import AsyncConveyor

let conveyor = AsyncConveyor()

Task {
    try await conveyor.run {
        print("Task A starting")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print("Task A finished")
    }
}

Task {
    try await conveyor.run {
        print("Task B starting")
        try await Task.sleep(nanoseconds: 500_000_000)
        print("Task B finished")
    }
}
```

---

## ✅ Output

```shell
Task A starting
Task A finished
Task B starting
Task B finished
```

Note: Even though Task B starts earlier in wall time, it waits for Task A to complete before executing.

---

## 🛑 Cancellation Safety

If a task is cancelled while waiting or running, AsyncConveyor ensures:
	•	The task is properly removed from the internal queue
	•	The next task resumes correctly
	•	No memory leaks or deadlocks

---

## 🔒 Use Cases
	•	Serializing file reads/writes
	•	Managing access to a database or cache
	•	Enforcing order of operations in state machines
	•	Coordinating request pipelines
	•	Preventing overlapping animations or transitions

---

## 🧪 Testing Tips
	•	Each .run { } block is awaited and can be tested deterministically.
	•	Consider injecting AsyncConveyor as a dependency when testing logic that depends on ordering.

---

## 🧠 Design Philosophy

AsyncConveyor follows a minimal locking, actor-free design by using ManagedCriticalState to efficiently manage internal state. It behaves similarly to a serial DispatchQueue, but with native async/await and structured cancellation.

---

## 👷 Contributions

Contributions and feedback are welcome! Please open issues or PRs.

---

