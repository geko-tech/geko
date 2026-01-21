---
title: Overview
order: 1
---

# Linux support

Geko has limited support on Linux. Since it's not possible to install Xcode on Linux, some Geko commands that use it on macOS cannot be run on Linux, and therefore these commands are not supported.

**List of supported commands on Linux:**
* fetch
* clean
* dump
* graph
* plugin
* version
* tree
* inspect

In the process of its operation, Geko uses the machine ID for logging, so it's necessary for at least one of the files to be present on the Linux machine in the following directories:
* /etc/machine-id
* /var/lib/dbus/machine-id
* /sys/class/dmi/id/product_uuid

Additionally, Geko requires the presence of the `SHELL` environment variable for executing pre- and post- shell scripts. 
`SHELL` variable and the machine ID are often missing in Docker containers.

Ruby and Bundler are also required if your project uses CocoaPods dependencies, as Geko utilizes `pod` during its operation.
On Linux, root privileges may be required to run CocoaPods, so you can set the environment variable `export COCOAPODS_ALLOW_ROOT=1` before using Geko.

## Build

For building on Linux, the Swift toolchain is required, and the easiest way to install it is using [Swiftly](https://www.swift.org/install/linux/).
The Swift version is specified in the .swift-version file located in the root of the project.

Other steps are:
* Run `swiftly install` in the root of the geko repository
* Run `swift build --product geko` to build geko executable binary

When attempting to run the application, it is likely to crash at runtime because the linker might not be able to find the necessary `.so` libraries.
To fix this, execute next command:


```bash 
export LD_LIBRARY_PATH="$(swift -print-target-info | jq -r '.paths.runtimeLibraryPaths[0]'):$LD_LIBRARY_PATH"
```
