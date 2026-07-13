ARG DHI_IMAGE_DEV=dhi.io/node:24.17.0-debian13-dev
ARG DHI_IMAGE_RUNTIME=dhi.io/node:24.17.0-debian13

FROM dhi.io/busybox:1.38.0-alpine3.24 AS shell

# ---- Build stage (has npm + apt) ----
FROM ${DHI_IMAGE_DEV} AS build

RUN apt-get update \
    && apt-get install -y unzip curl ca-certificates openssl libsnappy-dev gzip \
    # && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

# Patch npm's bundled dependencies
RUN npm install -g npm@11.10.0 --force \
    && npm pack tar@7.5.11 \
    && npm pack minimatch@10.2.1 \
    && npm pack picomatch@4.0.4 \
    && npm cache clean --force \
    # && tar -xzf tar-7.5.11.tgz -C /usr/local/lib/node_modules/npm/node_modules/tar --strip-components=1 \
    && tar -xzf tar-7.5.11.tgz -C /usr/lib/node_modules/npm/node_modules/tar --strip-components=1 \
    && rm tar-7.5.11.tgz \
    # && tar -xzf minimatch-10.2.1.tgz -C /usr/local/lib/node_modules/npm/node_modules/minimatch --strip-components=1 \
    && tar -xzf minimatch-10.2.1.tgz -C /usr/lib/node_modules/npm/node_modules/minimatch --strip-components=1 \
    && rm minimatch-10.2.1.tgz \
    # && tar -xzf picomatch-4.0.4.tgz -C /usr/local/lib/node_modules/npm/node_modules/tinyglobby/node_modules/picomatch --strip-components=1 \
    && tar -xzf picomatch-4.0.4.tgz -C /usr/lib/node_modules/npm/node_modules/tinyglobby/node_modules/picomatch --strip-components=1 \
    && rm picomatch-4.0.4.tgz

# Extract and prune the app
WORKDIR /home/sunbird/telemetry
COPY ./telemetry-service.zip .
RUN unzip telemetry-service.zip -d . && rm telemetry-service.zip
WORKDIR /home/sunbird/telemetry/telemetry
RUN npm prune --omit=dev

# ---- Runtime stage (minimal) ----
FROM ${DHI_IMAGE_RUNTIME}
COPY --from=shell /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=shell /bin/busybox /bin/sh

# Copy patched npm (already patched in build stage)
# COPY --from=build /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
# COPY --from=build /usr/local/bin/npm /usr/local/bin/npm
# COPY --from=build /usr/local/bin/npx /usr/local/bin/npx
COPY --from=build /usr/lib/node_modules/npm /usr/lib/node_modules/npm
COPY --from=build /usr/bin/npm /usr/bin/npm
COPY --from=build /usr/bin/npx /usr/bin/npx

# Copy runtime OS packages (libsnappy, curl, openssl, ca-certs)
COPY --from=build /usr/lib/x86_64-linux-gnu/libsnappy* /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/bin/curl /usr/bin/curl
COPY --from=build /lib/x86_64-linux-gnu/libssl* /lib/x86_64-linux-gnu/
COPY --from=build /lib/x86_64-linux-gnu/libcrypto* /lib/x86_64-linux-gnu/
COPY --from=build /etc/ssl /etc/ssl
COPY --from=build /usr/local/share/ca-certificates /usr/local/share/ca-certificates

# Copy the app
USER nonroot
COPY --from=build --chown=nonroot:nonroot /home/sunbird/telemetry/telemetry /home/sunbird/telemetry/
WORKDIR /home/sunbird/telemetry/

CMD ["node", "app.js"]