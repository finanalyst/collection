FROM rakudo-star:2020.01
MAINTAINER Richard Hainsworth, aka finanalyst
WORKDIR /collection
COPY . /collection
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install apt-utils \
    && apt-get -y install build-essential make nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && zef update && zef install zef && zef install . \
    && raku-pod-render-install-highlighter
CMD bash