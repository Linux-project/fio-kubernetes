# fio k8s

Forked to have better defaults sourced from the [SRE
Handbook](https://s905060.gitbooks.io/site-reliability-engineer-handbook/content/fio.html).

# Usage

```
# Add the configmap
kubectl apply -f https://raw.githubusercontent.com/openinfrastructure/fio-kubernetes/master/configs.yaml
# Run the jobs for 60 seconds.
kubectl apply -f https://raw.githubusercontent.com/openinfrastructure/fio-kubernetes/master/fio.yaml
```

Collect the results using `kubectl get pods` and `kubectl logs`.

Clean up:

```
kubectl delete configmap/fio-job-config
kubectl delete job/fio
```

# Proxmox 6.4 VE

My use case is to test a base install of the following stack:

 1. 3x Dell R620 servers
   * Each: CPU(s) 32 x Intel(R) Xeon(R) CPU E5-2670 0 @ 2.60GHz (2 Sockets)
   * 256 MB Ram
   * PERC H710P
   * 4x 556GB SAAS drives
 2. Proxmox 6.4 VE
 3. ZFS Raid 10
 4. Debian 10 VM
 5. Kubernetes 1.21.0
 6. 3x controller nodes
 7. 4x worker nodes

With a relatively un-tuned system the system is brought to a halt.  The kube
API starts failing with errors related to etcd storage.  Luckily, deleting the
deployment quickly resolves the situation.

```
Error from server: etcdserver: request timed out
```

```
Error from server: etcdserver: leader changed
```

```
Error from server (InternalError): an error on the server ("") has prevented the request from succeeding (get pods fio-c8xm8)
```

# First Run in k8s (job1)

This run, all 7 of the nodes are Proxmox guest VM's running on zvols in Proxmox
6.4.  I think this what's causing the etcd timeouts according to [this
thread](https://forum.proxmox.com/threads/high-disk-io-overhead-for-clients-on-zfs.80151/)

The virtio scsi driver is used in the guest.

```
[global]
ioengine=libaio
iodepth=128
rw=randrw
bs=8K
direct=1
size=1G
numjobs=12
ramp_time=5
runtime=60
time_based
group_reporting
[job1]
```

```
❯ k get pods -o wide
NAME        READY   STATUS      RESTARTS   AGE     IP              NODE      NOMINATED NODE   READINESS GATES
fio-c8xm8   0/1     Completed   0          5m59s   10.65.91.73     k1-9f87   <none>           <none>
fio-g4vzl   0/1     Completed   0          5m59s   10.65.97.10     k1-8843   <none>           <none>
fio-lchqb   0/1     Completed   0          5m59s   10.65.128.202   k1-9e1c   <none>           <none>
```

```
# k logs fio-c8xm8
job1: (groupid=0, jobs=12): err= 0: pid=10: Fri May 14 04:48:08 2021
  read: IOPS=3099, BW=24.3MiB/s (25.5MB/s)(1469MiB/60441msec)
    slat (usec): min=6, max=3540.7k, avg=1558.36, stdev=20618.60
    clat (msec): min=2, max=8167, avg=249.77, stdev=519.20
     lat (msec): min=2, max=8168, avg=251.36, stdev=521.86
    clat percentiles (msec):
     |  1.00th=[   11],  5.00th=[   16], 10.00th=[   22], 20.00th=[   37],
     | 30.00th=[   56], 40.00th=[   80], 50.00th=[  108], 60.00th=[  146],
     | 70.00th=[  201], 80.00th=[  296], 90.00th=[  550], 95.00th=[  877],
     | 99.00th=[ 2467], 99.50th=[ 3876], 99.90th=[ 6812], 99.95th=[ 7416],
     | 99.99th=[ 7819]
   bw (  KiB/s): min=  298, max=134826, per=100.00%, avg=26346.06, stdev=2160.49, samples=1350
   iops        : min=   37, max=16853, avg=3292.96, stdev=270.05, samples=1350
  write: IOPS=3102, BW=24.3MiB/s (25.5MB/s)(1471MiB/60441msec); 0 zone resets
    slat (usec): min=7, max=2726.3k, avg=1544.94, stdev=20722.35
    clat (msec): min=3, max=8168, avg=263.67, stdev=533.98
     lat (msec): min=3, max=8168, avg=265.27, stdev=536.77
    clat percentiles (msec):
     |  1.00th=[   13],  5.00th=[   20], 10.00th=[   26], 20.00th=[   43],
     | 30.00th=[   62], 40.00th=[   87], 50.00th=[  116], 60.00th=[  155],
     | 70.00th=[  211], 80.00th=[  309], 90.00th=[  575], 95.00th=[  927],
     | 99.00th=[ 2500], 99.50th=[ 3876], 99.90th=[ 7215], 99.95th=[ 7416],
     | 99.99th=[ 7819]
   bw (  KiB/s): min=  259, max=138774, per=100.00%, avg=26411.35, stdev=2180.11, samples=1349
   iops        : min=   32, max=17346, avg=3301.10, stdev=272.51, samples=1349
  lat (msec)   : 4=0.01%, 10=0.73%, 20=6.52%, 50=18.50%, 100=20.62%
  lat (msec)   : 250=29.37%, 500=13.36%, 750=4.65%, 1000=2.33%, 2000=2.83%
  lat (msec)   : >=2000=1.50%
  cpu          : usr=0.54%, sys=0.93%, ctx=220001, majf=0, minf=699
  IO depths    : 1=0.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=187319,187496,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=24.3MiB/s (25.5MB/s), 24.3MiB/s-24.3MiB/s (25.5MB/s-25.5MB/s), io=1469MiB (1541MB), run=60441-60441msec
  WRITE: bw=24.3MiB/s (25.5MB/s), 24.3MiB/s-24.3MiB/s (25.5MB/s-25.5MB/s), io=1471MiB (1542MB), run=60441-60441msec

Disk stats (read/write):
  sda: ios=188636/188853, merge=6/176, ticks=27586579/28446782, in_queue=57486792, util=100.00%
```

```
# k logs fio-g4vzl
job1: (groupid=0, jobs=12): err= 0: pid=9: Fri May 14 04:46:14 2021
  read: IOPS=11.3k, BW=87.0MiB/s (92.3MB/s)(5284MiB/60051msec)
    slat (usec): min=5, max=251618, avg=423.78, stdev=2730.90
    clat (usec): min=252, max=1086.7k, avg=65384.45, stdev=74248.45
     lat (usec): min=312, max=1101.9k, avg=65812.03, stdev=74737.90
    clat percentiles (msec):
     |  1.00th=[    6],  5.00th=[    8], 10.00th=[    9], 20.00th=[   12],
     | 30.00th=[   18], 40.00th=[   27], 50.00th=[   40], 60.00th=[   56],
     | 70.00th=[   77], 80.00th=[  107], 90.00th=[  157], 95.00th=[  209],
     | 99.00th=[  347], 99.50th=[  418], 99.90th=[  600], 99.95th=[  684],
     | 99.99th=[  793]
   bw (  KiB/s): min= 9408, max=583781, per=98.87%, avg=89094.02, stdev=7590.92, samples=1428
   iops        : min= 1176, max=72965, avg=11135.63, stdev=948.77, samples=1428
  write: IOPS=11.3k, BW=88.0MiB/s (92.3MB/s)(5285MiB/60051msec); 0 zone resets
    slat (usec): min=6, max=194375, avg=428.54, stdev=2746.07
    clat (usec): min=1137, max=1086.7k, avg=70104.71, stdev=76850.28
     lat (usec): min=1159, max=1086.7k, avg=70537.12, stdev=77319.37
    clat percentiles (msec):
     |  1.00th=[    7],  5.00th=[    9], 10.00th=[   11], 20.00th=[   13],
     | 30.00th=[   21], 40.00th=[   31], 50.00th=[   44], 60.00th=[   61],
     | 70.00th=[   84], 80.00th=[  114], 90.00th=[  165], 95.00th=[  218],
     | 99.00th=[  359], 99.50th=[  430], 99.90th=[  609], 99.95th=[  693],
     | 99.99th=[  802]
   bw (  KiB/s): min=10160, max=578179, per=98.89%, avg=89121.73, stdev=7576.27, samples=1428
   iops        : min= 1270, max=72267, avg=11139.18, stdev=946.95, samples=1428
  lat (usec)   : 500=0.01%, 750=0.01%, 1000=0.01%
  lat (msec)   : 2=0.03%, 4=0.29%, 10=12.21%, 20=18.56%, 50=24.59%
  lat (msec)   : 100=21.52%, 250=19.79%, 500=2.86%, 750=0.22%, 1000=0.02%
  lat (msec)   : 2000=0.01%
  cpu          : usr=1.54%, sys=4.13%, ctx=1292901, majf=0, minf=711
  IO depths    : 1=0.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=675673,675692,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=87.0MiB/s (92.3MB/s), 87.0MiB/s-87.0MiB/s (92.3MB/s-92.3MB/s), io=5284MiB (5541MB), run=60051-60051msec
  WRITE: bw=88.0MiB/s (92.3MB/s), 88.0MiB/s-88.0MiB/s (92.3MB/s-92.3MB/s), io=5285MiB (5542MB), run=60051-60051msec

Disk stats (read/write):
  sda: ios=719725/720400, merge=233/373, ticks=26710138/28593412, in_queue=62634044, util=100.00%
```

```
# logs fio-lchqb
job1: (groupid=0, jobs=12): err= 0: pid=9: Fri May 14 04:48:26 2021
  read: IOPS=5104, BW=39.0MiB/s (41.9MB/s)(2402MiB/60079msec)
    slat (usec): min=6, max=802100, avg=966.58, stdev=8960.66
    clat (msec): min=3, max=2816, avg=145.48, stdev=208.61
     lat (msec): min=3, max=2816, avg=146.45, stdev=209.87
    clat percentiles (msec):
     |  1.00th=[    7],  5.00th=[   13], 10.00th=[   19], 20.00th=[   34],
     | 30.00th=[   51], 40.00th=[   69], 50.00th=[   88], 60.00th=[  110],
     | 70.00th=[  140], 80.00th=[  190], 90.00th=[  309], 95.00th=[  468],
     | 99.00th=[ 1116], 99.50th=[ 1485], 99.90th=[ 2123], 99.95th=[ 2232],
     | 99.99th=[ 2601]
   bw (  KiB/s): min=  591, max=141856, per=100.00%, avg=41109.57, stdev=2567.72, samples=1417
   iops        : min=   73, max=17732, avg=5138.41, stdev=320.96, samples=1417
  write: IOPS=5108, BW=40.0MiB/s (41.0MB/s)(2404MiB/60079msec); 0 zone resets
    slat (usec): min=7, max=762950, avg=983.32, stdev=8862.25
    clat (msec): min=3, max=2949, avg=154.51, stdev=213.48
     lat (msec): min=3, max=3083, avg=155.51, stdev=214.72
    clat percentiles (msec):
     |  1.00th=[   11],  5.00th=[   17], 10.00th=[   23], 20.00th=[   41],
     | 30.00th=[   57], 40.00th=[   77], 50.00th=[   95], 60.00th=[  117],
     | 70.00th=[  148], 80.00th=[  201], 90.00th=[  326], 95.00th=[  489],
     | 99.00th=[ 1150], 99.50th=[ 1502], 99.90th=[ 2123], 99.95th=[ 2265],
     | 99.99th=[ 2702]
   bw (  KiB/s): min=  527, max=141696, per=100.00%, avg=41117.14, stdev=2550.11, samples=1418
   iops        : min=   65, max=17712, avg=5139.34, stdev=318.76, samples=1418
  lat (msec)   : 4=0.01%, 10=2.18%, 20=7.21%, 50=18.45%, 100=26.55%
  lat (msec)   : 250=31.77%, 500=9.41%, 750=2.35%, 1000=1.03%, 2000=1.13%
  lat (msec)   : >=2000=0.15%
  cpu          : usr=0.84%, sys=1.54%, ctx=359679, majf=0, minf=699
  IO depths    : 1=0.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=306670,306939,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=39.0MiB/s (41.9MB/s), 39.0MiB/s-39.0MiB/s (41.9MB/s-41.9MB/s), io=2402MiB (2518MB), run=60079-60079msec
  WRITE: bw=40.0MiB/s (41.0MB/s), 40.0MiB/s-40.0MiB/s (41.0MB/s-41.0MB/s), io=2404MiB (2521MB), run=60079-60079msec

Disk stats (read/write):
  sda: ios=313580/314089, merge=19/178, ticks=25889231/27114911, in_queue=55047900, util=100.00%
```

Proxmox host job1
===

The same job1, but executed directly on the host using a ZFS dataset:

```
root@r620a:~# zpool status
  pool: rpool
 state: ONLINE
config:

	NAME                                              STATE     READ WRITE CKSUM
	rpool                                             ONLINE       0     0     0
	  mirror-0                                        ONLINE       0     0     0
	    scsi-36c81f660cc719400283053fb1893524f-part3  ONLINE       0     0     0
	    scsi-36c81f660cc7194002830540d19a51e68-part3  ONLINE       0     0     0
	  mirror-1                                        ONLINE       0     0     0
	    scsi-36c81f660cc719400283054211ae0d9c7-part3  ONLINE       0     0     0
	    scsi-36c81f660cc719400283054351c0eaefd-part3  ONLINE       0     0     0
```

```
testjob: (groupid=0, jobs=12): err= 0: pid=29763: Thu May 13 22:02:17 2021
  read: IOPS=2804, BW=22.0MiB/s (23.1MB/s)(1321MiB/60004msec)
    slat (nsec): min=0, max=3466.4k, avg=39298.56, stdev=24129.56
    clat (nsec): min=0, max=480676k, avg=270941882.56, stdev=38148652.68
     lat (nsec): min=0, max=480720k, avg=270981502.50, stdev=38150822.03
    clat percentiles (msec):
     |  1.00th=[  199],  5.00th=[  220], 10.00th=[  230], 20.00th=[  243],
     | 30.00th=[  251], 40.00th=[  259], 50.00th=[  268], 60.00th=[  275],
     | 70.00th=[  288], 80.00th=[  296], 90.00th=[  313], 95.00th=[  334],
     | 99.00th=[  397], 99.50th=[  414], 99.90th=[  443], 99.95th=[  456],
     | 99.99th=[  468]
   bw (  KiB/s): min=    0, max= 2656, per=8.30%, avg=1869.73, stdev=268.23, samples=1438
   iops        : min=    0, max=  332, avg=233.69, stdev=33.54, samples=1438
  write: IOPS=2808, BW=22.0MiB/s (23.1MB/s)(1323MiB/60004msec); 0 zone resets
    slat (nsec): min=0, max=45675k, avg=4224369.44, stdev=568060.37
    clat (nsec): min=0, max=480158k, avg=271049781.62, stdev=38197160.42
     lat (nsec): min=0, max=486997k, avg=275278475.52, stdev=38506306.73
    clat percentiles (msec):
     |  1.00th=[  199],  5.00th=[  220], 10.00th=[  230], 20.00th=[  243],
     | 30.00th=[  251], 40.00th=[  259], 50.00th=[  268], 60.00th=[  275],
     | 70.00th=[  288], 80.00th=[  296], 90.00th=[  313], 95.00th=[  334],
     | 99.00th=[  397], 99.50th=[  414], 99.90th=[  443], 99.95th=[  451],
     | 99.99th=[  464]
   bw (  KiB/s): min=    0, max= 2448, per=8.29%, avg=1872.18, stdev=219.02, samples=1438
   iops        : min=    0, max=  306, avg=234.00, stdev=27.39, samples=1438
  lat (usec)   : 10=0.01%, 20=0.01%
  lat (msec)   : 4=0.01%, 10=0.01%, 20=0.01%, 50=0.06%, 100=0.09%
  lat (msec)   : 250=28.81%, 500=71.46%
  cpu          : usr=0.27%, sys=2.73%, ctx=169053, majf=1, minf=183
  IO depths    : 1=0.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=168309,168539,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=22.0MiB/s (23.1MB/s), 22.0MiB/s-22.0MiB/s (23.1MB/s-23.1MB/s), io=1321MiB (1385MB), run=60004-60004msec
  WRITE: bw=22.0MiB/s (23.1MB/s), 22.0MiB/s-22.0MiB/s (23.1MB/s-23.1MB/s), io=1323MiB (1387MB), run=60004-60004msec
```

# Notes

Running the same job1 again, `zpool iostat 3` reports good write throughput:

```
              capacity     operations     bandwidth
pool        alloc   free   read  write   read  write
----------  -----  -----  -----  -----  -----  -----
rpool       49.0G  1.04T      0  15.9K      0   617M
rpool       49.0G  1.04T      0  3.42K      0   639M
rpool       49.0G  1.04T      0  17.5K      0   632M
rpool       49.0G  1.04T      0  2.32K      0   607M
rpool       49.0G  1.04T      0  16.6K      0   620M
rpool       49.0G  1.04T      0  9.26K      0   620M
rpool       53.1G  1.03T      0  9.65K      0   612M
rpool       53.1G  1.03T      0  9.19K      0   613M
rpool       53.1G  1.03T      0  8.67K      0   612M
rpool       53.1G  1.03T      0  8.83K      0   601M
rpool       53.1G  1.03T      0  10.1K      0   620M
rpool       53.1G  1.03T      0  18.1K      0   562M
rpool       57.1G  1.03T      0  14.2K      0   462M
rpool       57.1G  1.03T      0  17.2K      0   559M
rpool       57.1G  1.03T      0  4.79K      0   370M
rpool       57.1G  1.03T      0  2.32K      0   224M
rpool       57.1G  1.03T      0  2.25K      0   218M
rpool       57.1G  1.03T      0  5.92K      0   367M
rpool       57.1G  1.03T      0  12.5K      0   426M
rpool       57.1G  1.03T      0  11.9K      0   423M
rpool       57.1G  1.03T      0  1.44K      0   172M
rpool       58.7G  1.03T      0  1.72K      0   172M
rpool       58.7G  1.03T      0  2.58K      0   272M
rpool       58.7G  1.03T      0  2.63K      0   276M
rpool       58.7G  1.03T      0  2.98K      0   306M
rpool       58.7G  1.03T      0  5.51K      0   295M
rpool       58.7G  1.03T      0  9.81K      0   445M
rpool       58.7G  1.03T      0  2.57K      0   273M
rpool       58.7G  1.03T      0  3.13K      0   298M
rpool       58.7G  1.03T      0  4.10K      0   298M
rpool       58.7G  1.03T      0  2.34K      0   228M
rpool       58.7G  1.03T      0  5.12K      0   317M
rpool       58.7G  1.03T      0  3.29K      0   302M
rpool       58.7G  1.03T      0  7.20K      0   319M
rpool       60.2G  1.03T      0  10.1K      0   514M
rpool       60.2G  1.03T      0  4.14K      0   595M
rpool       58.3G  1.03T      0  3.52K      0   449M
rpool       58.3G  1.03T      0     20      0   370K
rpool       53.1G  1.03T      0    127      0  3.46M
rpool       53.1G  1.03T      0     19      0   285K
```

# PERC H710P replacement

See [H310/H710/H710P/H810 Mini & Full Size IT Crossflashing](https://fohdeesha.com/docs/perc/).

Comparison of the random read/write job1 between two configurations on the same node:

 1. Dell stock firmware for PERC H710P.
 2. LSI initiator target (IT) mode firmware.

The hypothesis is the 512MB of cache on the dell firmware is causing a large
IOPS backlog, which is too much latency for the k8s controller nodes.  etcd
leader writes specifically.

## Dell Firmware

Run on r620c with the dell firmware with write back cache enabled on each of
the 4 raid0 virtual disks.

During the fio run on Proxmox VM k1-bf30, the k1c controller node VM running on
the same Proxmost host starts to experience errors.  Visible with `kubectl logs
etcd-k1c -n kube-system -f`.

```
2021-05-14 16:47:28.068343 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2021-05-14 16:47:39.063518 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:47:40.070062 W | wal: sync duration of 2.004393954s, expected less than 1s
2021-05-14 16:47:40.074621 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (1.999933111s) to execute
2021-05-14 16:47:40.074684 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000075287s) to execute
2021-05-14 16:47:40.482463 W | etcdserver: request "header:<ID:11233518338286848764 username:\"kube-apiserver-etcd-client\" auth_revision:1 > lease_grant:<ttl:15-second id:1be57969336c8afb>" with result "size:43" took too long (411.876518ms) to execute
2021-05-14 16:47:40.512613 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (2.261772101s) to execute
2021-05-14 16:47:40.512996 W | etcdserver: read-only range request "key:\"/registry/volumeattachments/\" range_end:\"/registry/volumeattachments0\" count_only:true " with result "range_response_count:0 size:7" took too long (2.045778732s) to execute
2021-05-14 16:47:40.513146 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (426.493863ms) to execute
2021-05-14 16:47:40.513321 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (2.034494424s) to execute
2021-05-14 16:47:43.703769 W | wal: sync duration of 1.201165229s, expected less than 1s
2021-05-14 16:47:45.073659 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000097905s) to execute
WARNING: 2021/05/14 16:47:45 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:47:45.767148 W | wal: sync duration of 2.063208783s, expected less than 1s
2021-05-14 16:47:45.769730 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (2.917698182s) to execute
2021-05-14 16:47:45.771116 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (987.080106ms) to execute
2021-05-14 16:47:45.771404 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (689.519595ms) to execute
2021-05-14 16:47:45.772156 W | etcdserver: read-only range request "key:\"/registry/poddisruptionbudgets/\" range_end:\"/registry/poddisruptionbudgets0\" count_only:true " with result "range_response_count:0 size:9" took too long (313.320874ms) to execute
2021-05-14 16:47:49.066706 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:47:50.073968 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (1.999816027s) to execute
2021-05-14 16:47:50.074554 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (2.000335768s) to execute
WARNING: 2021/05/14 16:47:50 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:47:50.178348 W | wal: sync duration of 2.734074977s, expected less than 1s
2021-05-14 16:47:51.660219 W | wal: sync duration of 1.481505633s, expected less than 1s
2021-05-14 16:47:51.667422 W | etcdserver: read-only range request "key:\"/registry/namespaces/default\" " with result "range_response_count:1 size:343" took too long (4.21749112s) to execute
2021-05-14 16:47:51.671328 W | etcdserver: read-only range request "key:\"/registry/ingressclasses/\" range_end:\"/registry/ingressclasses0\" count_only:true " with result "range_response_count:0 size:7" took too long (2.997925961s) to execute
2021-05-14 16:47:51.671368 W | etcdserver: read-only range request "key:\"/registry/roles/\" range_end:\"/registry/roles0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.638685129s) to execute
2021-05-14 16:47:51.671458 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (3.292675654s) to execute
2021-05-14 16:47:51.671968 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (1.948710623s) to execute
2021-05-14 16:47:51.672066 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.587452648s) to execute
2021-05-14 16:47:51.672234 W | etcdserver: read-only range request "key:\"/registry/pods/\" range_end:\"/registry/pods0\" count_only:true " with result "range_response_count:0 size:9" took too long (4.037966221s) to execute
2021-05-14 16:47:51.672450 W | etcdserver: read-only range request "key:\"/registry/apm.k8s.elastic.co/apmservers/\" range_end:\"/registry/apm.k8s.elastic.co/apmservers0\" count_only:true " with result "range_response_count:0 size:7" took too long (490.308153ms) to execute
2021-05-14 16:47:51.674384 W | etcdserver: read-only range request "key:\"/registry/enterprisesearch.k8s.elastic.co/enterprisesearches/\" range_end:\"/registry/enterprisesearch.k8s.elastic.co/enterprisesearches0\" count_only:true " with result "range_response_count:0 size:7" took too long (2.011775706s) to execute
2021-05-14 16:47:56.073940 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.00005527s) to execute
2021-05-14 16:47:56.653048 W | wal: sync duration of 3.146738308s, expected less than 1s
2021-05-14 16:47:56.771375 W | etcdserver: request "header:<ID:519736299082878547 > lease_revoke:<id:1be57969336c8afb>" with result "size:31" took too long (117.442308ms) to execute
2021-05-14 16:47:56.780305 W | etcdserver: read-only range request "key:\"/registry/leases/\" range_end:\"/registry/leases0\" count_only:true " with result "range_response_count:0 size:9" took too long (2.818954211s) to execute
2021-05-14 16:47:56.781381 W | etcdserver: read-only range request "key:\"/registry/flowschemas/exempt\" " with result "range_response_count:1 size:881" took too long (2.431694823s) to execute
2021-05-14 16:47:56.781588 W | etcdserver: read-only range request "key:\"/registry/priorityclasses/\" range_end:\"/registry/priorityclasses0\" count_only:true " with result "range_response_count:0 size:9" took too long (494.969411ms) to execute
2021-05-14 16:47:56.781880 W | etcdserver: read-only range request "key:\"/registry/services/endpoints/kubernetes-dashboard/dashboard-metrics-scraper\" " with result "range_response_count:1 size:731" took too long (185.308379ms) to execute
2021-05-14 16:47:56.782087 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (697.552917ms) to execute
2021-05-14 16:47:56.782402 W | etcdserver: read-only range request "key:\"/registry/configmaps/\" range_end:\"/registry/configmaps0\" count_only:true " with result "range_response_count:0 size:9" took too long (830.787522ms) to execute
2021-05-14 16:47:56.783491 W | etcdserver: read-only range request "key:\"/registry/secrets/\" range_end:\"/registry/secrets0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.279636775s) to execute
2021-05-14 16:47:56.783921 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (1.611870772s) to execute
2021-05-14 16:47:56.784211 W | etcdserver: read-only range request "key:\"/registry/services/specs/\" range_end:\"/registry/services/specs0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.878266294s) to execute
2021-05-14 16:47:56.784481 W | etcdserver: read-only range request "key:\"/registry/ingress/\" range_end:\"/registry/ingress0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.855380479s) to execute
2021-05-14 16:47:56.784901 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (2.042504583s) to execute
2021-05-14 16:47:56.785160 W | etcdserver: read-only range request "key:\"/registry/ingress/\" range_end:\"/registry/ingress0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.703574878s) to execute
2021-05-14 16:47:58.073976 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2021-05-14 16:48:01.073915 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (1.999793156s) to execute
WARNING: 2021/05/14 16:48:01 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:48:01.700970 W | wal: sync duration of 2.692862574s, expected less than 1s
2021-05-14 16:48:01.861234 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (775.02307ms) to execute
2021-05-14 16:48:01.861431 W | etcdserver: read-only range request "key:\"/registry/replicasets/\" range_end:\"/registry/replicasets0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.424579997s) to execute
2021-05-14 16:48:01.861673 W | etcdserver: read-only range request "key:\"/registry/daemonsets/\" range_end:\"/registry/daemonsets0\" count_only:true " with result "range_response_count:0 size:9" took too long (162.257314ms) to execute
2021-05-14 16:48:01.861841 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (2.240889051s) to execute
2021-05-14 16:48:05.594378 W | wal: sync duration of 1.894286851s, expected less than 1s
2021-05-14 16:48:06.075458 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (1.999822484s) to execute
WARNING: 2021/05/14 16:48:06 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:48:08.084591 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.00004746s) to execute
2021-05-14 16:48:08.218408 W | wal: sync duration of 2.623595635s, expected less than 1s
2021-05-14 16:48:08.359222 W | etcdserver: request "header:<ID:11233518338286848945 username:\"kube-apiserver-etcd-client\" auth_revision:1 > txn:<compare:<target:MOD key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" mod_revision:2130505 > success:<request_put:<key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" value_size:522 >> failure:<>>" with result "size:20" took too long (140.154041ms) to execute
2021-05-14 16:48:08.373517 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2021-05-14 16:48:08.379442 W | etcdserver: read-only range request "key:\"/registry/jobs/\" range_end:\"/registry/jobs0\" count_only:true " with result "range_response_count:0 size:9" took too long (4.104346821s) to execute
2021-05-14 16:48:08.379871 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (288.648477ms) to execute
2021-05-14 16:48:08.380124 W | etcdserver: read-only range request "key:\"/registry/deployments/\" range_end:\"/registry/deployments0\" count_only:true " with result "range_response_count:0 size:9" took too long (2.90187721s) to execute
2021-05-14 16:48:08.380399 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (302.991875ms) to execute
2021-05-14 16:48:08.380714 W | etcdserver: read-only range request "key:\"/registry/namespaces/default\" " with result "range_response_count:1 size:343" took too long (928.401467ms) to execute
2021-05-14 16:48:08.381547 W | etcdserver: read-only range request "key:\"/registry/elasticsearch.k8s.elastic.co/elasticsearches/\" range_end:\"/registry/elasticsearch.k8s.elastic.co/elasticsearches0\" count_only:true " with result "range_response_count:0 size:7" took too long (3.112434664s) to execute
2021-05-14 16:48:08.381632 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (2.501435641s) to execute
2021-05-14 16:48:08.382144 W | etcdserver: read-only range request "key:\"/registry/rolebindings/\" range_end:\"/registry/rolebindings0\" count_only:true " with result "range_response_count:0 size:9" took too long (3.510267029s) to execute
2021-05-14 16:48:08.382859 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (3.909593314s) to execute
2021-05-14 16:48:12.074812 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000097059s) to execute
WARNING: 2021/05/14 16:48:12 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:48:13.947012 W | wal: sync duration of 3.201270291s, expected less than 1s
2021-05-14 16:48:13.947762 W | etcdserver: request "header:<ID:11233518338286848975 username:\"kube-apiserver-etcd-client\" auth_revision:1 > txn:<compare:<target:MOD key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" mod_revision:2130512 > success:<request_put:<key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" value_size:522 >> failure:<>>" with result "size:20" took too long (3.201838504s) to execute
2021-05-14 16:48:14.086703 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000163334s) to execute
2021-05-14 16:48:14.221461 W | etcdserver: read-only range request "key:\"/registry/runtimeclasses/\" range_end:\"/registry/runtimeclasses0\" count_only:true " with result "range_response_count:0 size:7" took too long (3.495616621s) to execute
2021-05-14 16:48:14.221533 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (120.354716ms) to execute
2021-05-14 16:48:14.222132 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (3.303652653s) to execute
2021-05-14 16:48:14.222208 W | etcdserver: read-only range request "key:\"/registry/events/\" range_end:\"/registry/events0\" count_only:true " with result "range_response_count:0 size:9" took too long (3.222538639s) to execute
2021-05-14 16:48:14.222737 W | etcdserver: read-only range request "key:\"/registry/csistoragecapacities/\" range_end:\"/registry/csistoragecapacities0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.74756842s) to execute
2021-05-14 16:48:14.223126 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (2.817382778s) to execute
2021-05-14 16:48:19.064094 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:48:19.723461 W | wal: sync duration of 2.260260776s, expected less than 1s
2021-05-14 16:48:19.893530 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.816992278s) to execute
2021-05-14 16:48:19.904353 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (360.43429ms) to execute
2021-05-14 16:48:19.904749 W | etcdserver: read-only range request "key:\"/registry/ingressclasses/\" range_end:\"/registry/ingressclasses0\" count_only:true " with result "range_response_count:0 size:7" took too long (642.285016ms) to execute
2021-05-14 16:48:19.905093 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/networkpolicies/\" range_end:\"/registry/crd.projectcalico.org/networkpolicies0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.32056446s) to execute
2021-05-14 16:48:19.905397 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.828616262s) to execute
2021-05-14 16:48:22.828626 W | wal: sync duration of 1.220041901s, expected less than 1s
2021-05-14 16:48:24.075014 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000075414s) to execute
2021-05-14 16:48:25.298470 W | wal: sync duration of 2.469547286s, expected less than 1s
2021-05-14 16:48:25.306358 W | etcdserver: read-only range request "key:\"/registry/services/endpoints/\" range_end:\"/registry/services/endpoints0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.821408643s) to execute
2021-05-14 16:48:25.306441 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (1.696113013s) to execute
2021-05-14 16:48:25.306502 W | etcdserver: read-only range request "key:\"/registry/resourcequotas/\" range_end:\"/registry/resourcequotas0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.458550475s) to execute
2021-05-14 16:48:25.306683 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:505" took too long (420.08481ms) to execute
2021-05-14 16:48:25.307325 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.221008478s) to execute
2021-05-14 16:48:29.063647 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:48:29.498144 W | wal: sync duration of 2.035124863s, expected less than 1s
2021-05-14 16:48:30.073833 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000048363s) to execute
2021-05-14 16:48:30.073978 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000116518s) to execute
2021-05-14 16:48:30.311372 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:505" took too long (2.656798046s) to execute
2021-05-14 16:48:30.314663 W | etcdserver: read-only range request "key:\"/registry/rolebindings/\" range_end:\"/registry/rolebindings0\" count_only:true " with result "range_response_count:0 size:9" took too long (2.610577698s) to execute
2021-05-14 16:48:30.314912 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (229.378784ms) to execute
2021-05-14 16:48:30.315166 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (1.029279538s) to execute
2021-05-14 16:48:30.315631 W | etcdserver: read-only range request "key:\"/registry/csinodes/\" range_end:\"/registry/csinodes0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.374788063s) to execute
2021-05-14 16:48:30.315886 W | etcdserver: read-only range request "key:\"/registry/beat.k8s.elastic.co/beats/\" range_end:\"/registry/beat.k8s.elastic.co/beats0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.047840404s) to execute
2021-05-14 16:48:34.677629 W | wal: sync duration of 2.157039294s, expected less than 1s
2021-05-14 16:48:35.072925 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000091976s) to execute
2021-05-14 16:48:35.629220 W | etcdserver: request "header:<ID:519736299082878764 > lease_revoke:<id:510d79690b060722>" with result "size:31" took too long (951.333828ms) to execute
2021-05-14 16:48:35.700603 W | wal: sync duration of 1.02278617s, expected less than 1s
2021-05-14 16:48:35.704415 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:505" took too long (2.882976411s) to execute
2021-05-14 16:48:35.706290 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (2.769937461s) to execute
2021-05-14 16:48:35.706354 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (621.857896ms) to execute
2021-05-14 16:48:35.706545 W | etcdserver: read-only range request "key:\"/registry/poddisruptionbudgets/\" range_end:\"/registry/poddisruptionbudgets0\" count_only:true " with result "range_response_count:0 size:9" took too long (687.209083ms) to execute
2021-05-14 16:48:35.706845 W | etcdserver: read-only range request "key:\"/registry/namespaces/\" range_end:\"/registry/namespaces0\" count_only:true " with result "range_response_count:0 size:9" took too long (397.601456ms) to execute
2021-05-14 16:48:35.706865 W | etcdserver: read-only range request "key:\"/registry/clusterrolebindings/\" range_end:\"/registry/clusterrolebindings0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.521254619s) to execute
2021-05-14 16:48:35.707018 W | etcdserver: read-only range request "key:\"/registry/clusterroles/\" range_end:\"/registry/clusterroles0\" count_only:true " with result "range_response_count:0 size:9" took too long (528.475448ms) to execute
2021-05-14 16:48:35.707124 W | etcdserver: read-only range request "key:\"/registry/ingress/\" range_end:\"/registry/ingress0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.888495463s) to execute
2021-05-14 16:48:35.707343 W | etcdserver: read-only range request "key:\"/registry/horizontalpodautoscalers/\" range_end:\"/registry/horizontalpodautoscalers0\" count_only:true " with result "range_response_count:0 size:7" took too long (2.523678135s) to execute
2021-05-14 16:48:37.937598 W | etcdserver: read-only range request "key:\"/registry/persistentvolumeclaims/\" range_end:\"/registry/persistentvolumeclaims0\" count_only:true " with result "range_response_count:0 size:7" took too long (296.490442ms) to execute
2021-05-14 16:48:39.063879 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:48:40.077491 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (1.999985333s) to execute
WARNING: 2021/05/14 16:48:40 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:48:40.077698 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000045557s) to execute
WARNING: 2021/05/14 16:48:40 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:48:40.579897 W | wal: sync duration of 2.515287274s, expected less than 1s
2021-05-14 16:48:41.432226 W | etcdserver: request "header:<ID:11233518338286849148 username:\"kube-apiserver-etcd-client\" auth_revision:1 > txn:<compare:<target:MOD key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" mod_revision:2130585 > success:<request_put:<key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" value_size:522 >> failure:<>>" with result "size:20" took too long (851.871312ms) to execute
2021-05-14 16:48:41.497708 W | etcdserver: read-only range request "key:\"/registry/validatingwebhookconfigurations/\" range_end:\"/registry/validatingwebhookconfigurations0\" count_only:true " with result "range_response_count:0 size:9" took too long (2.908214002s) to execute
2021-05-14 16:48:41.497802 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.409157538s) to execute
2021-05-14 16:48:41.498438 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (1.513382525s) to execute
2021-05-14 16:48:41.498584 W | etcdserver: read-only range request "key:\"/registry/networkpolicies/\" range_end:\"/registry/networkpolicies0\" count_only:true " with result "range_response_count:0 size:7" took too long (2.626543682s) to execute
2021-05-14 16:48:41.498825 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:505" took too long (2.368925277s) to execute
2021-05-14 16:48:44.400828 W | etcdserver: read-only range request "key:\"/registry/certificatesigningrequests/\" range_end:\"/registry/certificatesigningrequests0\" count_only:true " with result "range_response_count:0 size:7" took too long (105.508839ms) to execute
2021-05-14 16:48:49.063667 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:48:50.082171 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.00009962s) to execute
2021-05-14 16:48:50.082848 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (2.000677569s) to execute
WARNING: 2021/05/14 16:48:50 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:48:50.755798 W | wal: sync duration of 3.292073398s, expected less than 1s
2021-05-14 16:48:52.092354 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (1.999986972s) to execute
2021-05-14 16:48:53.212714 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "error:context deadline exceeded" took too long (4.994528585s) to execute
2021-05-14 16:48:54.104468 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000070932s) to execute
2021-05-14 16:48:54.620244 W | etcdserver: timed out waiting for read index response (local node might have slow network)
2021-05-14 16:48:54.620456 W | etcdserver: read-only range request "key:\"/registry/persistentvolumes/\" range_end:\"/registry/persistentvolumes0\" count_only:true " with result "error:etcdserver: request timed out" took too long (7.000598776s) to execute
2021-05-14 16:48:54.661744 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "error:context canceled" took too long (4.9943588s) to execute
WARNING: 2021/05/14 16:48:54 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:48:56.116967 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000011027s) to execute
2021-05-14 16:48:58.126565 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000114166s) to execute
2021-05-14 16:48:59.063665 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:49:00.074357 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (1.99998013s) to execute
WARNING: 2021/05/14 16:49:00 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:00.134105 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000063271s) to execute
2021-05-14 16:49:00.333552 W | wal: sync duration of 9.57730431s, expected less than 1s
2021-05-14 16:49:00.439600 W | etcdserver: ignored out-of-date read index response; local node read indexes queueing up and waiting to be in sync with leader (request ID want 15063829820687648635, got 15063829820687648630)
2021-05-14 16:49:00.484946 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/kubecontrollersconfigurations/\" range_end:\"/registry/crd.projectcalico.org/kubecontrollersconfigurations0\" count_only:true " with result "range_response_count:0 size:9" took too long (9.559154555s) to execute
2021-05-14 16:49:00.485151 W | etcdserver: read-only range request "key:\"/registry/flowschemas/exempt\" " with result "range_response_count:1 size:881" took too long (6.134903437s) to execute
2021-05-14 16:49:00.485552 W | etcdserver: read-only range request "key:\"/registry/events/\" range_end:\"/registry/events0\" count_only:true " with result "range_response_count:0 size:9" took too long (11.028761784s) to execute
2021-05-14 16:49:00.981660 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "error:context canceled" took too long (4.994961352s) to execute
WARNING: 2021/05/14 16:49:00 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:02.144566 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000066404s) to execute
WARNING: 2021/05/14 16:49:02 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:02.342322 W | wal: sync duration of 1.857681007s, expected less than 1s
2021-05-14 16:49:02.353904 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "error:context deadline exceeded" took too long (4.994882026s) to execute
2021-05-14 16:49:04.156768 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (1.999971009s) to execute
WARNING: 2021/05/14 16:49:04 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:04.602303 W | wal: sync duration of 1.780658921s, expected less than 1s
2021-05-14 16:49:04.638035 W | etcdserver: request "header:<ID:11233518338286849296 username:\"kube-apiserver-etcd-client\" auth_revision:1 > txn:<compare:<target:MOD key:\"/registry/leases/kube-system/kube-controller-manager\" mod_revision:2130651 > success:<request_put:<key:\"/registry/leases/kube-system/kube-controller-manager\" value_size:425 >> failure:<>>" with result "size:20" took too long (1.816238952s) to execute
2021-05-14 16:49:04.639385 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/bgpconfigurations/\" range_end:\"/registry/crd.projectcalico.org/bgpconfigurations0\" count_only:true " with result "range_response_count:0 size:9" took too long (7.556052557s) to execute
2021-05-14 16:49:04.639481 W | etcdserver: read-only range request "key:\"/registry/prioritylevelconfigurations/\" range_end:\"/registry/prioritylevelconfigurations0\" count_only:true " with result "range_response_count:0 size:9" took too long (6.056164089s) to execute
2021-05-14 16:49:04.639735 W | etcdserver: read-only range request "key:\"/registry/namespaces/default\" " with result "range_response_count:1 size:343" took too long (6.878527672s) to execute
2021-05-14 16:49:04.639815 W | etcdserver: read-only range request "key:\"/registry/enterprisesearch.k8s.elastic.co/enterprisesearches/\" range_end:\"/registry/enterprisesearch.k8s.elastic.co/enterprisesearches0\" count_only:true " with result "range_response_count:0 size:7" took too long (5.609663817s) to execute
2021-05-14 16:49:04.640084 W | etcdserver: read-only range request "key:\"/registry/services/endpoints/kubernetes-dashboard/dashboard-metrics-scraper\" " with result "range_response_count:1 size:731" took too long (7.834224269s) to execute
2021-05-14 16:49:04.640375 W | etcdserver: read-only range request "key:\"/registry/csinodes/\" range_end:\"/registry/csinodes0\" count_only:true " with result "range_response_count:0 size:9" took too long (7.966897734s) to execute
2021-05-14 16:49:04.640647 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/clusterinformations/\" range_end:\"/registry/crd.projectcalico.org/clusterinformations0\" count_only:true " with result "range_response_count:0 size:9" took too long (8.640585048s) to execute
2021-05-14 16:49:04.640772 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/ipamhandles/\" range_end:\"/registry/crd.projectcalico.org/ipamhandles0\" count_only:true " with result "range_response_count:0 size:9" took too long (8.558093266s) to execute
2021-05-14 16:49:04.727681 W | etcdserver: read-only range request "key:\"/registry/priorityclasses/\" range_end:\"/registry/priorityclasses0\" count_only:true " with result "range_response_count:0 size:9" took too long (855.607029ms) to execute
2021-05-14 16:49:04.727738 W | etcdserver: read-only range request "key:\"/registry/csidrivers/\" range_end:\"/registry/csidrivers0\" count_only:true " with result "range_response_count:0 size:7" took too long (584.216911ms) to execute
2021-05-14 16:49:04.727754 W | etcdserver: read-only range request "key:\"/registry/statefulsets/\" range_end:\"/registry/statefulsets0\" count_only:true " with result "range_response_count:0 size:9" took too long (4.010953902s) to execute
2021-05-14 16:49:04.727824 W | etcdserver: read-only range request "key:\"/registry/runtimeclasses/\" range_end:\"/registry/runtimeclasses0\" count_only:true " with result "range_response_count:0 size:7" took too long (611.397079ms) to execute
2021-05-14 16:49:04.727922 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/ipamblocks/\" range_end:\"/registry/crd.projectcalico.org/ipamblocks0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.337282133s) to execute
2021-05-14 16:49:04.727982 W | etcdserver: read-only range request "key:\"/registry/roles/\" range_end:\"/registry/roles0\" count_only:true " with result "range_response_count:0 size:9" took too long (2.914807893s) to execute
2021-05-14 16:49:04.728240 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (557.571921ms) to execute
2021-05-14 16:49:04.728872 W | etcdserver: read-only range request "key:\"/registry/flowschemas/catch-all\" " with result "range_response_count:1 size:992" took too long (4.24042777s) to execute
2021-05-14 16:49:04.729188 W | etcdserver: read-only range request "key:\"/registry/services/specs/\" range_end:\"/registry/services/specs0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.690302452s) to execute
2021-05-14 16:49:07.402235 W | wal: sync duration of 1.462896631s, expected less than 1s
2021-05-14 16:49:08.073681 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (1.999985883s) to execute
WARNING: 2021/05/14 16:49:08 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:09.064533 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:49:09.584379 W | wal: sync duration of 2.18193608s, expected less than 1s
2021-05-14 16:49:09.665525 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (2.761369279s) to execute
2021-05-14 16:49:09.665823 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.586397027s) to execute
2021-05-14 16:49:09.665950 W | etcdserver: read-only range request "key:\"/registry/namespaces/default\" " with result "range_response_count:1 size:343" took too long (1.903892037s) to execute
2021-05-14 16:49:09.666193 W | etcdserver: read-only range request "key:\"/registry/validatingwebhookconfigurations/\" range_end:\"/registry/validatingwebhookconfigurations0\" count_only:true " with result "range_response_count:0 size:9" took too long (2.628056857s) to execute
2021-05-14 16:49:09.666464 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/globalnetworkpolicies/\" range_end:\"/registry/crd.projectcalico.org/globalnetworkpolicies0\" count_only:true " with result "range_response_count:0 size:7" took too long (2.706834961s) to execute
2021-05-14 16:49:09.666809 W | etcdserver: read-only range request "key:\"/registry/apiregistration.k8s.io/apiservices/\" range_end:\"/registry/apiregistration.k8s.io/apiservices0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.560084337s) to execute
2021-05-14 16:49:09.667211 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.583823466s) to execute
2021-05-14 16:49:13.073740 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000058503s) to execute
WARNING: 2021/05/14 16:49:13 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:15.086823 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000051952s) to execute
2021-05-14 16:49:15.378800 W | wal: sync duration of 4.031454592s, expected less than 1s
2021-05-14 16:49:15.810105 W | etcdserver: request "header:<ID:519736299082878991 username:\"kube-apiserver-etcd-client\" auth_revision:1 > txn:<compare:<target:MOD key:\"/registry/leases/kube-system/kube-scheduler\" mod_revision:2130680 > success:<request_put:<key:\"/registry/leases/kube-system/kube-scheduler\" value_size:407 >> failure:<>>" with result "size:20" took too long (429.891089ms) to execute
2021-05-14 16:49:15.969003 W | etcdserver: read-only range request "key:\"/registry/enterprisesearch.k8s.elastic.co/enterprisesearches/\" range_end:\"/registry/enterprisesearch.k8s.elastic.co/enterprisesearches0\" count_only:true " with result "range_response_count:0 size:7" took too long (873.376464ms) to execute
2021-05-14 16:49:15.969211 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:479" took too long (2.006104876s) to execute
2021-05-14 16:49:15.969287 W | etcdserver: read-only range request "key:\"/registry/elasticsearch.k8s.elastic.co/elasticsearches/\" range_end:\"/registry/elasticsearch.k8s.elastic.co/elasticsearches0\" count_only:true " with result "range_response_count:0 size:7" took too long (2.338498303s) to execute
2021-05-14 16:49:15.969455 W | etcdserver: read-only range request "key:\"/registry/pods/\" range_end:\"/registry/pods0\" count_only:true " with result "range_response_count:0 size:9" took too long (5.463094809s) to execute
2021-05-14 16:49:15.969668 W | etcdserver: read-only range request "key:\"/registry/apm.k8s.elastic.co/apmservers/\" range_end:\"/registry/apm.k8s.elastic.co/apmservers0\" count_only:true " with result "range_response_count:0 size:7" took too long (4.79487292s) to execute
2021-05-14 16:49:15.969772 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (2.111609347s) to execute
2021-05-14 16:49:15.969999 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (871.066461ms) to execute
2021-05-14 16:49:15.970322 W | etcdserver: read-only range request "key:\"/registry/clusterroles/\" range_end:\"/registry/clusterroles0\" count_only:true " with result "range_response_count:0 size:9" took too long (4.288067468s) to execute
2021-05-14 16:49:18.022490 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (1.949752766s) to execute
2021-05-14 16:49:18.022777 W | etcdserver: read-only range request "key:\"/registry/podsecuritypolicy/\" range_end:\"/registry/podsecuritypolicy0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.143156114s) to execute
2021-05-14 16:49:18.835142 W | wal: sync duration of 1.255294798s, expected less than 1s
2021-05-14 16:49:18.996797 W | etcdserver: read-only range request "key:\"/registry/events/\" range_end:\"/registry/events0\" count_only:true " with result "range_response_count:0 size:9" took too long (1.340122701s) to execute
2021-05-14 16:49:18.997224 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2021-05-14 16:49:18.998935 W | etcdserver: read-only range request "key:\"/registry/namespaces/default\" " with result "range_response_count:1 size:343" took too long (1.236363322s) to execute
2021-05-14 16:49:18.999228 W | etcdserver: read-only range request "key:\"/registry/jobs/\" range_end:\"/registry/jobs0\" count_only:true " with result "range_response_count:0 size:9" took too long (858.86211ms) to execute
2021-05-14 16:49:18.999249 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (963.891504ms) to execute
2021-05-14 16:49:18.999470 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (924.524932ms) to execute
2021-05-14 16:49:20.364030 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (289.353928ms) to execute
2021-05-14 16:49:20.364500 W | etcdserver: read-only range request "key:\"/registry/controllerrevisions/\" range_end:\"/registry/controllerrevisions0\" count_only:true " with result "range_response_count:0 size:9" took too long (154.52095ms) to execute
2021-05-14 16:49:23.511639 W | wal: sync duration of 1.461066482s, expected less than 1s
2021-05-14 16:49:24.076800 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (1.999974565s) to execute
2021-05-14 16:49:26.089361 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.00007326s) to execute
2021-05-14 16:49:27.615878 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "error:context deadline exceeded" took too long (4.992140627s) to execute
2021-05-14 16:49:28.102476 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.00005594s) to execute
2021-05-14 16:49:28.164726 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "error:context deadline exceeded" took too long (4.997777754s) to execute
2021-05-14 16:49:29.063978 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:49:29.076952 W | etcdserver: timed out waiting for read index response (local node might have slow network)
2021-05-14 16:49:30.079768 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context canceled" took too long (2.000102351s) to execute
WARNING: 2021/05/14 16:49:30 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:30.110348 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000087703s) to execute
2021-05-14 16:49:31.656676 W | etcdserver: request "header:<ID:519736299082879050 > lease_revoke:<id:1be57969336c8d2b>" with result "size:31" took too long (7.40507015s) to execute
2021-05-14 16:49:32.123097 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000041697s) to execute
2021-05-14 16:49:33.645506 W | wal: sync duration of 9.394062782s, expected less than 1s
2021-05-14 16:49:33.645713 W | etcdserver: ignored out-of-date read index response; local node read indexes queueing up and waiting to be in sync with leader (request ID want 15063829820687648694, got 15063829820687648692)
2021-05-14 16:49:34.135119 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000075521s) to execute
2021-05-14 16:49:35.526275 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "error:context deadline exceeded" took too long (4.989718551s) to execute
2021-05-14 16:49:35.616130 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "error:context deadline exceeded" took too long (4.999097682s) to execute
2021-05-14 16:49:36.150220 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000050859s) to execute
2021-05-14 16:49:36.584513 W | etcdserver: request "header:<ID:11233518338286849425 username:\"kube-apiserver-etcd-client\" auth_revision:1 > txn:<compare:<target:MOD key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" mod_revision:2130714 > success:<request_put:<key:\"/registry/configmaps/elastic-system/elastic-operator-leader\" value_size:522 >> failure:<>>" with result "size:20" took too long (2.938613222s) to execute
2021-05-14 16:49:38.161285 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000620744s) to execute
2021-05-14 16:49:39.064278 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:49:40.082108 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000038949s) to execute
2021-05-14 16:49:40.168229 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000054166s) to execute
2021-05-14 16:49:40.645941 W | etcdserver: timed out waiting for read index response (local node might have slow network)
2021-05-14 16:49:40.646425 W | etcdserver: read-only range request "key:\"/registry/namespaces/default\" " with result "error:etcdserver: request timed out" took too long (12.883884409s) to execute
2021-05-14 16:49:40.647197 W | etcdserver: read-only range request "key:\"/registry/volumeattachments/\" range_end:\"/registry/volumeattachments0\" count_only:true " with result "error:etcdserver: request timed out" took too long (15.406929413s) to execute
2021-05-14 16:49:40.647641 W | etcdserver: read-only range request "key:\"/registry/namespaces/kube-system\" " with result "error:etcdserver: request timed out" took too long (13.961243348s) to execute
2021-05-14 16:49:40.648286 W | etcdserver: read-only range request "key:\"/registry/ingress/\" range_end:\"/registry/ingress0\" count_only:true " with result "error:etcdserver: request timed out" took too long (13.411354081s) to execute
2021-05-14 16:49:40.648931 W | etcdserver: read-only range request "key:\"/registry/apm.k8s.elastic.co/apmservers/\" range_end:\"/registry/apm.k8s.elastic.co/apmservers0\" count_only:true " with result "error:etcdserver: request timed out" took too long (13.51900025s) to execute
2021-05-14 16:49:40.650184 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/globalnetworksets/\" range_end:\"/registry/crd.projectcalico.org/globalnetworksets0\" count_only:true " with result "error:etcdserver: request timed out" took too long (15.685898862s) to execute
2021-05-14 16:49:40.650277 W | etcdserver: read-only range request "key:\"/registry/controllers/\" range_end:\"/registry/controllers0\" count_only:true " with result "error:etcdserver: request timed out" took too long (12.932561198s) to execute
2021-05-14 16:49:40.651731 W | etcdserver: read-only range request "key:\"/registry/volumeattachments/\" range_end:\"/registry/volumeattachments0\" count_only:true " with result "error:etcdserver: request timed out" took too long (17.408487848s) to execute
2021-05-14 16:49:40.652917 W | etcdserver: read-only range request "key:\"/registry/agent.k8s.elastic.co/agents/\" range_end:\"/registry/agent.k8s.elastic.co/agents0\" count_only:true " with result "error:etcdserver: request timed out" took too long (13.781726054s) to execute
2021-05-14 16:49:42.180545 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.002610296s) to execute
2021-05-14 16:49:43.215513 W | wal: sync duration of 9.562235964s, expected less than 1s
2021-05-14 16:49:43.393932 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "error:context deadline exceeded" took too long (4.994221095s) to execute
2021-05-14 16:49:43.518417 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "error:context deadline exceeded" took too long (5.00190156s) to execute
WARNING: 2021/05/14 16:49:43 grpc: Server.processUnaryRPC failed to write status: connection error: desc = "transport is closing"
2021-05-14 16:49:44.192568 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000051535s) to execute
2021-05-14 16:49:45.621262 W | etcdserver: request "header:<ID:519736299082879117 username:\"kube-apiserver-etcd-client\" auth_revision:1 > lease_grant:<ttl:15-second id:073679690bb6108c>" with result "size:43" took too long (2.405260194s) to execute
2021-05-14 16:49:46.204952 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000040975s) to execute
2021-05-14 16:49:47.646473 W | etcdserver: timed out waiting for read index response (local node might have slow network)
2021-05-14 16:49:47.646646 W | etcdserver: read-only range request "key:\"/registry/services/endpoints/kubernetes-dashboard/dashboard-metrics-scraper\" " with result "error:etcdserver: request timed out" took too long (12.908440857s) to execute
2021-05-14 16:49:47.646746 W | etcdserver: read-only range request "key:\"/registry/minions/\" range_end:\"/registry/minions0\" count_only:true " with result "error:etcdserver: request timed out" took too long (9.247493768s) to execute
2021-05-14 16:49:47.646797 W | etcdserver: read-only range request "key:\"/registry/beat.k8s.elastic.co/beats/\" range_end:\"/registry/beat.k8s.elastic.co/beats0\" count_only:true " with result "error:etcdserver: request timed out" took too long (9.41115545s) to execute
2021-05-14 16:49:47.646857 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/bgppeers/\" range_end:\"/registry/crd.projectcalico.org/bgppeers0\" count_only:true " with result "error:etcdserver: request timed out" took too long (9.838826583s) to execute
2021-05-14 16:49:47.646923 W | etcdserver: read-only range request "key:\"/registry/kibana.k8s.elastic.co/kibanas/\" range_end:\"/registry/kibana.k8s.elastic.co/kibanas0\" count_only:true " with result "error:etcdserver: request timed out" took too long (10.549874392s) to execute
2021-05-14 16:49:47.647107 W | etcdserver: read-only range request "key:\"/registry/replicasets/\" range_end:\"/registry/replicasets0\" count_only:true " with result "error:etcdserver: request timed out" took too long (13.170239305s) to execute
2021-05-14 16:49:47.647191 W | etcdserver: read-only range request "key:\"/registry/elasticsearch.k8s.elastic.co/elasticsearches/\" range_end:\"/registry/elasticsearch.k8s.elastic.co/elasticsearches0\" count_only:true " with result "error:etcdserver: request timed out" took too long (16.824675011s) to execute
2021-05-14 16:49:47.647241 W | etcdserver: read-only range request "key:\"/registry/cronjobs/\" range_end:\"/registry/cronjobs0\" count_only:true " with result "error:etcdserver: request timed out" took too long (17.19567264s) to execute
2021-05-14 16:49:47.647290 W | etcdserver: read-only range request "key:\"/registry/poddisruptionbudgets/\" range_end:\"/registry/poddisruptionbudgets0\" count_only:true " with result "error:etcdserver: request timed out" took too long (17.725938344s) to execute
2021-05-14 16:49:47.647364 W | etcdserver: read-only range request "key:\"/registry/mutatingwebhookconfigurations/\" range_end:\"/registry/mutatingwebhookconfigurations0\" count_only:true " with result "error:etcdserver: request timed out" took too long (18.235532272s) to execute
2021-05-14 16:49:47.648050 W | etcdserver: read-only range request "key:\"/registry/mutatingwebhookconfigurations/\" range_end:\"/registry/mutatingwebhookconfigurations0\" count_only:true " with result "error:etcdserver: request timed out" took too long (15.063260338s) to execute
2021-05-14 16:49:47.648230 W | etcdserver: read-only range request "key:\"/registry/storageclasses/\" range_end:\"/registry/storageclasses0\" count_only:true " with result "error:etcdserver: request timed out" took too long (13.609552656s) to execute
2021-05-14 16:49:47.648327 W | etcdserver: read-only range request "key:\"/registry/flowschemas/\" range_end:\"/registry/flowschemas0\" count_only:true " with result "error:etcdserver: request timed out" took too long (7.757600938s) to execute
2021-05-14 16:49:47.648357 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/felixconfigurations/\" range_end:\"/registry/crd.projectcalico.org/felixconfigurations0\" count_only:true " with result "error:etcdserver: request timed out" took too long (7.762523582s) to execute
2021-05-14 16:49:47.648388 W | etcdserver: read-only range request "key:\"/registry/daemonsets/\" range_end:\"/registry/daemonsets0\" count_only:true " with result "error:etcdserver: request timed out" took too long (8.246352159s) to execute
2021-05-14 16:49:47.648603 W | etcdserver: read-only range request "key:\"/registry/serviceaccounts/\" range_end:\"/registry/serviceaccounts0\" count_only:true " with result "error:etcdserver: request timed out" took too long (7.480614055s) to execute
2021-05-14 16:49:47.648830 W | etcdserver: read-only range request "key:\"/registry/csidrivers/\" range_end:\"/registry/csidrivers0\" count_only:true " with result "error:etcdserver: request timed out" took too long (14.257050374s) to execute
2021-05-14 16:49:47.648890 W | etcdserver: read-only range request "key:\"/registry/apiextensions.k8s.io/customresourcedefinitions/\" range_end:\"/registry/apiextensions.k8s.io/customresourcedefinitions0\" count_only:true " with result "error:etcdserver: request timed out" took too long (15.017829888s) to execute
2021-05-14 16:49:47.648945 W | etcdserver: read-only range request "key:\"/registry/runtimeclasses/\" range_end:\"/registry/runtimeclasses0\" count_only:true " with result "error:etcdserver: request timed out" took too long (14.648260593s) to execute
2021-05-14 16:49:47.649610 W | etcdserver: read-only range request "key:\"/registry/crd.projectcalico.org/blockaffinities/\" range_end:\"/registry/crd.projectcalico.org/blockaffinities0\" count_only:true " with result "error:etcdserver: request timed out" took too long (9.200458048s) to execute
2021-05-14 16:49:48.213220 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000075478s) to execute
2021-05-14 16:49:49.064158 W | etcdserver/api/etcdhttp: /health error; QGET failed etcdserver: request timed out (status code 503)
2021-05-14 16:49:50.079197 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.002538287s) to execute
2021-05-14 16:49:50.220564 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "error:context deadline exceeded" took too long (2.000009565s) to execute
2021-05-14 16:49:50.769246 W | wal: sync duration of 7.545806347s, expected less than 1s
2021-05-14 16:49:50.770157 W | etcdserver: ignored out-of-date read index response; local node read indexes queueing up and waiting to be in sync with leader (request ID want 15063829820687648697, got 15063829820687648694)
2021-05-14 16:49:50.831324 W | etcdserver: ignored out-of-date read index response; local node read indexes queueing up and waiting to be in sync with leader (request ID want 15063829820687648697, got 15063829820687648696)
2021-05-14 16:49:50.958218 W | etcdserver: read-only range request "key:\"/registry/ingressclasses/\" range_end:\"/registry/ingressclasses0\" count_only:true " with result "range_response_count:0 size:7" took too long (4.342815807s) to execute
2021-05-14 16:49:50.958608 W | etcdserver: read-only range request "key:\"/registry/ingress/\" range_end:\"/registry/ingress0\" count_only:true " with result "range_response_count:0 size:7" took too long (9.924264295s) to execute
2021-05-14 16:49:50.958879 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-scheduler\" " with result "range_response_count:1 size:478" took too long (4.924103368s) to execute
2021-05-14 16:49:50.959191 W | etcdserver: read-only range request "key:\"/registry/apm.k8s.elastic.co/apmservers/\" range_end:\"/registry/apm.k8s.elastic.co/apmservers0\" count_only:true " with result "range_response_count:0 size:7" took too long (9.874018968s) to execute
2021-05-14 16:49:50.959446 W | etcdserver: read-only range request "key:\"/registry/leases/kube-system/kube-controller-manager\" " with result "range_response_count:1 size:506" took too long (5.028923626s) to execute
2021-05-14 16:49:50.959707 W | etcdserver: read-only range request "key:\"/registry/ingressclasses/\" range_end:\"/registry/ingressclasses0\" count_only:true " with result "range_response_count:0 size:7" took too long (6.832726863s) to execute
2021-05-14 16:49:50.961944 W | etcdserver: read-only range request "key:\"/registry/resourcequotas/default/\" range_end:\"/registry/resourcequotas/default0\" " with result "range_response_count:0 size:7" took too long (10.298997938s) to execute
2021-05-14 16:49:50.963150 W | etcdserver: read-only range request "key:\"/registry/resourcequotas/kube-system/\" range_end:\"/registry/resourcequotas/kube-system0\" " with result "range_response_count:0 size:7" took too long (10.30849744s) to execute
2021-05-14 16:49:50.991326 W | etcdserver: read-only range request "key:\"/registry/namespaces/kube-public\" " with result "range_response_count:1 size:353" took too long (327.607593ms) to execute
2021-05-14 16:49:50.991432 W | etcdserver: read-only range request "key:\"/registry/certificatesigningrequests/\" range_end:\"/registry/certificatesigningrequests0\" count_only:true " with result "range_response_count:0 size:7" took too long (385.238359ms) to execute
2021-05-14 16:49:50.991999 W | etcdserver: read-only range request "key:\"/registry/cronjobs/\" range_end:\"/registry/cronjobs0\" count_only:true " with result "range_response_count:0 size:7" took too long (1.137777288s) to execute
2021-05-14 16:49:50.992271 W | etcdserver: read-only range request "key:\"/registry/validatingwebhookconfigurations/\" range_end:\"/registry/validatingwebhookconfigurations0\" count_only:true " with result "range_response_count:0 size:9" took too long (3.132753024s) to execute
2021-05-14 16:49:50.992752 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (761.430242ms) to execute
2021-05-14 16:49:50.994553 W | etcdserver: read-only range request "key:\"/registry/namespaces/default\" " with result "range_response_count:1 size:343" took too long (330.558717ms) to execute
2021-05-14 16:49:51.186894 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (113.35076ms) to execute
2021-05-14 16:49:54.479204 W | etcdserver: read-only range request "key:\"/registry/flowschemas/exempt\" " with result "range_response_count:1 size:881" took too long (129.508259ms) to execute
2021-05-14 16:49:56.197387 W | etcdserver: read-only range request "key:\"/registry/health\" " with result "range_response_count:0 size:7" took too long (122.866438ms) to execute
2021-05-14 16:49:58.068341 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2021-05-14 16:50:08.068906 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2021-05-14 16:50:18.068762 I | etcdserver/api/etcdhttp: /health OK (status code 200)
2021-05-14 16:50:28.068471 I | etcdserver/api/etcdhttp: /health OK (status code 200)
```

```
testjob: (groupid=0, jobs=12): err= 0: pid=10: Fri May 14 16:43:23 2021
  read: IOPS=10.1k, BW=79.1MiB/s (82.0MB/s)(4751MiB/60053msec)
    slat (usec): min=5, max=382179, avg=463.84, stdev=3584.34
    clat (usec): min=735, max=1863.9k, avg=72486.63, stdev=97045.23
     lat (usec): min=780, max=1863.9k, avg=72953.53, stdev=97707.59
    clat percentiles (msec):
     |  1.00th=[    5],  5.00th=[    7], 10.00th=[    9], 20.00th=[   14],
     | 30.00th=[   21], 40.00th=[   33], 50.00th=[   45], 60.00th=[   59],
     | 70.00th=[   78], 80.00th=[  105], 90.00th=[  159], 95.00th=[  232],
     | 99.00th=[  493], 99.50th=[  625], 99.90th=[ 1003], 99.95th=[ 1116],
     | 99.99th=[ 1351]
   bw (  KiB/s): min= 2830, max=504550, per=98.84%, avg=80065.34, stdev=6278.23, samples=1428
   iops        : min=  352, max=63063, avg=10007.24, stdev=784.71, samples=1428
  write: IOPS=10.1k, BW=79.1MiB/s (82.9MB/s)(4750MiB/60053msec); 0 zone resets
    slat (usec): min=6, max=349939, avg=470.04, stdev=3621.64
    clat (usec): min=1291, max=1864.0k, avg=78277.90, stdev=101175.43
     lat (usec): min=1314, max=1910.4k, avg=78751.05, stdev=101814.17
    clat percentiles (msec):
     |  1.00th=[    7],  5.00th=[    9], 10.00th=[   11], 20.00th=[   17],
     | 30.00th=[   25], 40.00th=[   37], 50.00th=[   50], 60.00th=[   64],
     | 70.00th=[   84], 80.00th=[  112], 90.00th=[  169], 95.00th=[  247],
     | 99.00th=[  510], 99.50th=[  651], 99.90th=[ 1036], 99.95th=[ 1183],
     | 99.99th=[ 1418]
   bw (  KiB/s): min= 2831, max=508061, per=98.83%, avg=80046.54, stdev=6311.22, samples=1428
   iops        : min=  353, max=63503, avg=10004.93, stdev=788.84, samples=1428
  lat (usec)   : 750=0.01%, 1000=0.01%
  lat (msec)   : 2=0.01%, 4=0.39%, 10=11.56%, 20=15.01%, 50=25.51%
  lat (msec)   : 100=25.07%, 250=17.97%, 500=3.59%, 750=0.70%, 1000=0.20%
  lat (msec)   : 2000=0.11%
  cpu          : usr=1.40%, sys=3.56%, ctx=1090869, majf=0, minf=713
  IO depths    : 1=0.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=607356,607215,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=79.1MiB/s (82.0MB/s), 79.1MiB/s-79.1MiB/s (82.0MB/s-82.0MB/s), io=4751MiB (4982MB), run=60053-60053msec
  WRITE: bw=79.1MiB/s (82.9MB/s), 79.1MiB/s-79.1MiB/s (82.9MB/s-82.9MB/s), io=4750MiB (4981MB), run=60053-60053msec

Disk stats (read/write):
  sda: ios=660161/660256, merge=172/341, ticks=28084610/30045312, in_queue=61318072, util=100.00%
```

# Reference

Forked from [this post](https://medium.com/@joshua_robinson/storage-benchmarking-with-fio-in-kubernetes-14cf29dc5375)
