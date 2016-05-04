FROM pritunl/archlinux:2016-04-16

# note: jenkins has uid 1001 & gid 1002 on our build hosts, this needs to be reflected in here!
ENV UID 1001
RUN useradd jenkins -u 1001 -g root

RUN pacman -Sy --noconfirm gcc clang sudo autoconf base-devel \
                           wget git unzip python2 \
                           libev snappy help2man

## extra packages not available in the default repo
## makepkg refuses running as root, so switch to jenkins first

RUN echo 'jenkins ALL=NOPASSWD: ALL' >/etc/sudoers.d/jenkins
RUN mkdir /home/jenkins
RUN chown jenkins /home/jenkins

WORKDIR /home/jenkins
USER jenkins

RUN git clone https://aur.archlinux.org/clasp.git && \
    cd clasp && \
    makepkg -sri --noconfirm && \
    cd .. && \
    rm -rf clasp

RUN git clone https://aur.archlinux.org/gringo.git && \
    cd gringo && \
    makepkg -sri --noconfirm && \
    cd .. && \
    rm -rf gringo

RUN git clone https://aur.archlinux.org/aspcud.git && \
    cd aspcud && \
    makepkg -sri --noconfirm && \
    cd .. && \
    rm -rf aspcud

RUN git clone https://aur.archlinux.org/opam.git && \
    cd opam && \
    makepkg -sri --noconfirm && \
    cd .. && \
    rm -rf opam

env ocaml_version=4.02.3
ENV opam_env="opam config env"
RUN opam init --comp ${ocaml_version}

RUN eval `${opam_env}` && \
    opam update && \
    opam install -y \
         core.113.00.00 \
         arakoon
