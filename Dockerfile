FROM debian

RUN apt-get -y update && \
    apt-get -y install build-essential wget make libssl-dev && \
    wget https://code.call-cc.org/releases/4.13.0/chicken-4.13.0.tar.gz && \
    tar -xvvzf chicken-4.13.0.tar.gz && \
    cd chicken-4.13.0 && \
    make PLATFORM=linux install

RUN chicken-install spiffy && \
    chicken-install intarweb && \
    chicken-install http-client && \
    chicken-install regex && \
    chicken-install uri-common && \
    chicken-install json && \
    chicken-install openssl

COPY ./main.scm ./main.scm
RUN chmod +x ./main.scm

ENV REWRITE_TARGET_HOST=discordapp.com
ENV REWRITE_TARGET_SCHEME=https

EXPOSE 8080

CMD ./main.scm
