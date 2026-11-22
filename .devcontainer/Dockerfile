FROM ocaml/opam:ubuntu-24.04-ocaml-5.3

# The image puts the opam switch on PATH through its entrypoint, which dev
# containers replace, so set the switch environment here instead.
ENV OPAM_SWITCH_PREFIX=/home/opam/.opam/5.3 \
    CAML_LD_LIBRARY_PATH=/home/opam/.opam/5.3/lib/stublibs:/home/opam/.opam/5.3/lib/ocaml/stublibs:/home/opam/.opam/5.3/lib/ocaml \
    OCAML_TOPLEVEL_PATH=/home/opam/.opam/5.3/lib/toplevel \
    PATH=/home/opam/.opam/5.3/bin:$PATH

# The image's default opam is 2.1, which lacks --with-dev-setup.
RUN sudo ln -f /usr/bin/opam-2.5 /usr/bin/opam

# Bicep checks the emitted templates offline, as in CI; it needs ICU.
ARG BICEP_VERSION=v0.49.2
RUN sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends libicu74 \
 && sudo rm -rf /var/lib/apt/lists/* \
 && case "$(uname -m)" in aarch64) arch=arm64 ;; *) arch=x64 ;; esac \
 && sudo curl -fsSLo /usr/local/bin/bicep "https://github.com/Azure/bicep/releases/download/${BICEP_VERSION}/bicep-linux-${arch}" \
 && sudo chmod +x /usr/local/bin/bicep

COPY --chown=opam azf.opam /tmp/azf/
RUN cd ~/opam-repository && git pull -q origin master \
 && opam update \
 && opam install -y /tmp/azf --deps-only --with-test --with-doc --with-dev-setup \
 && opam clean -a -c -s --logs \
 && rm -rf /tmp/azf
