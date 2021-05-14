# fio k8s

Forked to have better defaults sourced from the [SRE
Handbook](https://s905060.gitbooks.io/site-reliability-engineer-handbook/content/fio.html).

# Proxmox 6.4 VE

My use case is to test a base install of the following stack:

 1. 3x Dell R620 servers
   * Each: CPU(s) 32 x Intel(R) Xeon(R) CPU E5-2670 0 @ 2.60GHz (2 Sockets)
   * 256 MB Ram
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

# Reference

Forked from [this post](https://medium.com/@joshua_robinson/storage-benchmarking-with-fio-in-kubernetes-14cf29dc5375)
