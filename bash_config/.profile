# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1) if ~/.bash_profile or ~/.bash_login exists;
# bash_config/.bash_profile exists purely to delegate here.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# PATH is built BEFORE sourcing .bashrc: .bashrc invokes tools (starship, fzf,
# fastfetch) that may live in these directories. Building PATH afterwards makes
# a login shell fail where an interactive one succeeds.

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# set PATH so it includes npm global bin (user-writable prefix) if it exists
if [ -d "$HOME/.npm-global/bin" ] ; then
    PATH="$HOME/.npm-global/bin:$PATH"
fi

# Corporate TLS interception (Zscaler) re-signs HTTPS. Node bundles its own CA
# store and ignores the system one, so every node process needs pointing at the
# system bundle that already carries the Zscaler root. Without this, npm and any
# node tool that talks to the network fail with UNABLE_TO_GET_ISSUER_CERT_LOCALLY
# while curl succeeds.
if [ -f /etc/ssl/certs/ca-certificates.crt ] ; then
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
fi

# ~/.cargo/env is sourced by .bashrc, which runs below.

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
