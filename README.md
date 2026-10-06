# devcontainers

Prebuilt development container images and reusable [Dev Container Features](https://containers.dev/implementors/features/), one per language. Nothing here depends on a particular editor: the images are plain OCI images that also work with `docker run`, and any tool that speaks the [Dev Container spec](https://containers.dev) can use them.

## What's available

| Image `ghcr.io/kankava/devcontainer-images/…` | Built from                           | Contents                                              |
| --------------------------------------------- | ------------------------------------ | ----------------------------------------------------- |
| `base`                                        | [Dockerfile](images/base/Dockerfile) | Debian trixie, git, curl, sudo, user `dev` (UID 1000) |

Every image is built for amd64 and arm64 (Apple Silicon Macs, ARM Linux). Docker pulls the right one for the machine.

## Using an image

In a project, create `.devcontainer/devcontainer.json`:

```jsonc
{ "image": "ghcr.io/kankava/devcontainer-images/base:latest" }
```

Then open it with any of these:

- **Terminal editors (Neovim, Helix, Emacs)** with the [devcontainer CLI](https://github.com/devcontainers/cli) (`npm install -g @devcontainers/cli`):

  ```sh
  devcontainer up --workspace-folder . [--dotfiles-repository https://github.com/<you>/dotfiles]
  devcontainer exec --workspace-folder . bash
  ```

  The editor itself isn't in the images. Install it from your dotfiles' install script so your config comes with it.

- **Zed**: open the folder and accept the "Open in Dev Container" prompt.
- **VS Code**: "Dev Containers: Reopen in Container".
- **JetBrains IDEs**: "Remote Development → Dev Containers".
- **Plain Docker or Podman**, no devcontainer tooling needed:

  ```sh
  docker run --rm -it -v "$PWD":/workspaces/app -w /workspaces/app ghcr.io/kankava/devcontainer-images/base bash
  ```

To pick up a newer image, `docker pull` it and recreate the container (`devcontainer up --workspace-folder . --remove-existing-container`).

Tags decide which updates a project gets:

| Tag                           | Gets                                                                         |
| ----------------------------- | ---------------------------------------------------------------------------- |
| `latest`, `debian`            | every release                                                                |
| `1`, `1-trixie`               | new tools and fixes, but no breaking changes                                 |
| `1.0`, `1.0-trixie`           | fixes only                                                                   |
| `1.0.0`, `1.0.0-trixie`       | that version only                                                            |
| `trixie`, `debian13`          | every release on Debian 13 (moving to Debian 14 will be a new major version) |
| `20261006`, `trixie-20261006` | one exact build                                                              |

The current version's tags are rebuilt weekly with Debian's security updates. Tags the images have moved past stay as they were: an older version's (such as `1.0` once `1.1` is out), `trixie` and `debian13` once the images move to Debian 14, and every dated tag.

## Repository layout

```text
images/<image>/      devcontainer.json (+ Dockerfile for base) that an image is built from, and image.json with its version
scripts/build.sh     builds images (and pushes with --push)
```

## Building locally

```sh
scripts/build.sh                 # all images, base first
scripts/build.sh base            # specific images
```

Local builds are for the machine's own architecture.

Without a global CLI install, prefix with `DEVCONTAINER="npx -y @devcontainers/cli"`.

## Publishing

GitHub Actions does the publishing, but the scripts run anywhere, so another CI system or registry works too.

- **Images** (`.github/workflows/images.yml`): builds and pushes the images whose files or features changed, and all of them weekly (for security updates), with the tags from [Using an image](#using-an-image). Each architecture builds natively on its own runner (`ubuntu-latest`, `ubuntu-24.04-arm`) and is pushed as `build-<arch>`, then [build-image.yml](.github/workflows/build-image.yml) combines them into the published tags. The architectures per image are set in the workflow's `prepare` job.

Each image's version is in its `image.json`. Bump it when the image's folder or features change: patch for fixes, minor for new tools, major for breaking changes such as removing a tool or moving to a new Debian release. The workflow refuses to publish a changed image without a bump, and marks each published version with a git tag `image_<name>_<version>`.

GitHub's ARM runners are free for public repositories; a private one needs paid larger runners.

Packages published from a public repository like this one are public too, so pulling them needs no login.

## License

MIT, see [LICENSE](LICENSE). The software installed in the images and by the features keeps its own licenses.
