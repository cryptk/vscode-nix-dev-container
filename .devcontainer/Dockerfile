FROM nixos/nix

# This is so VSCode can tell it's Nix and skip chcking glibc since it doesn't know how to do it
RUN echo 'ID=nixos' > /etc/os-release

RUN nix-channel --update
RUN nix-env --install --attr \
        nixpkgs.nil \
        nixpkgs.nixd \
        nixpkgs.alejandra \
        nixpkgs.nixfmt \
        nixpkgs.gnused \
        nixpkgs.killall \
        nixpkgs.patchelf

# Make some directories that we will use to assemble our compatability layer
RUN mkdir -p /root/lib /root/bin

COPY --chmod=755 LSPwrapper /root/bin/LSPwrapper

# NixIDE takes it's "nix.serverPath" parameter as a full path, even with spaces, so we cannot pass arguments to the wrapper
# to select what LSP to run.  We work around this by having different names for the wrapper and executing the appropriate
# LSP based on the name the script is called as. There should be a symlink here for every LSP in the container.
RUN ln -s /root/bin/LSPwrapper /root/bin/nixd && \
    ln -s /root/bin/LSPwrapper /root/bin/nil

# Luckily, vscode code-server has support for ELF patching the node binary, we will leverage that to make it work in Nix
# If they ever remove this support, it's easy enough to just run patchelf outselves.  You can see how it works at
# https://github.com/microsoft/vscode/blob/31ec1c528f3352405f329821df31b91e6deba824/resources/server/bin/code-server-linux.sh
# We need an easy to reference location for the binaries and libraries we will need for the binary patch
RUN ln -s $(nix-instantiate --eval-only --expr '(import <nixpkgs> {}).glibc.outPath'  | sed -e 's/"//g') /root/lib/glibc && \
    ln -s $(nix-instantiate --eval-only --expr '(import <nixpkgs> {}).libgcc.lib.outPath'  | sed -e 's/"//g') /root/lib/libgcc && \
    ln -s $(which patchelf) /root/bin/patchelf

# Finally we will set some env vars to tell vscode where to find them so it can patch nodejs
ENV VSCODE_SERVER_CUSTOM_GLIBC_LINKER="/root/lib/glibc/lib/ld-linux-x86-64.so.2"
ENV VSCODE_SERVER_CUSTOM_GLIBC_PATH="/root/lib/glibc/lib:/root/lib/libgcc/lib"
ENV VSCODE_SERVER_PATCHELF_PATH="/root/bin/patchelf"
