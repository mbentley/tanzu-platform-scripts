# Tanzu Platform Tools

Example scripts and yaml for Tanzu Platform

Warning: this repo is very much a work in progress and things are likely to be in a mixed state of working and not working

## Tanzu Platform for Kubernetes Configuration

Steps:

In this example, I need to be able to run containers as root and have r/w container filesystems. This has instructions for creating the availability target, profile, space, and applying my policies.

### Availability Targets

```bash
tanzu project use AMER-East
tanzu deploy -y --only ./tp4k8s/availability-targets/mbentley-home-at.yaml
```

### Profiles

```bash
tanzu project use AMER-East
tanzu deploy -y --only ./tp4k8s/profiles/mbentley-profile.yaml
```

### Spaces

```bash
tanzu project use AMER-East
tanzu deploy -y --only ./tp4k8s/spaces/mbentley-space.yaml
```

### Policies

Set `pod-security.kubernetes.io/enforce` to `privileged` for namespaces with a `spaces.tanzu.vmware.com/name` label:

```bash
tanzu operations apply -f ./tp4k8s/policies/allow-privileged.yaml
```

Apply mutating policies to allow root and r/w filesystems for namespaces with a `spaces.tanzu.vmware.com/name` label:

```bash
tanzu operations apply -f ./tp4k8s/policies/allow-root-and-rw-fs.yaml
```
