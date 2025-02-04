# GlideSwiftSDK

## Introduction

`GlideSwiftSDK` is our SDK for integrating with our systems

## Installation

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code. To use GlideSwiftSDK with Swift Package Manger, add it to `dependencies` in your `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/franciscojrp/glide-swift-sdk", branch: "master")
]
```

## Usage

Firstly, import `GlideSwiftSDK`.

```swift
import GlideSwiftSDK
```

Second, configure the SDK, recommended in `didFinishLaunchingWithOptions` in `AppDelegare.swift`.

```swift
Glide.configure(clientId: <CLIENT_ID>)
```

Third, authenticate wherever you need.

```swift
Glide.instance.startVerification (state: <STATE>, phoneNumber: <PHONE_NUMBER>) { code, state in
}
```
