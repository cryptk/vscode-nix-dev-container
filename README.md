# Nix Devcontainer for VSCode
A functional devcontainer setup for writing Nix in VSCode

## What
This is a functional devcontainer for developing Nix in VSCode from a system that does not have Nix on it.

It includes the following functionality:
- Nix IDE installed inside the container
- Nixd language server pre-installed in the container
- A VSCode settings file that has the bare minimum needed to get Nix IDE functional
  - Pre-configured to use nixfmt for code formatting, but alejandra is available in the container if you prefer it
  - Formatting on save is not enabled in the settings.json, so your global preferences should be respected there.  You can uncomment the line in .vscode/settings.json if you want it
- A wrapper script to run the nixd LSP that ensures that nix-daemon is running (nixd needs nix-daemon for code completion functionality)
- The container is the official nixos/nix container so you can open a VSCode Terminal and use all of your familiar nix-env, nix-shell, etc commands
  - NOTE: The container is NOT NixOS, it is a minimal container with Nix package management.  You can still use this to develop your NixOS configurations, but don't expect tooling like nixos-rebuild and such, it's a container, not a full operating system.

This repo is intentionally kept to an absolute miminum for a functional Nix devcontainer. This is a starting point for you to build your IDE that handles the hard work of figuring out how to get Nix IDE working in a devcontainer from a system that does not have Nix.

## Why
[Nix and NixOS](https://nixos.org/) are amazing projects if you have a specific requirement.  I run NixOS in my homelab, but my desktop runs Gentoo.  I wanted to be able to edit my Nix configuration files in VSCode, on my desktop, with full code-completion features.  This requires having the Nix store and several pieces of tooling available.  This sounds like a perfect job for a [devcontainer](https://containers.dev/).

## The Problem
NixOS is not [FHS](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) compliant.  It does not support dynamic linking of libraries in the ways that more mainstream distributions do. This means that binaries compiled with the assumption that those facilities work are almost certain to break when run on NixOS unaltered. 

Nixpkgs has [a couple](https://nixos.org/manual/nixpkgs/stable/#sec-fhs-environments) of [different](https://nixos.org/manual/nixpkgs/stable/#setup-hook-autopatchelfhook) ways to deal with this for things that are distributed through Nixpkgs, but when you use a devcontainer with VSCode, it copies it's own pre-compiled binaries into the container, and those binaries are not patched for NixOS.

And this is once you get past the initial check to see if the system even has a compatible version of glibc, which NixOS does, but vscode and devcontainers have no idea how to tell.

There are a few hurdles to overcome:

### The glibc compatability problem
VSCode runs a check very early in setting up the devcontainer to check that it has compatible versions of glibc and libstdc++.  These are not locatable using "normal means" in NixOS, so this check fails.

Luckily a developer at Microsoft added a [check for NixOS](https://github.com/microsoft/vscode/blob/97e317f161d8aa14057ad348bbc603a6823e4bf1/resources/server/bin/helpers/check-requirements-linux.sh#L34-L37) to skip all of this (thanks deepak1556!).

The nixos/nix container doesn't have /etc/os-release like NixOS does, but we have a couple of options, either place "ID=nixos" inside /etc/os-release, or use the other escape hatch by placing a file at `/tmp/vscode-skip-server-requirements-check`.  I opted for the former as it seemed more contextually correct.

### Patch node ourselves with patchelf
We can't just run patchelf on the node binary ourselves because by that time, the devcontainer has already failed and we would have an awkward dance of:

1) open in container
1) container fails
1) patch node binary
1) reconnect to container

This isn't a great user experience and it would be pretty annoying to have to remember to re-patch the node binary yourself any time the container gets rebuilt.

### Replace the node binary with one from nixpkgs
This has similar user experience issues.  It would require either setting up the ~/.vscode-server directory ourselves somehow (and this likely wouldn't work because devcontainers place a mount over that location anyway), or it would require a similar dance as before with the container initially failing, then replace the node binary, then re-connect to the container.

## The Fix
We need a way to have VSCode patch the node binary *itself*, after it copies the node binary into the container but before it runs code-server inside it.  And wouldn't you know it, that same developer at Microsoft added [functionality for this already!](https://github.com/microsoft/vscode/blob/97e317f161d8aa14057ad348bbc603a6823e4bf1/resources/server/bin/code-server-linux.sh#L12-L20) (They even referenced a NixOS bug report about the ordering of --set-rpath and --set-interpreter! Thanks again deepak1556, this literally wouldn't be possible without this functionality!).

Now we just need to put it all together, it comes down to setting a few environment variables:

- VSCODE_SERVER_CUSTOM_GLIBC_LINKER: This should point to the location of the [linker](https://en.wikipedia.org/wiki/Linker_(computing)) (ld-linux-x86-64.so.2)
- VSCODE_SERVER_CUSTOM_GLIBC_PATH: This should be set to the [rpath](https://en.wikipedia.org/wiki/Rpath)
- VSCODE_SERVER_PATCHELF_PATH: This needs to point to the path of the patchelf binary

We aren't quite out of the woods yet, the way that Nix works, the path to these will change if they are ever updated. The actual libraries and binaries in Nix are stored within the Nix Store and their filepath includes a hash of the package, so new package versions will get a new path in the store.

To work around that last issue, as part of the Dockerfile we query the path to those locations in the Nix store and create some symlinks to the current path to them so that we can reference those paths in ENV settings in the Dockerfile.

I would love to just set the environment variables directly to the path of those locations, but Dockerfiles don't support setting an ENV to the output of a command as far as I can tell.

## Room for improvement
Currently, this works, but there may be better ways to query the nix-store for those paths.  I thought about having Nix build the container itself, but then this would not be usable by people that need to build the container on a system that does not have Nix (like me!).

Improvements are welcome! Submit an issue or a PR with any suggestions, but the scope of this repo is to have a functional Nix IDE. Changes that implement opinions of how an IDE should be configured (line length, changing default configurations for the formatters, etc) should not be submitted. The customer is always right in matters of style and taste, and those decisions should be left to the end-users.