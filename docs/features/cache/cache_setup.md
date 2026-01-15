# Setup 

## Local Cache 

Geko uses a profile-based approach to warming up your project. Profiles allow Geko to know which configurations and targets to warm up the cache with. By default, there are two profiles: `Debug` and `Release`, which build the cache for iOS and the ARM architecture. To start using the cache locally in its basic configuration, you don't need to do anything extra. To get started, you can use one of the following commands:

```bash
geko generate --cache # All cachable modules will be cached 
geko generate App Auth --cache # Cache with focus on module App and Auth. All other modules will be pruned or cached
geko generate App Auth --cache --profile MyCustomProfile # Geko will use MyCustomProfile to warmup the cache
```

### Profiles 

You can create multiple ``Cache/Profile`` so that Geko knows which configurations and targets to use for cache warmup. To do this, you need to define all the parameters required for your build in the `Config.swift` manifest.

```swift
let config = Config(
    cache: .cache(
        profiles: [
            .profile(
                name: "Default", // Custom profile name. You can override Default profile with the same name and don't need to specify it in the command line
                configuration: "Debug", // Configuration to use for cache warmup
                platforms: [
                    .iOS: .options(arch: .arm64, os: "26.0", device: "iPhone 11") // Platforms and options to use for cache warmup
                ],
                scripts: [
                    .script(name: "SwiftGen", envKeys: ["SRCROOT"]) // List of build phase scripts to run before hashing
                ],
                options: .options() // Additional options for cache warmup
            )
        ]
    )
)
```

> [!NOTE]
> Geko supports building caches for multiple platforms simultaneously. In this case, you'll use xcframeworks instead of frameworks. However, using multiple platforms can significantly impact warm-up time. Therefore, we recommend separating different platforms into different profiles.

## Remote Cache 

Geko makes it very easy to set up your own remote cache. To do this, you need to set up your own S3 server using AWS or use any other S3 API-compatible service.

TODO: Auth for download not ready now. 

Once you have configured your S3, you need to specify information about it in your `Config.swift` file with ``Config/cloud``.

```swift 
let confisg = Config(
    cloud: .cloud(
        bucket: "my-bucket-name",
        url: "my-url-to-s3"
    )
)
```

After this, Geko will start accessing your S3 server to download the pre-built modules when generating a project. If a module isn't found in S3, Geko will warm it up and save it only in the local cache.

To upload locally built modules to the remote cache, use the command:

```bash 
geko cache upload 
``` 

Before upload you should declare ENV variables to access your s3 storage:

```bash
export GEKO_CLOUD_ACCESS_KEY="your_access_key"
export GEKO_CLOUD_SECRET_KEY="your_secret_key"
```

After each `geko generate --cache` command, the `.geko/Cache/BuildCache/latest_build` file is created, which contains information about the last warmup of the local cache. Using this file, the `upload` command determines which modules need to be loaded into the remote cache. This file is overwritten after each warmup.
