ARG DHI_IMAGE_DEV=dhi.io/node:24.17.0-debian13-dev
ARG DHI_IMAGE_RUNTIME=dhi.io/node:24.17.0-debian13

FROM dhi.io/busybox:1.38.0-alpine3.24 as shell

FROM ${DHI_IMAGE_DEV} AS build
RUN apt-get update \
    && apt-get install -y unzip curl ca-certificates openssl libsnappy-dev \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /home/sunbird/telemetry
COPY ./telemetry-service.zip .
RUN unzip telemetry-service.zip -d . && rm telemetry-service.zip
WORKDIR /home/sunbird/telemetry/telemetry
RUN npm prune --omit=dev

# ---- Runtime stage: m

# RUN apt-get update \
#  && apt-get install -y unzip curl ca-certificates openssl libsnappy-dev \
#  && apt-get upgrade -y \
#  && rm -rf /var/lib/apt/lists/*
# WORKDIR /home/sunbird/telemetry
# COPY ./telemetry-service.zip /home/sunbird/telemetry/
# RUN unzip /home/sunbird/telemetry/telemetry-service.zip -d /home/sunbird/telemetry/
# WORKDIR /home/sunbird/telemetry/telemetry
# RUN npm prune --omit=dev

FROM ${DHI_IMAGE_RUNTIME}
COPY --from=shell /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=shell /bin/busybox /bin/sh

RUN npm install -g npm@11.10.0 \
    && npm pack tar@7.5.11 \
    && npm pack minimatch@10.2.1 \
    && npm pack picomatch@4.0.4 \
    && npm cache clean --force \
    && tar -xzf tar-7.5.11.tgz -C /usr/local/lib/node_modules/npm/node_modules/tar --strip-components=1 \
    && rm tar-7.5.11.tgz \
    && tar -xzf minimatch-10.2.1.tgz -C /usr/local/lib/node_modules/npm/node_modules/minimatch --strip-components=1 \
    && rm minimatch-10.2.1.tgz \
    && tar -xzf picomatch-4.0.4.tgz -C /usr/local/lib/node_modules/npm/node_modules/tinyglobby/node_modules/picomatch --strip-components=1 \
    && rm picomatch-4.0.4.tgz

USER nonroot
COPY --from=build --chown=nonroot:nonroot /home/sunbird/telemetry/telemetry/ /home/sunbird/telemetry/
WORKDIR /home/sunbird/telemetry/
CMD ["node", "app.js"]

# RUN npm install -g npm@11.10.0 \
#  && npm pack tar@7.5.11 \
#  && npm pack minimatch@10.2.1 \
#  && npm pack picomatch@4.0.4 \
#  && npm cache clean --force \
#  && tar -xzf tar-7.5.11.tgz -C /usr/local/lib/node_modules/npm/node_modules/tar --strip-components=1 \
#  && rm tar-7.5.11.tgz \
#  && tar -xzf minimatch-10.2.1.tgz -C /usr/local/lib/node_modules/npm/node_modules/minimatch --strip-components=1 \
#  && rm minimatch-10.2.1.tgz \
#  && tar -xzf picomatch-4.0.4.tgz -C /usr/local/lib/node_modules/npm/node_modules/tinyglobby/node_modules/picomatch --strip-components=1 \
#  && rm picomatch-4.0.4.tgz
# RUN useradd -rm -d /home/sunbird -s /bin/bash -g root -G sudo -u 1001 sunbird
# RUN apt-get update \
#  && apt-get install -y curl ca-certificates openssl libsnappy-dev \
#  && apt-get upgrade -y \
#  && rm -rf /var/lib/apt/lists/*
# USER sunbird
# RUN mkdir -p /home/sunbird/telemetry
# WORKDIR /home/sunbird/telemetry
# COPY --from=build /home/sunbird/telemetry/telemetry/ /home/sunbird/telemetry/
# CMD ["node", "app.js"]