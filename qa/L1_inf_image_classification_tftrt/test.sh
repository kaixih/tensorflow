#!/bin/bash

set -e

pip install requests
MODELS="$PWD/../third_party/tensorflow_models/"
export PYTHONPATH="$PYTHONPATH:$MODELS"
pushd $MODELS/research/slim
python setup.py install
popd

OUTPUT_PATH=$PWD

JETSON=false
NATIVE_ARCH=`uname -m`
if [ ${NATIVE_ARCH} == "aarch64" ]; then
  JETSON=true
fi

JETSON=false
NATIVE_ARCH=`uname -m`

if [ ${NATIVE_ARCH} == 'aarch64' ]; then
  JETSON=true
fi


set_models() {
  models=(
    mobilenet_v1
    mobilenet_v2
    nasnet_large
    #nasnet_mobile
    resnet_v1_50
    resnet_v2_50
    #vgg_16
    #vgg_19
    inception_v3
    inception_v4
  )
  if ! $JETSON ; then
    models+=(vgg_16)
    models+=(vgg_19)
  fi
}


set_allocator() {
  if $JETSON ; then
    export TF_GPU_ALLOCATOR="cuda_malloc"
  else
    unset TF_GPU_ALLOCATOR
  fi
}

set_allocator
set_models

for model in "${models[@]}"
do
  echo "Testing $model..."
  pushd ../third_party/tensorrt/tftrt/examples/image-classification/
  python -u image_classification.py \
      --data_dir "/data/imagenet/train-val-tfrecord" \
      --default_models_dir "/data/tensorflow/models" \
      --model $model \
      --use_trt \
      2>&1 | tee $OUTPUT_PATH/output_tftrt_fp32_bs8_${model}_dynamic_op=False
  popd
  pushd ../inference/image_classification/
  python -u check_accuracy.py --input_path $OUTPUT_PATH --precision tftrt_fp32 --batch_size 8 --model $model
  if $JETSON ; then
    python -u check_performance.py --input_path $OUTPUT_PATH --model $model --batch_size 8 --precision tftrt_fp32
  fi
  popd

  echo "DONE testing $model"
done
