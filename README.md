# Rust Docker Container Images

[![Build Status](https://github.com/wodby/rust/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/rust/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/rust.svg)](https://hub.docker.com/r/wodby/rust)
[![Docker Stars](https://img.shields.io/docker/stars/wodby/rust.svg)](https://hub.docker.com/r/wodby/rust)

## Table of Contents

- [Docker Images](#docker-images)
    - [`-dev`](#-dev)
    - [`-dev-macos`](#-dev-macos)
    - [Supported architectures](#supported-architectures)
- [Environment Variables](#environment-variables)
- [Build arguments](#build-arguments)
- [Tools](#tools)
- [Changelog](#changelog)
- [Crond](#crond)
- [SSHD](#sshd)
- [Adding SSH key](#adding-ssh-key)
- [Complete Rust stack](#complete-rust-stack)
- [Orchestration Actions](#orchestration-actions)

## Docker Images

Use image revision tags such as `wodby/rust:1-rN` to select a Wodby image revision.
Major and minor tags use the repository release number, starting at `r0`. Full-version tags such as
`wodby/rust:1.99.1-r0` start at `r0` for each exact upstream version.
Every published versioned revision tag has a matching annotated Git tag pointing to its release commit.
Existing tags remain available after support for their major or minor version ends.
See [release tags](https://github.com/wodby/rust/tags) for available revisions and the [image revision policy](https://github.com/wodby/images#image-revisions) for upgrade guidance.
Previously published image tags remain available.

About images:

- All images are based on Alpine Linux
- Base image: [rust](https://github.com/rust-lang/docker-rust)
- [GitHub actions builds](https://github.com/wodby/rust/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/rust)

Supported tags and respective `Dockerfile` links:

- `1.99`, `1`, `latest` [_(Dockerfile)_]
- `1.99-dev`, `1-dev`, `dev` [_(Dockerfile)_]
- `1.99-dev-macos`, `1-dev-macos` [_(Dockerfile)_]

Rust keeps compatibility within the 1.x series, so the image follows the latest stable release: `1` moves to each new
minor release, while minor tags such as `1.99` stay on their release.

[_(Dockerfile)_]: https://github.com/wodby/rust/tree/master/Dockerfile

### `-dev`

Images with `-dev` tag have `sudo` allowed for all commands for the `wodby` user and include build dependencies for crates that link C libraries (PostgreSQL, MariaDB, SQLite) or build them with CMake.

### `-dev-macos`

Same as `-dev` but the default user/group `wodby` has uid/gid `501`/`20` to match the macOS default user/group ids.

### Supported architectures

All images are built for `linux/amd64` and `linux/arm64`.

## Environment Variables

| Variable                          | Default value                 |
|-----------------------------------|-------------------------------|
| `APP_ROOT`                        | `/usr/src/app`                |
| `FILES_DIR`                       | `/mnt/files`                  |
| `GIT_USER_EMAIL`                  | `wodby@example.com`           |
| `GIT_USER_NAME`                   | `wodby`                       |
| `CARGO_HOME`                      | `/home/wodby/.cargo`          |
| `RUSTUP_HOME`                     | `/usr/local/rustup`           |
| `SSH_DISABLE_STRICT_KEY_CHECKING` |                               |
| `SSH_PRIVATE_KEY`                 |                               |
| `SSHD_GATEWAY_PORTS`              | `no`                          |
| `SSHD_HOST_KEYS_DIR`              | `/etc/ssh`                    |
| `SSHD_LOG_LEVEL`                  | `INFO`                        |
| `SSHD_PASSWORD_AUTHENTICATION`    | `no`                          |
| `SSHD_PERMIT_USER_ENV`            | `no`                          |
| `SSHD_USE_DNS`                    | `yes`                         |

## Build arguments

| Argument         | Default value |
|------------------|---------------|
| `RUST_DEV`       |               |
| `WODBY_GROUP_ID` | `1000`        |
| `WODBY_USER_ID`  | `1000`        |

Change `WODBY_USER_ID` and `WODBY_GROUP_ID` mainly for local dev image variants. If either value matches an existing system user/group id, the existing user/group will be deleted before creating the `wodby` user.

## Tools

| Tool                       | all versions                            |
|----------------------------|-----------------------------------------|
| Rust toolchain and rustup  | bundled from the upstream `rust` image  |
| clippy, rustfmt            | rustup components of the same toolchain |
| OpenSSL headers, pkg-config | latest Alpine packages                 |
| make, git, jq              | latest Alpine packages                  |

The toolchain is the `*-unknown-linux-musl` target, which links binaries statically by default. A
`rust-toolchain.toml` in the project selects another toolchain; rustup downloads it on first use.

## Changelog

For changes in each image revision, see the [release notes](https://github.com/wodby/rust/releases).

## Crond

You can run Crond with this image by changing the command to `sudo -E crond -f -d 0` and mounting a crontab file to `./crontab:/etc/crontabs/wodby`. Example crontab file contents:

```
# min	hour	day	month	weekday	command
*/1	*	*	*	*	echo "test" > /mnt/files/cron
```

## SSHD

You can run SSHD with this image by changing the command to `sudo /usr/sbin/sshd -De` and mounting authorized public keys to `/home/wodby/.ssh/authorized_keys`.

## Adding SSH key

You can add a private SSH key to the container by mounting it to `/home/wodby/.ssh/id_rsa`.

## Complete Rust stack

See https://github.com/wodby/stack-rust

## Orchestration Actions

Usage:

```
make COMMAND [params ...]

commands:
    check-ready [host max_try wait_seconds delay_seconds]
    files-import source
    files-link public_dir
```

## Building with pinned base images

Build with the Makefile to use the base image digests in `base-images.mk`. Local
builds and CI resolve the same version and variant to the same multi-platform
image. A version without a pin fails before the build starts.

When adding a supported base version or variant, add its image index digest to
`base-images.mk`. For a custom build, override `BASE_IMAGE` with a complete
`repository:tag@sha256:...` reference.

### Development workspace contract

Development variants declare `com.wodby.workspace.contract=1`. Configuration-only
startup (`/docker-entrypoint.sh --configure-runtime`) does not rewrite developer
SSH/Git settings, initialize shared storage, or run application hooks. Normal
startup retains its existing behavior. `WODBY_WORKSPACE=1` selects the workspace
startup command. Login-shell tools remain available when the developer home is mounted.

`workspace-rust prepare` downloads the project's crates (`cargo fetch`) and compiles it once, so the first start only
builds what changed; an error in the application's own code doesn't fail preparation and is reported by start.
`workspace-rust start` compiles the checkout with `cargo build` and runs the binary, then watches the checkout: when a
file changes, it compiles again and restarts the application with the new build, without restarting the container. A
build that fails leaves the running build up and prints the compiler's errors. Files are polled every
`WORKSPACE_POLL_INTERVAL` milliseconds (1000 by default), because file events don't reach a shared volume. Git's own
files, `.wodby-workspace`, `target` and `node_modules` are not watched. `WORKSPACE_RUST_WATCH=0` turns watching off:
the application then replaces the script and a change needs a restart of the container.

The binary is the project's only binary target, or its `default-run` one. `WORKSPACE_RUST_BIN` selects another
binary and `WORKSPACE_RUST_PACKAGE` a workspace member; `WORKSPACE_RUST_COMMAND` overrides startup.
`HOST` and `PORT` default to `0.0.0.0` and `8080`, but the application must read them.
A committed `Cargo.lock` is used with `--locked`, so it is never rewritten: a missing or outdated entry fails the
build and must be fixed in the repository with `cargo update`. Without a lock file, Cargo creates one, as on any first
build.

Downloaded crates (`cargo`) and build artifacts (`target`) use `.wodby-workspace/` in the shared checkout, so
preparation's work reaches the application and a build recompiles only what changed. `workspace-rust` points
`CARGO_HOME` and `CARGO_TARGET_DIR` there, also for `WORKSPACE_RUST_COMMAND`; a `CARGO_HOME` set to anything but the
image default and a `CARGO_TARGET_DIR` set at all stay as set. Both count against the checkout's volume and can be
deleted at any time. The directory is excluded through `.git/info/exclude` without editing `.gitignore`.
A tracked directory or symlink at that reserved path is refused. The runner's private home is not required by
application pods. Build scripts (`build.rs`) remain application-owned and may modify files; review Git changes after
preparation.

CI checks labels for all image variants and runs configuration, developer-state,
reserved-path and runtime tests for development variants. Publish a new image
revision before enabling this contract in a consuming service.
