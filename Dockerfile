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
            --virtual build-deps git coreutils cmake build-base linux-headers musl-utils \
            bash wget file openblas-dev freetype-dev libjpeg-turbo-dev libpng-dev openjdk8 swig zip patch

ARG BAZEL_VERSION="${BAZEL_VERSION:-0.29.1}"
ARG LOCAL_RESOURCES="${LOCAL_RESOURCES:-4096,8.0,1.0}"
ARG TF_VERSION="${TF_VERSION:-2.1.0}"
ARG TF_BUILD_OPTIONS="${TF_BUILD_OPTIONS:--c opt}"
ENV BAZEL_VERSION="$BAZEL_VERSION" \
    TF_VERSION="$TF_VERSION" \
    TF_BUILD_OPTIONS="$TF_BUILD_OPTIONS" \
    JAVA_HOME=/usr/lib/jvm/default-jvm \
    LOCAL_RESOURCES="$LOCAL_RESOURCES"

RUN while true; do \
      wget -qc "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip" \
           -O bazel.zip --show-progress --progress=bar:force -t 0 \
           --retry-connrefused --waitretry=2 --read-timeout=30 && \
      break; done && \
    mkdir "bazel-${BAZEL_VERSION}" && \
    unzip -qd "bazel-${BAZEL_VERSION}" bazel.zip && \
    rm bazel.zip && \
    cd "bazel-${BAZEL_VERSION}" && \
    sed -i -e 's/-classpath/-J-Xmx4096m -J-Xms128m -classpath/g' scripts/bootstrap/compile.sh && \
    EXTRA_BAZEL_ARGS=--host_javabase=@local_jdk//:jdk bash compile.sh && \
    echo "startup --server_javabase=$JAVA_HOME --io_nice_level 7" >> /etc/bazel.bazelrc && \
    cp -p output/bazel /usr/local/bin/ && \
    cd / && \
    rm -rf /bazel* /usr/share/man /usr/local/share/man /tmp/* /var/cache/apk/* /var/log/* ~/.cache && \
    bazel version

FROM build-base as compile

RUN while true; do \
      wget -qc "https://github.com/tensorflow/tensorflow/archive/v${TF_VERSION}.tar.gz" \
           -O tensorflow.tar.gz --show-progress --progress=bar:force -t 0 \
           --retry-connrefused --waitretry=2 --read-timeout=30 && \
      break; done && \
    tar xzf tensorflow.tar.gz && \
    rm tensorflow.tar.gz && \
    cd "tensorflow-${TF_VERSION}" && \
    yes '' | ./configure || exit 1 && \
    bazel build $TF_BUILD_OPTIONS --local_resources $LOCAL_RESOURCES \
          //tensorflow/tools/pip_package:build_pip_package --verbose_failures && \
    ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /root && \
    bazel shutdown && \
    cd / && \
    rm -rf /tensorflow* /usr/share/man /usr/local/share/man /tmp/* /var/cache/apk/* /var/log/* ~/.cache

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
