---
title: Overview
order: 1
---

# Contributing to Geko

First off, thank you for considering contributing to Geko! It's people like you who make this tool better for everyone.

By participating in this project, you agree to abide by our [Code of Conduct](https://github.com/geko-tech/geko/blob/main/CODE_OF_CONDUCT.md).

---

### 🚀 How Can I Contribute?

#### Reporting Bugs
For issues we are using GitHub issues

You can create issue for each component:
- [Geko&Desktop issues page](https://github.com/geko-tech/geko/issues)
- [GekoPlugins issues page](https://github.com/geko-tech/geko-plugins/issues)


#### Pull Requests
For PR style details can be found in the [Editing](../contributing/release.md) section.

---

### 🛠 Development Setup

#### Geko

1. Clone the Geko repo: https://github.com/geko-tech/geko
2. Open the project (it is recommended to open it via terminal using the `xed .` command to ensure environment variables are loaded correctly).
3. Select the Geko target.
4. In the Scheme settings, under Options > Working Directory, set the path to the project you will be generating with Geko.

#### Debug

To debug, you can use your own projects or the ready-made fixtures located in the fixtures/ folder.

Fixtures are pre-configured demo projects in various setups used for debugging and testing.

To debug using a specific fixture, go to Scheme > Options > Working Directory and set the path to that fixture.

#### FAQ

1. __Q:__ How do I run commands from Xcode?

   __A:__ In the Scheme settings, under Arguments Passed On Launch, enter your startup arguments and run the project.

2. __Q:__  The run failed with an `invalid byte sequence in US-ASCII` error on launch

   __A:__ In the Scheme settings, go to Arguments > Environment Variables and add `LANG` with the value `en_US.UTF-8`.

#### Desktop

1. Clone Geko repo https://github.com/geko-tech/geko
2. Navigate to the geko/GekoDesktop folder.
3. Install xcodegen if needed `brew install xcodegen`
4. Run `xcodegen generate` in the project folder.
5. Open GekoDesktop.xcodeproj

##### ProjectDescription

1. Clone ProjectDescription repo https://github.com/geko-tech/project-description
2. Open the project (it is recommended to open it via terminal using the `xed .` command to ensure environment variables are loaded correctly).

##### GekoPlugins

TBD

---

### 💬 Questions?
Feel free to open an issue or join our Team.

