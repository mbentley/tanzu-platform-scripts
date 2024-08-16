# Tanzu Platform Tools

Example scripts and yaml for Tanzu Platform

Warning: this repo is very much a work in progress and things are likely to be in a mixed state of working and not working

## Configuration & Deployment

In this example, I need to be able to run containers as root and have r/w container filesystems.

### Configuration

Set `pod-security.kubernetes.io/enforce` to `privileged` for namespaces with a `spaces.tanzu.vmware.com/name` label:

```bash
tanzu operations apply -f ./tp4k8s/policies/allow-privileged.yaml
```

Apply mutating policies to allow root and r/w filesystems for namespaces with a `spaces.tanzu.vmware.com/name` label:

```bash
tanzu operations apply -f ./tp4k8s/allow-root-and-rw-fs.yaml
```
