#!/bin/bash

set -e

pip install requests
MODELS="$PWD/../third_party/tensorflow_models/"
export PYTHONPATH="$PYTHONPATH:$MODELS"
pushd $MODELS/research/slim
python setup.py install
popd

OUTPUT_PATH=$PWD
pushd ../../nvidia-examples/inference/image-classification/scripts

JETSON=false
NATIVE_ARCH=`uname -m`
if [ ${NATIVE_ARCH} == "aarch64" ]; then
  JETSON=true
fi

set_models() {
  models=(
    mobilenet_v1
    mobilenet_v2
    nasnet_large
    nasnet_mobile
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

set_models

for model in "${models[@]}"
do
  python -u inference.py \
      --data_dir "/data/imagenet/train-val-tfrecord" \
      --default_models_dir "/data/tensorflow/models" \
      --model $model \
      2>&1 | tee $OUTPUT_PATH/output_tf_fp32_bs8_${model}_dynamic_op=False
  python -u check_accuracy.py --input_path $OUTPUT_PATH --precision tf_fp32 --batch_size 8 --model $model

  if $JETSON ; then
    pushd ../../../../qa/inference/image_classification
    python -u check_performance.py --input_path $OUTPUT_PATH --model $model --batch_size 8 --precision tf_fp32
    popd
  fi

  echo "DONE testing $model"
done
popd
