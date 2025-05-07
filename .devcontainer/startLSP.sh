#!/usr/bin/env bash

# devcontainers don't seem to run entrypoints, so we have to handle getting nix-daemon going as part of starting the LSP

# First ensure there are no lingering processes in case we are restarting the LSP
killall nix-daemon
killall nixd

# Send nix-daemon off into the background so that nixd can talk to it
nix-daemon &

# Exec nixd so that NixIDE can grab it's stdin/stdout
exec nixd