## Tensorflow for alpine and python3.7

![https://travis-ci.org/AfsmNGhr/alpine-py3-tensorflow](https://travis-ci.org/AfsmNGhr/alpine-py3-tensorflow.svg?branch=master)
![https://microbadger.com/images/afsmnghr/alpine-py3-tensorflow](https://images.microbadger.com/badges/version/afsmnghr/alpine-py3-tensorflow.svg)
![https://microbadger.com/images/afsmnghr/alpine-py3-tensorflow](https://images.microbadger.com/badges/image/afsmnghr/alpine-py3-tensorflow.svg)
![https://hub.docker.com/r/afsmnghr/alpine-py3-tensorflow/](https://img.shields.io/docker/pulls/afsmnghr/alpine-py3-tensorflow.svg?style=flat-square)
![https://hub.docker.com/r/afsmnghr/alpine-py3-tensorflow/](https://img.shields.io/docker/stars/afsmnghr/alpine-py3-tensorflow.svg?style=flat-square)

It work on Alpine 3.9.3 and Tensorflow 1.13.1.
Compile tensorflow with options:

```sh
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
```

#### How to install

Use the pre-built binary wheel hosted on Github.

```sh
pip install *.whl
```

If you want to compile it yourself, use the Dockerfile. Note that it can take many hours.
