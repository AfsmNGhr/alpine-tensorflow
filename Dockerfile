ARG ALPINE_PYTHON_IMAGE="${ALPINE_PYTHON_IMAGE:-'python:3.7.6-alpine3.11'}"
FROM "${ALPINE_PYTHON_IMAGE}" as base

RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
            openblas libpng libjpeg-turbo hdf5 libstdc++ && \
    apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
            --virtual build-deps build-base hdf5-dev linux-headers file && \
    pip install --no-cache-dir numpy==1.18.0 h5py && \
    pip install --no-cache-dir --no-deps keras_applications==1.0.8 keras_preprocessing==1.1.0 && \
    find /usr/lib* /usr/local/lib* \
         \( -type d -a -name '__pycache__' -o -name '(test|tests)' \) \
         -o \( -type f -a -name '(*.pyc|*.pxd)' -o -name '(*.pyo|*.pyd)' \) \
         -exec rm -rf '{}' + && \
    find /usr/lib* /usr/local/lib* -name '*.so' -print \
         -exec sh -c 'file "{}" | grep -q "not stripped" && strip -s "{}"' \; && \
    apk del build-deps && \
    rm -rf /usr/share/man /usr/local/share/man /usr/share/hdf5_examples \
           /tmp/* /var/cache/apk/* /var/log/* ~/.cache

FROM base as build-base

RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        --virtual build-deps git coreutils cmake build-base linux-headers llvm-dev libexecinfo-dev bazel \
        bash wget file openblas-dev freetype-dev libjpeg-turbo-dev libpng-dev openjdk8 swig zip patch && \
    echo "startup --server_javabase=/usr/lib/jvm/default-jvm --io_nice_level 7" >> /etc/bazel.bazelrc && \
    bazel version

ENV LANG=C.UTF-8 \
    ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" \
    ALPINE_GLIBC_PACKAGE_VERSION="2.30-r0" \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-2.30-r0.apk" \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-2.30-r0.apk" \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-2.30-r0.apk"

RUN echo \
        "-----BEGIN PUBLIC KEY-----\
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApZ2u1KJKUu/fW4A25y9m\
        y70AGEa/J3Wi5ibNVGNn1gT1r0VfgeWd0pUybS4UmcHdiNzxJPgoWQhV2SSW1JYu\
        tOqKZF5QSN6X937PTUpNBjUvLtTQ1ve1fp39uf/lEXPpFpOPL88LKnDBgbh7wkCp\
        m2KzLVGChf83MS0ShL6G9EQIAUxLm99VpgRjwqTQ/KfzGtpke1wqws4au0Ab4qPY\
        KXvMLSPLUp7cfulWvhmZSegr5AdhNw5KNizPqCJT8ZrGvgHypXyiFvvAH5YRtSsc\
        Zvo9GI2e2MaZyo9/lvb+LbLEJZKEQckqRj4P26gmASrZEPStwc+yqy1ShHLA0j6m\
        1QIDAQAB\
        -----END PUBLIC KEY-----" | sed 's/   */\n/g' > "/etc/apk/keys/sgerrand.rsa.pub" && \
    wget "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
         "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
         "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    apk add --no-cache \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    rm /etc/apk/keys/sgerrand.rsa.pub && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    apk del glibc-i18n && \
    rm /root/.wget-hsts && \
    rm "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME"

FROM build-base as compile

ARG LOCAL_RESOURCES="${LOCAL_RESOURCES:-4096,8.0,1.0}"
ARG TF_VERSION="${TF_VERSION:-2.1.0}"
ARG TF_BUILD_OPTIONS="${TF_BUILD_OPTIONS:--c opt}"

ENV TF_VERSION="$TF_VERSION" \
    TF_BUILD_OPTIONS="$TF_BUILD_OPTIONS" \
    TF_IGNORE_MAX_BAZEL_VERSION=1 \
    LOCAL_RESOURCES="$LOCAL_RESOURCES"

# FIX: set link to sys/sysctl.h (@hwloc//:hwloc)

RUN ln -s /usr/include/linux/sysctl.h /usr/include/sys/sysctl.h && \
    while true; do \
      wget -qc "https://github.com/tensorflow/tensorflow/archive/v${TF_VERSION}.tar.gz" \
           -O tensorflow.tar.gz --show-progress --progress=bar:force -t 0 \
           --retry-connrefused --waitretry=2 --read-timeout=30 && \
      break; done && \
    tar xzf tensorflow.tar.gz && \
    rm tensorflow.tar.gz && \
    cd "tensorflow-${TF_VERSION}" && \
    echo '2.0.0-' > .bazelversion && \
    yes '' | ./configure || exit 1 && \
    LD_PRELOAD=/lib bazel build $TF_BUILD_OPTIONS --local_resources $LOCAL_RESOURCES \
        //tensorflow/tools/pip_package:build_pip_package --verbose_failures && \
    ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /root && \
    bazel shutdown && \
    cd / && \
    rm -rf /tensorflow* /usr/share/man /usr/local/share/man /tmp/* /var/cache/apk/* /var/log/* ~/.cache ~/.wget-hsts

FROM base as release

COPY --from=compile /root/*.whl /root

RUN apk add --no-cache --virtual build-deps binutils file && \
    pip install --no-cache-dir /root/*.whl && \
    find /usr/lib* /usr/local/lib* \
         \( -type d -a -name '__pycache__' -o -name '(test|tests)' \) \
         -o \( -type f -a -name '(*.pyc|*.pxd)' -o -name '(*.pyo|*.pyd)' \) \
         -exec rm -rf '{}' + && \
    find /usr/lib* /usr/local/lib* -name '*.so' -print \
         -exec sh -c 'file "{}" | grep -q "not stripped" && strip -s "{}"' \; && \
    apk del build-deps && \
    rm -rf /usr/share/man /usr/local/share/man \
           /tmp/* /var/cache/apk/* /var/log/* ~/.cache && \
    python -c 'import tensorflow as tf; print(tf.__version__); print(tf.sysconfig.get_compile_flags())'
