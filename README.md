# Dotfiles

personal environment files

## Requirements

import your gpg keys

## Usage

Clone the repo with this [chezmoi](https://www.chezmoi.io/) command line:


```sh
sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply fredericrous
#OR: chezmoi init https://github.com/fredericrous/dotfiles.git
```

Apply dotfiles on the machine with

```sh
chezmoi apply -v
```

During the execution of `chezmoi apply`, you'll get prompted for passwords.
Without the passwords you should just remove the files that are
prefixed by `encrypted_` and `private_`.
Otherwise, have a look at section **Data Protection**.

## Updating dotfiles

To see the differences and resolve the conflict, use the commands:

```sh
chezmoi diff
chezmoi merge <file-from-diff>
```

When the files from the local changed and you just
want to override the repository, run:

```sh
chezmoi add <file>
```

It is the same command that is used to add new dotfiles to the repo.

When the files from the repository changed, run

```sh
chezmoi apply
```

`apply` will add the files that aren't present in the home folder.
It will asks for every file that has a diff if it should override it.
The command `chezmoi merge <file>` helps resolving conflicts before running `apply` again.

## Data Protection

### Files Located in a Pass Vault

Login to bitwarden. This is used for:

- `private_dot_ssh/private_id_rsa`

```sh
brew install bitwarden-cli
bw config server <url>
bw login
export BW_SESSION="<session id>"
```

### Encrypted Files

To decrypt, import the key with

```sh
gpg --import key
```

## Similar repos

- https://github.com/neersighted/dotfiles
- https://github.com/twpayne/dotfiles
- https://github.com/alrra/dotfiles
- https://github.com/mathiasbynens/dotfiles

