---
title: Skills
order: 2
---

# Skills

Geko provides a set of Agent Skills that help coding agents work with Geko and follow recommended project workflows.

Skills contain reusable instructions and Geko-specific knowledge that can be installed into compatible coding agents. They help avoid repeating the same operational guidance in every prompt and provide a consistent way to teach agents how to work with Geko.

The skills are maintained in the [geko-tech/skills](https://github.com/geko-tech/skills) repository, which is the source of truth for the available skills and their documentation.

::: info
Geko Skills are still under active development.

The collection will be expanded with additional workflows and use cases over time. Refer to the skills repository for the current set of available skills.
:::

## Installation

Geko Skills can be installed using either the [Skills CLI](https://github.com/vercel-labs/skills) or [GitHub CLI](https://cli.github.com/manual/gh_skill).

Using the Skills CLI:

```bash
npx skills add geko-tech/skills
```

Using GitHub CLI:

```bash
gh skill install geko-tech/skills
```

Both installation methods use the skills directly from the Geko Skills repository.

## Installing a Specific Skill

To install only a specific skill, provide its name explicitly.

Using the Skills CLI:

```bash
npx skills add geko-tech/skills --skill <skill-name>
```

Using GitHub CLI:

```bash
gh skill install geko-tech/skills <skill-name>
```

## Pinning a Version

The Geko Skills repository is versioned using SemVer releases.

For reproducible environments, a specific release can be installed instead of tracking the latest version.

Using the Skills CLI:

```bash
npx skills add 'geko-tech/skills#<version>' --skill <skill-name>
```

Using GitHub CLI:

```bash
gh skill install geko-tech/skills <skill-name>@<version>
```
