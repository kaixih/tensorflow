#!/bin/bash

set -e

pip install requests
MODELS="$PWD/../third_party/tensorflow_models/"
export PYTHONPATH="$PYTHONPATH:$MODELS"
pushd $MODELS/research/slim
python setup.py install
popd

OUTPUT_PATH=$PWD
EXAMPLE_PATH="../../nvidia-examples/tensorrt/tftrt/examples/image-classification/"
SCRIPTS_PATH="../inference/image_classification/"

JETSON=false
NATIVE_ARCH=`uname -m`
if [ ${NATIVE_ARCH} == "aarch64" ]; then
  JETSON=true
fi

set_models() {
  models=(
    #mobilenet_v1 disabled due to low accuracy: http://nvbugs/2369608
    mobilenet_v2
    #nasnet_large disabled due to calibration taking ~2 hours.
    #nasnet_mobile disabled only on Jetson due to memory issues
    resnet_v1_50
    #resnet_v2_50 disabled only on Jetson due to time limit for L2 tests
    #vgg_16 disabled only on Jetson due to low perf.
    #vgg_19 disabled only on Jetson due to low perf.
    inception_v3
    inception_v4
  )
  if ! $JETSON ; then
    models+=(vgg_16)
    models+=(vgg_19)
    models+=(resnet_v2_50)
    models+=(nasnet_mobile)
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
  pushd $EXAMPLE_PATH
  python -u image_classification.py \
      --data_dir "/data/imagenet/train-val-tfrecord" \
      --calib_data_dir "/data/imagenet/train-val-tfrecord" \
      --default_models_dir "/data/tensorflow/models" \
      --model $model \
      --use_trt \
      --batch_size 8 \
      --num_calib_inputs 8 \
      --precision int8 \
      --num_calib_input 8 \
      2>&1 | tee $OUTPUT_PATH/output_tftrt_int8_bs8_${model}_dynamic_op=False
  popd
  pushd $SCRIPTS_PATH
  python -u check_accuracy.py --tolerance 1.0 --input_path $OUTPUT_PATH --precision tftrt_int8 --batch_size 8 --model $model
  python -u check_nodes.py --input_path $OUTPUT_PATH --precision tftrt_int8 --batch_size 8 --model $model
  if $JETSON ; then
    python -u check_performance.py --input_path $OUTPUT_PATH --model $model --batch_size 8 --precision tftrt_int8 
  fi
  popd

  echo "DONE testing $model"
done
