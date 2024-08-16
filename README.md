# Tanzu Platform Tools

Example scripts and yaml for Tanzu Platform

## Configuration & Deployment

In this example, I need to be able to run containers as root and have r/w container filesystems.

### Configuration

Set `pod-security.kubernetes.io/enforce` to `privileged` for namespaces with a `spaces.tanzu.vmware.com/name` label:

```bash
tanzu operations apply -f ./policies/allow-privileged.yaml
```

Apply mutating policies to allow root and r/w filesystems for namespaces with a `spaces.tanzu.vmware.com/name` label:

```bash
tanzu operations apply -f ./policies/allow-root-and-rw-fs.yaml
```

### App Deployment

Configure the build plan to use ucp (allowing for pre-built images to be used) and specify the registry path to put the containerapp definitions that are created:

```bash
tanzu build config \
  --build-plan-source-type=ucp \
  --containerapp-registry harbor.mbentley.net/mbentley/{name}
```

Deploy the defined `ContainerApp`s:

```bash
tanzu deploy -y
```
