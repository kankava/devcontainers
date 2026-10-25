# base

Debian with the tools every other image needs and a non-root user, built from this folder's [Dockerfile](Dockerfile). All the other images are built on it, and it also works on its own for projects that add their languages as features. It's published as `ghcr.io/kankava/devcontainer-images/base`; the main README has its [tags](../../README.md#using-an-image) and [variants](../../README.md#variants).

## What's installed

| Package                     | For                                                           |
| --------------------------- | ------------------------------------------------------------- |
| git, openssh-client, gnupg  | version control, SSH remotes, signing commits with SSH or GPG |
| curl, wget, ca-certificates | downloads                                                     |
| unzip, xz-utils             | `.zip` and `.xz` archives (tar and gzip come with Debian)     |
| less                        | the pager, also git's                                         |
| vim                         | quick edits, and the editor git opens for commit messages     |
| procps                      | `ps`, `top`, `free`, `pgrep`, `watch`                         |
| python3                     | scripts, and tools written in Python                          |
| bash-completion             | tab completion for git and other commands                     |
| sudo                        | installing more with `sudo apt-get install`                   |

Each version is built once, with Debian's updates as of that day, also for the packages that come with Debian's image. Later updates come as new patch versions (see [Releasing](../../README.md#releasing)).

## The user

The container runs as `dev`, UID and GID 1000, with passwordless sudo, home `/home/dev` and bash. It starts in `/workspaces`, which belongs to `dev`. Both are set in the image itself, so plain `docker run` gets them too.

On Linux, the devcontainer CLI and VS Code change `dev`'s UID and GID to yours when they create the container, so the files it writes in the project belong to you. Plain `docker run` doesn't: there, new files in a mounted folder belong to UID 1000.

## Environment

| Variable | Value                                                                                    |
| -------- | ---------------------------------------------------------------------------------------- |
| `LANG`   | `C.UTF-8`, so programs read and write UTF-8 without any locales installed                |
| `PATH`   | starts with `~/.local/bin`, for tools you install for your user, e.g. from your dotfiles |

A login shell (`bash -l`) gets Debian's `PATH` from `/etc/profile` instead, and its `~/.profile` adds `~/.local/bin` only once the folder exists.

## Variants

There's one so far, `trixie`, built on `debian:trixie`. Another variant would be another tag of Debian's image, built from the same Dockerfile (see [Variants](../../README.md#variants)).

## Not included

- Compilers, `make` and language runtimes: they come with the language features.
- pip and `venv`: Debian's Python is there for scripts and tools, not for Python projects. `sudo apt-get install python3-venv` adds `venv`, with pip inside each virtual environment.
- Your own editor and its config: install them from your dotfiles.
- `man`: the man pages are there, but reading them needs `sudo apt-get install man-db`.
