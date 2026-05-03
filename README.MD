# DevOps Test Assignment

## Overview

This project contains Ansible playbooks for automated deployment of a small infrastructure on Debian-based containers.

The infrastructure includes:
- nginx static web server
- nginx reverse proxy with caching
- 5-node etcd cluster
- custom health-check daemon
- daemontools + multilog for process supervision
- basic monitoring setup

The environment was first configured manually to verify correct behavior and then automated using Ansible.

---

## Infrastructure

Virtual machines used in the setup:

- web-1 — nginx static server + etcd (172.30.0.11)  
- proxy-1 — nginx reverse proxy + etcd (172.30.0.12)  
- monitor-1 — health-check daemon + etcd (172.30.0.13)  
- node-4 — etcd (172.30.0.14)  
- node-5 — etcd (172.30.0.15)  

---

## Implemented Components

### nginx
- static web server running on web-1
- reverse proxy on proxy-1
- caching enabled via proxy_cache

### etcd cluster
- 5-node cluster
- uses Raft consensus
- cluster health verified
- supports fault tolerance (quorum-based)

### custom daemon
- collects:
  - system load
  - nginx stub_status
- outputs structured logs
- deployed on monitor-1

### supervision
- daemontools used for process supervision
- multilog used for logging

### monitoring
- Prometheus and exporters were configured and tested manually
- Ansible role is included as a basic skeleton

---

## How to Run

### Requirements

This project is designed to run with **Podman**.

Required on the host machine:

- Linux host
- Ansible
- Podman
- SSH client
- sudo privileges

The containers are Debian-based and run `systemd` as PID 1 (`/sbin/init`). Because of this, the deployment uses rootful Podman through Ansible `become: true`.

On Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y ansible podman
```

On Fedora/RHEL:

```bash
sudo dnf install -y ansible podman
```

---

### Run deployment

Run the playbook from the project root directory:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -K
```

The `-K` option is needed if the current user requires a sudo password.

Alternatively, the playbook can be executed as root:

```bash
sudo ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

The project uses fixed container IP addresses, so no manual inventory changes are required.

| Node | Role | IP |
|---|---|---|
| web-1 | nginx static server + etcd | 172.30.0.11 |
| proxy-1 | nginx reverse proxy + etcd | 172.30.0.12 |
| monitor-1 | health-check daemon + etcd | 172.30.0.13 |
| node-4 | etcd | 172.30.0.14 |
| node-5 | etcd | 172.30.0.15 |

The optional script `scripts/setup_inv.sh` is only needed if the IP addresses should be changed dynamically.

---

## Verification

### Container status

```bash
sudo podman ps -a
```

Expected result: all five containers should be in the `Up` state.

---

### nginx static web server

```bash
curl http://172.30.0.11
```

Expected result: HTML page from `web-1`.

---

### nginx reverse proxy

```bash
curl -I http://172.30.0.12
```

Expected result:

```text
HTTP/1.1 200 OK
```

---

### nginx status endpoints

```bash
sudo podman exec -it monitor-1 curl http://172.30.0.11/nginx_status
sudo podman exec -it monitor-1 curl http://172.30.0.12/nginx_status
```

Expected result:

```text
Active connections: ...
server accepts handled requests
Reading: ... Writing: ... Waiting: ...
```

---

### health-check daemon

```bash
sudo podman exec -it monitor-1 svstat /service/health-check
sudo podman exec -it monitor-1 tail -n 30 /var/log/health-check/current
```

Expected log content:

```text
type=load
type=nginx | service=nginx-web
type=nginx | service=nginx-proxy
HTTP/1.1 200 OK
Active connections: ...
```

---

### etcd cluster health

```bash
sudo podman exec -it web-1 etcdctl \
  --endpoints=http://172.30.0.11:2379,http://172.30.0.12:2379,http://172.30.0.13:2379,http://172.30.0.14:2379,http://172.30.0.15:2379 \
  endpoint health
```

Expected result: all five endpoints should be healthy.

Cluster members can be listed with:

```bash
sudo podman exec -it web-1 etcdctl \
  --endpoints=http://172.30.0.11:2379 \
  member list
```

---

## Additional Test: etcd Quorum / Fault Tolerance

The etcd cluster has 5 nodes.

A 5-node Raft cluster requires a quorum of 3 nodes, so it can tolerate up to 2 failed nodes.

Stop etcd on two nodes:

```bash
sudo podman exec -it node-4 systemctl stop etcd
sudo podman exec -it node-5 systemctl stop etcd
```

Check cluster health:

```bash
sudo podman exec -it web-1 etcdctl \
  --endpoints=http://172.30.0.11:2379,http://172.30.0.12:2379,http://172.30.0.13:2379,http://172.30.0.14:2379,http://172.30.0.15:2379 \
  endpoint health
```

The stopped nodes should be reported as unhealthy, while the remaining three nodes should stay healthy.

Verify that the cluster can still accept writes:

```bash
sudo podman exec -it web-1 etcdctl \
  --endpoints=http://172.30.0.11:2379,http://172.30.0.12:2379,http://172.30.0.13:2379 \
  put test-key "cluster-survived-two-failed-nodes"
```

Read the value back:

```bash
sudo podman exec -it web-1 etcdctl \
  --endpoints=http://172.30.0.11:2379,http://172.30.0.12:2379,http://172.30.0.13:2379 \
  get test-key
```

Restore the stopped nodes:

```bash
sudo podman exec -it node-4 systemctl start etcd
sudo podman exec -it node-5 systemctl start etcd
```

After a few seconds, all five endpoints should become healthy again.