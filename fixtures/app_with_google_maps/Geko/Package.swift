// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "App",
    dependencies: [
        .package(url: "https://github.com/googlemaps/ios-maps-sdk", exact: "8.4.0"),
    ]
)