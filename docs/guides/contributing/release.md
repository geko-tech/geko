---
title: Release
order: 2
---

# Releases

Geko uses a manual release system with version bumping based on the type of changes.

## Overview

Geko consists of several projects across multiple repositories:

- **Project Description** located in `project-description` defines the core interfaces
- **Geko** located in `geko` - CLI tool
- **Desktop** located in `geko` - is a companion application for interacting with the project via a UI.
- **GekoPlugins** located in `geko-plugins` - TBD

Each component has its own release cycle.

## How it works

### 1. Commit conventions

We use custom formats to structure our commit messages. This allows our tooling to determine version bumps, and generate appropriate changelogs.

- **Geko** Format: `Geko [patch/minor/major] description`
- **Desktop** Format: `Desktop [patch/minor/major] description`
- **Project Description** Format: `[patch/minor/major] description`
- **GekoPlugins** Format: TBD

#### Bump types and their impact

| Type | Description | Version Impact | Example |
|------|-------------|----------------|---------|
| `patch` | Backward-compatible changes | Patch version bump (x.y.Z) | `[patch] added tests` |
| `minor` | Backward-compatible new features | Minor version bump (x.Y.z) | `[minor] added new flag for generate command` |
| `major` | Incompatible API changes | Major version bump (X.y.z) | `[major] remove deprecated API` |

### 3. Release pipeline

When release pipeline started:

1. **Version calculation**: The pipeline determines the next version number from commit messages
2. **Changelog generation**: creates a changelog from commit messages
3. **Build process**: The utility(or plugin) is built and tested
4. **Release creation**: A GitHub release is created with artifacts

## Writing good commit messages

Since commit messages directly influence release notes, it's important to write clear, descriptive messages:

### Do:
- Use present tense: "add feature" not "added feature"
- Be concise but descriptive
- Include the scope when changes are component-specific
- Reference issues when applicable: `geko [patch] Fixed graph build-time (#1234)`

### Don't:
- Use vague messages like "fix bug" or "update code"
- Mix multiple unrelated changes in one commit
- Forget to include breaking change information

## Release workflows

The release workflows are defined in:
- **Geko** - `.github/workflows/release.yml`
- **Desktop** - `.github/workflows/release_desktop.yml`
- **Project Description** - `.github/workflows/release.yml`
- **GekoPlugins** - TBD

Each workflow:
- triggered manually
- Uses custom change detection
- Handles the entire release process

## Monitoring releases

You can monitor releases through:
- [Geko&Desktop Releases page](https://github.com/geko-tech/geko/releases)
- [ProjectDescription Releases page](https://github.com/geko-tech/project-description/releases)
- [GekoPlugins Releases page](https://github.com/geko-tech/geko-plugins/releases)
