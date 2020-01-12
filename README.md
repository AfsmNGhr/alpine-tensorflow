## Tensorflow for alpine

![https://microbadger.com/images/afsmnghr/tensorflow](https://images.microbadger.com/badges/version/afsmnghr/tensorflow.svg)
![https://microbadger.com/images/afsmnghr/tensorflow](https://images.microbadger.com/badges/image/afsmnghr/tensorflow.svg)
![https://hub.docker.com/r/afsmnghr/tensorflow/](https://img.shields.io/docker/pulls/afsmnghr/tensorflow.svg?style=flat-square)
![https://hub.docker.com/r/afsmnghr/tensorflow/](https://img.shields.io/docker/stars/afsmnghr/tensorflow.svg?style=flat-square)

Compile tensorflow with options:

```conf
BAZEL_VERSION=0.29.1
TF_BUILD_OPTIONS= --config opt --config=noaws --config=nogcp --config=nohdfs --config=nonccl
LOCAL_RESOURCES=4096,8.0,1.0
```

```sh
bazel build $TF_BUILD_OPTIONS --local_resources $LOCAL_RESOURCES //tensorflow/tools/pip_package:build_pip_package
```

#### How to install:

Use the pre-built binary wheel hosted on [Github](https://github.com/AfsmNGhr/alpine-tensorflow/releases).

#### How to compile:

If you want to compile it yourself, use the Dockerfile (optional with build args). Note that it can take many hours.

```sh
docker build --build-arg ALPINE_PYTHON_IMAGE=python:3.8.0-alpine3.11 \
             --build-arg BAZEL_VERSION=0.25.2 \
             --build-arg TF_VERSION=1.14.0 \
             --build-arg TF_BUILD_OPTIONS=-c opt --copt=-mavx --copt=-mavx2 --copt=-mfma --copt=-mfpmath=both --copt=-msse4.2
             -t tensorflow:1.14.0-alpine3.11 .
```
