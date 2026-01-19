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
