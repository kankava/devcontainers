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

| Tag                     | Gets                                                                         |
| ----------------------- | ---------------------------------------------------------------------------- |
| `latest`, `debian`      | every release                                                                |
| `1`, `1-trixie`         | new tools, fixes and security updates, but no breaking changes               |
| `1.0`, `1.0-trixie`     | fixes and security updates only                                              |
| `1.0.0`, `1.0.0-trixie` | one build, which never changes                                               |
| `trixie`, `debian13`    | every release on Debian 13 (moving to Debian 14 will be a new major version) |

Each version is built and published once. Debian's security updates come as new patch versions (`1.0.1`, `1.0.2`, …). Tags the images have moved past stay as they were: an older version's (such as `1.0` once `1.1` is out), and `trixie` and `debian13` once the images move to Debian 14. The [releases](https://github.com/kankava/devcontainers/releases) list what changed in each version.

## Repository layout

```text
images/<image>/      devcontainer.json (+ Dockerfile for base) that an image is built from, image.json with its version, and an optional test.sh
scripts/build.sh     builds images (and pushes with --push)
scripts/test.sh      tests built images
scripts/bump.sh      bumps versions for a release
scripts/inputs.sh    lists the files an image is built from, for the version checks
```

## Building locally

```sh
scripts/build.sh                 # all images, base first
scripts/build.sh base            # specific images
scripts/test.sh base             # test built images
```

Local builds are for the machine's own architecture, tagged `latest` and with the image's version.

Without a global CLI install, prefix with `DEVCONTAINER="npx -y @devcontainers/cli"`.

## Publishing

GitHub Actions does the publishing, but the scripts run anywhere, so another CI system or registry works too.

- **Images** (`.github/workflows/images.yml`): on a push to `main`, publishes every image whose version in `image.json` isn't published yet, with the tags from [Using an image](#using-an-image). Each architecture builds natively on its own runner (`ubuntu-latest`, `ubuntu-24.04-arm`), where the image's tests run before it's pushed as `build-<arch>`. Then [build-image.yml](.github/workflows/build-image.yml) combines the architectures into the published tags and creates a GitHub release, tagged `image_<name>_<version>` in git, with the commits since the previous version. The architectures per image are set in the workflow's `prepare` job. Running the workflow by hand publishes whatever a failed run left unpublished.

GitHub's ARM runners are free for public repositories; a private one needs paid larger runners.

Packages published from a public repository like this one are public too, so pulling them needs no login.

## Releasing

A release is a commit that bumps versions: CI then publishes every image with a new version. Nothing is released on its own, so Debian's security updates need a release every few weeks.

`scripts/bump.sh` bumps a version together with everything built from it. Run `git fetch` first, so it sees the latest releases.

```sh
scripts/bump.sh image base patch     # Debian's security updates: every image gets a new patch version
scripts/bump.sh image base minor     # a change to base, which every image builds on
scripts/bump.sh image <name> patch   # a change to one image's devcontainer.json
```

| Level | When                                                  | Examples                                                           |
| ----- | ----------------------------------------------------- | ------------------------------------------------------------------ |
| patch | nothing added or removed: fixes and updates           | Debian's security updates, a fix in an install script              |
| minor | something added, and projects keep working            | a new package in base, a new feature option                        |
| major | something removed or changed, so projects might break | moving to a new Debian release, removing a tool, renaming the user |

Each version moves one level up from its last published one, and only once however often the script runs. The other images build on an exact version of base (`base:1.0.0` in their `devcontainer.json`), so bumping base moves them to its new version and bumps them too.

CI refuses to publish when an image's files (its folder, its features or base) changed since its published version without a bump, when an image builds on a base version other than base's current one, or when a version goes down.

## License

MIT, see [LICENSE](LICENSE). The software installed in the images and by the features keeps its own licenses.
