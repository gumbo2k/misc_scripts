#!/bin/sh

# Linux uses "_NPROCESSORS..." while BSD and macOS use "NPROCESSORS..."
if [ "$(uname)" = 'Linux' ] ; then 
  PREFIX='_'
fi
if CMDGETCONF=$(command -v getconf) ; then
  printf "getconf ${PREFIX}NPROCESSORS_ONLN / ${PREFIX}NPROCESSORS_CONF : %d / %d\n" "$(${CMDGETCONF} ${PREFIX}NPROCESSORS_ONLN)" "$(${CMDGETCONF} ${PREFIX}NPROCESSORS_CONF)"
else
  printf "getconf not installed.\n"
fi

# on XCP-ng / xenserver "--all" command will return VCPUs-max of a vm
if CMDNPROC=$(command -v nproc) ; then
  printf "nproc / nproc --all : %d / %d\n" "$(${CMDNPROC})" $(${CMDNPROC} --all)
else
  printf "nproc not installed.\n"
fi

# macOS
if [ "$(uname)" = 'Darwin' ] ; then
  printf "sysctl -n hw.logicalcpu_max / hw.physicalcpu_max : %d / %d\n" "$(sysctl -n hw.logicalcpu_max)" "$(sysctl -n hw.physicalcpu_max)"
fi

# lscpu
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

# check if limited by cgroups like in a container
# cgroup v1
# https://git.kernel.org/pub/scm/linux/kernel/git/tj/cgroup.git/tree/Documentation/admin-guide/cgroup-v1
if [ -e /sys/fs/cgroup/cpu/cpu.cfs_quota_us -a -e /sys/fs/cgroup/cpu/cpu.cfs_period_us ] ; then
  CFS_QUOTA_US=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
  CFS_PERIOD_US=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
fi
# cgroup v2
# https://git.kernel.org/pub/scm/linux/kernel/git/tj/cgroup.git/tree/Documentation/admin-guide/cgroup-v2.rst
if [ -e /sys/fs/cgroup/cpu.max ] ; then
  CFS_QUOTA_US=$(cat /sys/fs/cgroup/cpu.max | cut -f1 -d' ')
  CFS_PERIOD_US=$(cat /sys/fs/cgroup/cpu.max | cut -f2 -d' ')
fi
if [ -n "${CFS_QUOTA_US}" -a -n "${CFS_PERIOD_US}" ] ; then
  if [ "${CFS_QUOTA_US}" -ge 0 -a "${CFS_PERIOD_US}" -ge 0 ] ; then
    printf "cgroup cpu limitation : %d.%d\n" $(( CFS_QUOTA_US / CFS_PERIOD_US )) $(( CFS_QUOTA_US % CFS_PERIOD_US )) 
  fi
fi
