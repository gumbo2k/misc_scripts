#!/bin/bash

debug_output() {
  if [ "${DEBUG}"=="1" ] ; then
    echo "DEBUG: $*"
  fi
}

#probably not needed as fio uses directio but the drive itself might have some async write back caches
sync_and_wait() {
  echo "Sync and wait 5 sec."
  sync
  sleep 5
}

# probably not needed, as fio invalidates caches before reading a file.
# reading an unrelated large file from the same disk might be the better way,
# as it will also flush caches in the drive itself
flush_caches_and_wait() {
  sync
  echo 3 > /proc/sys/vm/drop_caches
  blockdev --flushbufs /dev/${DEVICE}
  hdparm -F /dev/${DEVICE}
}

# Select tests to perform
DO_SEQUENTIALREAD=true
DO_SEQUENTIALWRITE=true
DO_RANDOMREAD=true
DO_RANDOMWRITE=true
#DO_QD1_RANDOMREAD=true
#DO_QD1_RANDOMWRITE=true

TESTFILESIZE=10g
TESTFILENUM=6
TESTFILENAMEPFX=fiotestfile
RUNTIME=60

SEQIOSIZE=1m
SEQIODEPTH=8

RNDIOSIZE=4k
TARGETRNDIODEPTH=192

RNDIODEPTH=$(( TARGETRNDIODEPTH / TESTFILENUM ))
TOTALRNDIODEPTH=$(( RNDIODEPTH * TESTFILENUM ))

DEVICE=$1
RUNID=$(date +'%y%m%d%H%M'-$$)-$(echo ${DEVICE} | tr -c '[:alnum:]' '_')

if [ -z ${DEVICE} ] ; then
  echo "Usage:"
  echo "  $0 DEVICE"
  echo "DEVICE is empty - we need a device name of a mounted device passed as first parameter. E.g. 'sda1' or 'mapper/ubuntu--vg-ubuntu--lv'"
  exit 1
fi

MOUNT=$(df | grep '^/dev/'${DEVICE} | awk '{ print $6 }')

if [ -z ${MOUNT} ] ; then
  echo "Could not find mount point for ${DEVICE}"
  exit 1
fi

echo "Mountpoint for device ${DEVICE} is ${MOUNT}"

# Create files to do IO upon. This avoids metadata updates during later tests.
for filenumber in $(seq 1 ${TESTFILENUM}) ; do
  filename=${TESTFILENAMEPFX}${filenumber}
  if [ -e ${MOUNT}/$filename ] ; then
    echo Skipping creation of ${MOUNT}/$filename
  else
    echo Creating test file ${MOUNT}/$filename of size ${TESTFILESIZE}
    fio --name=prefill --filename=${MOUNT}/$filename --bs=${SEQIOSIZE} --size=${TESTFILESIZE} --rw=write \
      --direct=1 --ioengine=libaio --iodepth=${SEQIODEPTH} \
      --output=${RUNID}-testfile-prefill.out
    echo
    if [[ $filenumber -eq ${TESTFILENUM} ]] ; then
      sync_and_wait
    fi
  fi
done

#Sequential Read
if [ "${DO_SEQUENTIALREAD}" = true ] ; then
  echo "## Sequential Read. One process. QD=${SEQIODEPTH}."
  fio --name=seq_read --filename=${MOUNT}/${TESTFILENAMEPFX}1 --bs=${SEQIOSIZE} --rw=read \
    --time_based --runtime=${RUNTIME} \
    --direct=1 --ioengine=libaio --iodepth=${SEQIODEPTH} \
    --output=${RUNID}-seq-read.out
  echo
  echo Look at the bandwidth:
  grep '^  read:'  ${RUNID}-seq-read.out
  grep '^   bw '   ${RUNID}-seq-read.out
  echo
fi

#Sequential Write
if [ "${DO_SEQUENTIALWRITE}" = true ] ; then
  echo "## Sequential Write. One process. QD=${SEQIODEPTH}."
  fio --name=seq_write --filename=${MOUNT}/${TESTFILENAMEPFX}1 --bs=${SEQIOSIZE} --rw=write \
    --time_based --runtime=${RUNTIME} \
    --direct=1 --ioengine=libaio --iodepth=${SEQIODEPTH} \
    --output=${RUNID}-seq-write.out
  echo
  echo Look at the bandwidth:
  grep '^  write:' ${RUNID}-seq-write.out
  grep '^   bw '   ${RUNID}-seq-write.out
  echo
  sync_and_wait
