FROM python:3.7.3-alpine3.9

ENV TENSORFLOW_VERSION=1.13.1 \
    NUMPY_VERSION=1.16.1 \
    BAZEL_VERSION=0.19.2 \
    LOCAL_RESOURCES=2048,.5,1.0 \
    CC_OPT_FLAGS='-march=native' \
    TF_NEED_JEMALLOC=1 \
    TF_NEED_GCP=0 \
    TF_NEED_HDFS=0 \
    TF_NEED_S3=0 \
    TF_ENABLE_XLA=0 \
    TF_NEED_GDR=0 \
    TF_NEED_VERBS=0 \
    TF_NEED_OPENCL=0 \
    TF_NEED_CUDA=0 \
    TF_NEED_MPI=0

RUN apk add --no-cache --virtual build-deps cmake build-base linux-headers \
            bash wget file openblas-dev freetype-dev libjpeg-turbo-dev \
            libpng-dev openjdk8 swig && \
    pip install --no-cache-dir "numpy==$NUMPY_VERSION" && \
    echo 'Download and install bazel' && \
    wget -q " https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip" \
         -O bazel.zip && \
    unzip -qq bazel.zip && \
    rm bazel.zip && \
    cd "bazel-${BAZEL_VERSION}" && \
    sed -i -e 's/-classpath/-J-Xmx8192m -J-Xms128m -classpath/g' \
        scripts/bootstrap/compile.sh && \
    bash compile.sh && \
    cp -p output/bazel /usr/local/bin/ && \
    cd / && \
    bazel version && \
    echo 'Download and compile tensorflow' && \
    wget -q "https://github.com/tensorflow/tensorflow/archive/v${TENSORFLOW_VERSION}.tar.gz" \
         -O tensorflow.tar.gz && \
    tar xzf tensorflow.tar.gz && \
    rm tensorflow.tar.gz && \
    cd "tensorflow-${TENSORFLOW_VERSION}" && \
    sed -i -e '/JEMALLOC_HAVE_SECURE_GETENV/d' third_party/jemalloc.BUILD && \
    sed -i -e '/define TF_GENERATE_BACKTRACE/d' tensorflow/core/platform/default/stacktrace.h && \
    sed -i -e '/define TF_GENERATE_STACKTRACE/d' tensorflow/core/platform/stacktrace_handler.cc && \
    bazel build -c opt --local_resources "${LOCAL_RESOURCES}" //tensorflow/tools/pip_package:build_pip_package && \
    ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg && \
    cp /tmp/tensorflow_pkg/*.whl /root && \
    pip install --no-cache-dir /root/*.whl && \
    python -c 'import tensorflow; tensorflow.__version__' && \
    rm -rf "bazel-${BAZEL_VERSION}" /var/tmp/* /usr/share/man \
           /tmp/* /var/cache/apk/* /var/log/* /root/.cache \
           /usr/local/share/man /root/.wget-hsts
