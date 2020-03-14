## Tensorflow for Alpine

It work on Alpine 3.10 and Tensorflow 1.13.2.
Compile tensorflow with options:

```conf
CC_OPT_FLAGS='-march=native'
TF_NEED_JEMALLOC=1
TF_NEED_GCP=0
TF_NEED_HDFS=0
TF_NEED_S3=0
TF_ENABLE_XLA=0
TF_NEED_GDR=0
TF_NEED_VERBS=0
TF_NEED_OPENCL=0
TF_NEED_CUDA=0
TF_NEED_MPI=0
```

#### How to install

Use the pre-built binary wheel hosted on [Github](https://github.com/AfsmNGhr/alpine-tensorflow/releases).

#### How to compile

If you want to compile it yourself, use the Dockerfile. Note that it can take many hours.