fi


if [ "${DO_RANDOMREAD}" = true -o "${DO_RANDOMWRITE}" = true ] ; then
  echo "## Random IO with ${TESTFILENUM} parallel clients and deep queue."
  echo "Effective IO Depth per device file for RANDOM tests: TARGET_IO_DEPTH ( ${TARGETRNDIODEPTH} ) / NUMER_OF_TESTFILES ( ${TESTFILENUM} ) = ${RNDIODEPTH}"
  echo "Total IO Depth for RANDOM = ${TOTALRNDIODEPTH}"
fi
#Random Read
if [ "${DO_RANDOMREAD}" = true ] ; then
  echo "## Random Read. ${TESTFILENUM} processes. QD=${TOTALRNDIODEPTH}. Per process QD=${RNDIODEPTH}"
  fio --name=global --group_reporting --bs=${RNDIOSIZE} --rw=randread \
    --time_based --runtime=${RUNTIME} \
    --direct=1 --ioengine=libaio --iodepth=${RNDIODEPTH} --output=${RUNID}-rnd-read.out \
    $(for x in $(seq 1 ${TESTFILENUM}) ; do printf " --name=read%d --filename=%s/%s%d " ${x} "${MOUNT}" "${TESTFILENAMEPFX}" ${x} ; done)
  echo
  echo Look at the IOPS:
  grep '^  read:'  ${RUNID}-rnd-read.out
  grep '^   iops ' ${RUNID}-rnd-read.out
  echo
fi

#Random Write
if [ "${DO_RANDOMWRITE}" = true ] ; then 
  echo "## Random Write. ${TESTFILENUM} processes. QD=${TOTALRNDIODEPTH}. Per process QD=${RNDIODEPTH}"
  fio --name=global --group_reporting --bs=${RNDIOSIZE} --rw=randwrite \
    --time_based --runtime=${RUNTIME} \
    --direct=1 --ioengine=libaio --iodepth=${RNDIODEPTH} --output=${RUNID}-rnd-write.out \
    $(for x in $(seq 1 ${TESTFILENUM}) ; do printf " --name=write%d --filename=%s/%s%d " ${x} "${MOUNT}" "${TESTFILENAMEPFX}" ${x} ; done)
  echo
  echo Look at the IOPS:
  grep '^  write:'  ${RUNID}-rnd-write.out
  grep '^   iops '  ${RUNID}-rnd-write.out
  echo
  sync_and_wait
fi


#
# Repeat for single OIO
#
if [ "${DO_QD1_RANDOMREAD}" = true -o "${DO_QD1_RANDOMWRITE}" = true ] ; then 
  echo "## Random IO with shallow queue."
  echo "Single Outstanding IO for latency (iodepth=1)"
  echo "Look at the latecy distribution in the report file afterwards."
fi
#Random Read - Single OIO
if [ "${DO_QD1_RANDOMREAD}" = true ] ; then
  RNDIODEPTH=1
  echo Random Read. 2 processes. Per process QD=${RNDIODEPTH}
  fio --name=global  --group_reporting --bs=${RNDIOSIZE} --rw=randread \
    --time_based --runtime=${RUNTIME} --direct=1 --ioengine=libaio --iodepth=${RNDIODEPTH} --output=${RUNID}-QD-${RNDIODEPTH}-rnd-read.out \
    $(for x in 1 2 ; do printf " --name=write%d --filename=%s/%s%d " ${x} "${MOUNT}" "${TESTFILENAMEPFX}" ${x} ; done)
  echo
fi

#Random Write - Single OIO
if [ "${DO_QD1_RANDOMWRITE}" = true ] ; then 
  RNDIODEPTH=1
  echo Random Write. 2 processes. Per process QD=${RNDIODEPTH}
  fio --name=global --group_reporting --bs=${RNDIOSIZE} --rw=randwrite \
    --time_based --runtime=${RUNTIME} --direct=1 --ioengine=libaio --iodepth=${RNDIODEPTH} --output=${RUNID}-QD-${RNDIODEPTH}-rnd-write.out \
    $(for x in 1 2 ; do printf " --name=write%d --filename=%s/%s%d " ${x} "${MOUNT}" "${TESTFILENAMEPFX}" ${x} ; done)
  echo
  #sync_and_wait
fi
