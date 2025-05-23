#!/bin/sh

# Linux uses "_NPROCESSORS..." while BSD and macOS use "NPROCESSORS..."
if [ "$(uname)" = 'Linux' ] ; then 
  PREFIX='_'
fi
if CMDGETCONF=$(command -v getconf) ; then
  printf "getconf ${PREFIX}NPROCESSORS_ONLN / ${PREFIX}NPROCESSORS_CONF : %d / %d \n" "$(${CMDGETCONF} ${PREFIX}NPROCESSORS_ONLN)" "$(${CMDGETCONF} ${PREFIX}NPROCESSORS_CONF)"
else
  printf "getconf not installed.\n"
fi

if CMDNPROC=$(command -v nproc) ; then
  printf "nproc / nproc --all : %d / %d \n" "$(${CMDNPROC})" $(${CMDNPROC} --all)
else
  printf "nproc not installed.\n"
fi

# macOS
if [ "$(uname)" = 'Darwin' ] ; then
  printf "sysctl -n hw.logicalcpu_max / hw.physicalcpu_max : \n" "$(sysctl -n hw.logicalcpu_max)" "$(sysctl -n hw.physicalcpu_max)"
fi

#lscpu

if CMDLSCPU=$(command -v lscpu) ; then
  LCPUS=$(lscpu -p | grep -v '^#' | cut -f1 -d',' | sort -n | uniq | wc -l)
  CORES=$(lscpu -p | grep -v '^#' | cut -f2 -d',' | sort -n | uniq | wc -l)
  SOCKS=$(lscpu -p | grep -v '^#' | cut -f3 -d',' | sort -n | uniq | wc -l)
  NODES=$(lscpu -p | grep -v '^#' | cut -f4 -d',' | sort -n | uniq | wc -l)
  printf "lscpu CPUs / Cores / Sockets / Nodes : ${LCPUS} / ${CORES} / ${SOCKS} / ${NODES}\n"
  printf "lscpu --all --extended :\n"
  lscpu --all --extended
else
  printf "lscpu not installed.\n"
fi
