---
title: Build
order: 3
---

# Build

The `geko build` command builds all buildable schemes of the project in the current directory.

```bash
geko build
```

To build a specific scheme, pass its name, for example the scheme of the main application:

```bash
geko build MainApp
```

To build a specific module, for example `Framework1`, which was generated with the help of [automatic scheme generation](./schemes_generation.md):

```bash
geko build Framework1
```

## Choosing a destination

Specify a device with the `--device` flag:

```bash
geko build MainApp --device "iPhone 17 Pro"
```

Specify an operating system version with the `--os` flag:

```bash
geko build MainApp --os "26.5"
```

Specify a platform with the `--platform` flag:

```bash
geko build MainApp --platform "iOS"
```

Alternatively, you can pass a build destination directly to `xcodebuild` with the `-destination` flag:

```bash
geko build MainApp -- -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

## Other options

Build using the release configuration with the `--configuration` flag:

```bash
geko build MainApp --configuration Release
```

Clean the project before building:

```bash
geko build MainApp --clean
```

Specify a custom Derived Data path:

```bash
geko build MainApp -- -derivedDataPath /custom/path/DerivedData
```