FROM ubuntu:22.04 AS builder
ARG VERUS_VERSION=1.2.16-1
WORKDIR /app
RUN apt update && \
  apt install -y  wget unzip curl nano openssh-server ngrep tmux net-tools screen vim jq python3 python3-pip
#RUN wget https://github.com/VerusCoin/VerusCoin/releases/download/v${VERUS_VERSION}/Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tgz
#RUN tar zxvf Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tgz
#RUN tar zxvf Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tar.gz
RUN wget https://github.com/VerusCoin/VerusCoin/releases/download/v${VERUS_VERSION}/Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tgz \
    && tar -xzvf Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tgz  \
    && tar -xzvf Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tar.gz --strip=1 -C /usr/local/bin/ \
    && rm -rf Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tgz Verus-CLI-Linux-v${VERUS_VERSION}-x86_64.tar.gz \
    && verusd --version

#EXPOSE 18842
CMD ["verusd", "-chain=vrsctest"]
