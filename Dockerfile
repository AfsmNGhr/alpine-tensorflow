ARG ALPINE_PYTHON_IMAGE="${ALPINE_PYTHON_IMAGE:-'python:3.7.8-alpine3.12'}"
FROM "${ALPINE_PYTHON_IMAGE}" as base

RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community \
            openblas libpng libjpeg-turbo hdf5 libstdc++ && \
    apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community \
            --virtual build-deps build-base hdf5-dev linux-headers file && \
    pip install --no-cache-dir numpy==1.18.4 h5py && \
    pip install --no-cache-dir --no-deps keras_applications==1.0.8 keras_preprocessing==1.1.2 && \
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

ENV BAZEL_VERSION=0.19.2 \
    JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk

RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        --virtual build-deps git coreutils cmake build-base linux-headers llvm-dev gcompat libexecinfo-dev \
        bash wget file openblas-dev freetype-dev libjpeg-turbo-dev libpng-dev openjdk8 swig zip patch && \
    wget -q "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip" \
         -O bazel.zip && \
    mkdir "bazel-${BAZEL_VERSION}" && \
    unzip -qd "bazel-${BAZEL_VERSION}" bazel.zip && \
    rm bazel.zip && \
    cd "bazel-${BAZEL_VERSION}" && \
    sed -i -e 's/-classpath/-J-Xmx4096m -J-Xms128m -classpath/g' \
        scripts/bootstrap/compile.sh && \
    bash compile.sh && \
    cp -p output/bazel /usr/local/bin/ && \
    bazel version

FROM build-base as compile

ARG LOCAL_RESOURCES="${LOCAL_RESOURCES:-4096,8.0,1.0}"
ARG TF_VERSION="${TF_VERSION:-1.13.2}"
ARG TF_BUILD_OPTIONS="${TF_BUILD_OPTIONS:--c opt}"

ENV TF_VERSION="$TF_VERSION" \
    TF_BUILD_OPTIONS="$TF_BUILD_OPTIONS" \
    LOCAL_RESOURCES="$LOCAL_RESOURCES"

RUN while true; do \
      wget -qc "https://github.com/tensorflow/tensorflow/archive/v${TF_VERSION}.tar.gz" \
           -O tensorflow.tar.gz --show-progress --progress=bar:force -t 0 \
           --retry-connrefused --waitretry=2 --read-timeout=30 && \
      break; done && \
    tar xzf tensorflow.tar.gz && \
    rm tensorflow.tar.gz && \
    cd "tensorflow-${TF_VERSION}" && \
    sed -i -e '/define TF_GENERATE_BACKTRACE/d' tensorflow/core/platform/default/stacktrace.h && \
    sed -i -e '/define TF_GENERATE_STACKTRACE/d' tensorflow/core/platform/stacktrace_handler.cc && \
    yes '' | ./configure || exit 1 && \
    bazel build $TF_BUILD_OPTIONS --local_resources $LOCAL_RESOURCES \
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
