# Autoupdate

When working on a large project it is often required to switch to different branches, such as older releases. Each branch can contain different environment which includes version of geko.

To help with such cases geko supports automatic switching to different version.

To setup autoupdate, add a `.geko-version` file to root of your project with desired version, for example:

```
1.0.0
```

## How it works

On launch geko compares version of self to version inside `.geko-version`. If versions differ, following procedure starts:

1. Check for installed versions inside `~/.geko/Versions/{geko-version}` directory. If it exists, switch to cached version.

2. Download required version based on `geko_source.json` file which is located inside geko bundle directory, e.g. `~/.geko/bin/geko_source.json` or `~/.geko/Versions/1.0.0/geko_source.json`. See section "Specifying source of geko for autoupdate" for more info.

3. If version exists, it is downloaded into `~/.geko/Versions/{geko-version}`, otherwise an error will be thrown.

4. Switch to downloaded version `~/.geko/Versions/{geko-version}`.

## Specifying source of geko for autoupdate

By default geko will download versions from github releases specified in prefilled `geko_source.json` for macos releases:

```json
{"url":"https://github.com/geko-tech/geko/releases/download/Geko@{version}/geko_macos.zip"}
```

and another file for linux releases:

```json
{"url":"https://github.com/geko-tech/geko/releases/download/Geko@{version}/geko_linux_{arch}.tgz"}
```

File contains an object with a single value `url` which is a url template containing following optional variables:

- `{version}` is replaced with a version specified in `.geko-version`
- `{platform}` is replaced with a platform on which geko is being launched. Possible values: `macos`, `linux`.
- `{arch}` is replaced with a machine architecture on which geko is being launched. Possible values: `arm64`, `arm`, `x86_64`, `i386`.

When necessary, `geko_source.json` can be updated to suite your environment or removed completely from geko bundle.
