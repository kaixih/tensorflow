#!/bin/bash
#
# Configure, build, and install Tensorflow
#

# Exit at error
set -e

Usage() {
  echo "Configure, build, and install Tensorflow."
  echo ""
  echo "  Usage: $0 [OPTIONS]"
  echo ""
  echo "    OPTIONS          DESCRIPTION"
  echo "    --python2        Build python2 package (default)"
  echo "    --python3        Build python3 package"
  echo "    --configonly     Run configure step only"
  echo "    --noconfig       Skip configure step"
  echo "    --noclean        Retain intermediate build files"
}

PYVER=2
CONFIGONLY=0
NOCONFIG=0
NOCLEAN=0

while [[ $# -gt 0 ]]; do
  case $1 in
    "--help"|"-h")  Usage; exit 1 ;;
    "--python2")    PYVER=2 ;;
    "--python3")    PYVER=3 ;;
    "--configonly") CONFIGONLY=1 ;;
    "--noconfig")   NOCONFIG=1 ;;
    "--noclean")    NOCLEAN=1 ;;
    *)
      echo UNKNOWN OPTION $1
      echo Run $0 -h for help
      exit 1
  esac
  shift 1
done

cd /opt/tensorflow
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64/stubs
ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
export PYTHON_BIN_PATH=/usr/bin/python$PYVER
if [[ $NOCONFIG -eq 0 ]]; then
  yes "" | ./configure
fi

if [[ $CONFIGONLY -eq 1 ]]; then
  exit 0
fi

bazel build -c opt --config=cuda tensorflow/tools/pip_package:build_pip_package
bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/pip
pip$PYVER install --no-cache-dir --upgrade /tmp/pip/tensorflow-*.whl
rm -rf /tmp/pip/tensorflow-*.whl /usr/local/cuda/lib64/stubs/libcuda.so.1

if [[ $NOCLEAN -eq 0 ]]; then
  bazel clean --expunge
  rm -rf /root/.cache/bazel
  rm .tf_configure.bazelrc .bazelrc
fi
