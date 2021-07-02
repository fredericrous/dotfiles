# Dotfiles

personal environment files

## Requirement

Login to bitwarden. This is used for the files:

- `id_rsa`

```sh
brew install bitwarden-cli
bw config server <url>
bw login
export BW_SESSION="<session id>"
```

## Usage

Clone the repo with this [chezmoi](https://www.chezmoi.io/) command line:

```sh
chezmoi init https://git.daddyshome.fr/fredericrous/dotfiles.git
```

Apply dotfiles on the machine with

```sh
chezmoi apply -v
```

This command will apply the new changes from the repository and if the file on
the machine changed, it will ask if you want to overwrite it or skip it.
You can then merge the files with the command `chezmoi merge <file>`
and run the `apply` command again.

