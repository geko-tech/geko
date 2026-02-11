---
title: Install Geko
order: 2
---

# Install Geko

## Manual

1. Download latest release and unarchive it into folder of your choosing, for example into `~/.local/bin`
2. Add that folder to `PATH` variable in config file of your shell.

Example for `zsh`

in `~/.zshrc`

```bash
export PATH=/Users/my.user/.local/bin:$PATH
```

## Via install.sh

1. Donwload install.sh file
2. Run `chmod +x install.sh`
3. Run `./install.sh` or pass exact release tag `./install.sh Geko@1.0.0`

Make sure you are using zsh or manually add the path to executable into your shell config file.

```bash
export PATH=/Users/my.user/.local/bin:$PATH
```

## Continuous Integration (CI)

### GitHub actions

There are several ways to install Geko on CI - using `mise` or manual installation.

#### Mise

Create a `mise.toml` file in the root of the project:

```yaml
[tools]
"github:geko-tech/geko" = { version = "1.0.0", version_prefix = "Geko@" }
```

An example of a job that uses Geko:

```yaml
name: Build

on:
  pull_request:
    branches:
      - main

permissions:
  contents: read

jobs:
  build:
    runs-on: macos-latest
    steps:
    - uses: jdx/mise-action@v2
    - name: Geko Version
      run: |
        geko version
```

#### Manual installation

Download the [release archive](https://github.com/geko-tech/geko/releases/) of the required version to any suitable location. Urls to release archives and commands for unpacking will differ depending on the operating system (`MacOS` or `Linux`).

##### MacOS

```yaml
name: Build

on:
  pull_request:
    branches:
      - main

permissions:
  contents: read

jobs:
  build:
    runs-on: macos-latest
    steps:
    - name: Install Geko
      run: |
        VERSION="1.0.0"
        URL="https://github.com/geko-tech/geko/releases/download/Geko@$VERSION/geko_macos.zip"
        curl -fsSL "$URL" -o "geko.zip"
        unzip -q "geko.zip" -d "geko"
        chmod +x "geko/geko"
    - name: Geko Version
      run: |
        ./geko/geko version
```

##### Linux

```yaml
name: Build

on:
  pull_request:
    branches:
      - main

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - name: Install Geko
      run: |
        VERSION="1.0.0"
        URL="https://github.com/geko-tech/geko/releases/download/Geko@$VERSION/geko_linux_x86_64.tgz"
        curl -fsSL "$URL" -o "geko.tgz"
        mkdir -p geko
        tar -xzf "geko.tgz" -C "geko"
        chmod +x "geko/geko"
    - name: Geko Version
      run: |
        ./geko/geko version
```
