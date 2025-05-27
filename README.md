# misc_scripts

## fio_measure_device.sh

Measures IOPS (4K random access) and throughput (1M sequential) for single-client and multi-client loads.


## get_cpu_number.sh

Checks various ways and sources of detecting the CPU number:
* `getconf`
* `nproc`
* `sysctl`
* `lscpu`

Also checks for cgroup settings that show the cpu limitations inside containers:
* `/sys/fs/cgroup/cpu/cpu.cfs_quota_us`
* `/sys/fs/cgroup/cpu.max`
