#!/bin/bash

set +e

EXAMPLE_PATH="../../nvidia-examples/tensorrt/tftrt/examples/object_detection/"
SCRIPTS_PATH="../inference/object_detection/"

echo Install dependencies of object_detection...
pushd $EXAMPLE_PATH
./install_dependencies.sh
popd

echo Setup tensorflow/tensorrt...
pushd $PWD/../../nvidia-examples/tensorrt
python setup.py install
popd

echo Detect arch...
lscpu | grep -q ^Architecture:.*aarch64
is_aarch64=$[!$?]
lscpu | grep -q ^CPU\(s\):.*8
is_8cpu=$[!$?]
is_xavier=$[$is_aarch64 && $is_8cpu]

echo Find all test cases...
if [[ "$is_xavier" == 1 ]]
then
  TEST_CASES=(`ls $SCRIPTS_PATH/tests/xavier_acc_perf/*`)
else
  TEST_CASES=(`ls $SCRIPTS_PATH/tests/generic_acc/*`)
fi

echo Run all tests...
failure=0
for test_case in "${TEST_CASES[@]}"
do
  echo "Testing $test_case..."
  python -m tftrt.examples.object_detection.test ${test_case}
  echo "DONE testing $test_case"
  failure=$[$failure || $?]
done
exit $failure
