#!/bin/bash
NATIVE_ARCH=`uname -m`
if [ ${NATIVE_ARCH} == 'aarch64' ]; then
  DEVS=1
else
  DEVS=$(nvidia-smi -L | wc -l)
fi
[[ $DEVS -gt 4 ]] && DEVS=4
export CUDA_VISIBLE_DEVICES=$(seq -s',' 0 $((DEVS-1)))
( cmdpid=$BASHPID; (sleep 20; kill -s SIGINT $cmdpid) & exec tensorboard --logdir /tmp )
RET=$?
if [[ $RET -eq 0 ]]; then
    echo Test succeeded
else
    echo Test failed
fi
exit $RET
