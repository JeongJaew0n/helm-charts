# Tekton CI Helm Chart

Reusable Tekton CI/CD pipeline for building Kotlin/Spring Boot applications with Gradle and pushing Docker images to NCR (NHN Cloud Registry).

## Features

- 🚀 Automated CI pipeline: Git clone → Gradle build → Docker build → NCR push
- 🎯 GitHub webhook integration with Tekton Triggers
- 💾 Gradle cache support for faster builds
- 🔐 Secure NCR authentication
- 📦 Reusable across multiple projects
- ⚙️ Highly configurable via Helm values

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- **Tekton Pipelines** v0.50.0+ installed
- **Tekton Triggers** v0.25.0+ installed
- NCR (NHN Cloud Registry) credentials

### Install Tekton

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Install Tekton Triggers
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# Verify installation
kubectl get pods -n tekton-pipelines
```

## Quick Start

### 1. Prepare NCR Credentials

Get your NCR Access Key and Secret Key from NHN Cloud console.

### 2. Install the Chart

```bash
helm install my-app-ci ./tekton-ci \
  --set git.url=https://github.com/your-org/your-app.git \
  --set docker.imageName=your-registry/your-app \
  --set ncr.credentials.username=<NCR_ACCESS_KEY> \
  --set ncr.credentials.password=<NCR_SECRET_KEY> \
  -n tekton-pipelines
```

### 3. Get Webhook URL

```bash
# For LoadBalancer service type
kubectl get svc -n tekton-pipelines | grep listener

# The external IP is your webhook URL
# Example: http://203.0.113.10:8080
```

### 4. Configure GitHub Webhook

Go to your GitHub repository:

1. **Settings** → **Webhooks** → **Add webhook**
2. **Payload URL**: `http://<EXTERNAL-IP>:8080`
3. **Content type**: `application/json`
4. **Events**: Select "Just the push event"
5. **Active**: ✓

### 5. Test the Pipeline

Push a commit to the `main` branch, and the pipeline will automatically trigger!

Monitor the pipeline:

```bash
# Watch pipeline runs
kubectl get pipelinerun -n tekton-pipelines -w

# View logs (install tekton CLI: brew install tektoncd-cli)
tkn pipelinerun logs -f -n tekton-pipelines
```

## Configuration

### Git Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `git.url` | Git repository URL | `https://github.com/your-org/vanitas.git` |
| `git.revision` | Branch/tag/commit to build | `main` |
| `git.credentials.enabled` | Enable for private repos | `false` |
| `git.credentials.username` | Git username | `""` |
| `git.credentials.password` | Personal access token | `""` |

### Gradle Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gradle.version` | Gradle version | `8.5` |
| `gradle.javaVersion` | Java version | `17` |
| `gradle.buildArgs` | Gradle build arguments | `clean build -x test` |
| `gradle.cacheEnabled` | Enable Gradle cache PVC | `true` |
| `gradle.cache.size` | Cache PVC size | `5Gi` |

### Docker/NCR Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `docker.registry` | NCR registry URL | `kr-central-1.ncr.ntruss.com` |
| `docker.imageName` | Image name (without registry) | `your-registry/vanitas` |
| `docker.dockerfilePath` | Dockerfile path | `./Dockerfile` |
| `docker.contextPath` | Build context path | `.` |

### NCR Credentials (Required)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ncr.credentials.username` | NCR Access Key ID | `""` |
| `ncr.credentials.password` | NCR Secret Key | `""` |
| `ncr.credentials.email` | Email for docker config | `noreply@example.com` |

### Pipeline Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pipeline.resources.gitClone.requests.cpu` | Git clone CPU request | `100m` |
| `pipeline.resources.gitClone.requests.memory` | Git clone memory request | `128Mi` |
| `pipeline.resources.gradleBuild.requests.cpu` | Gradle build CPU request | `1000m` |
| `pipeline.resources.gradleBuild.requests.memory` | Gradle build memory request | `2Gi` |
| `pipeline.resources.gradleBuild.limits.memory` | Gradle build memory limit | `4Gi` |
| `pipeline.resources.dockerBuild.requests.cpu` | Docker build CPU request | `500m` |
| `pipeline.resources.dockerBuild.requests.memory` | Docker build memory request | `1Gi` |

### Triggers Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `triggers.enabled` | Enable Tekton Triggers | `true` |
| `triggers.eventListener.serviceType` | Service type (LoadBalancer/ClusterIP) | `LoadBalancer` |
| `triggers.github.enabled` | Enable GitHub webhook | `true` |
| `triggers.github.branches` | Branch filter | `[main]` |

## Usage Examples

### Install for a Different Project

```bash
helm install backend-ci ./tekton-ci \
  --set git.url=https://github.com/myorg/backend.git \
  --set docker.imageName=my-registry/backend \
  --set ncr.credentials.username=$NCR_KEY \
  --set ncr.credentials.password=$NCR_SECRET \
  -n tekton-pipelines
```

### Private Repository

```bash
helm install private-app-ci ./tekton-ci \
  --set git.url=https://github.com/myorg/private-app.git \
  --set git.credentials.enabled=true \
  --set git.credentials.username=myuser \
  --set git.credentials.password=$GITHUB_TOKEN \
  --set docker.imageName=my-registry/private-app \
  --set ncr.credentials.username=$NCR_KEY \
  --set ncr.credentials.password=$NCR_SECRET \
  -n tekton-pipelines
```

### Custom Gradle Build

```bash
helm install custom-ci ./tekton-ci \
  --set git.url=https://github.com/myorg/custom-app.git \
  --set gradle.version=8.7 \
  --set gradle.javaVersion=21 \
  --set gradle.buildArgs="clean build test jacocoTestReport" \
  --set docker.imageName=my-registry/custom-app \
  --set ncr.credentials.username=$NCR_KEY \
  --set ncr.credentials.password=$NCR_SECRET \
  -n tekton-pipelines
```

### Multiple Branches

Deploy separate pipelines for different branches:

```bash
# Dev pipeline
helm install app-dev-ci ./tekton-ci \
  --set git.revision=develop \
  --set triggers.github.branches[0]=develop \
  --set docker.imageName=my-registry/app-dev \
  -n tekton-pipelines

# Production pipeline
helm install app-prod-ci ./tekton-ci \
  --set git.revision=main \
  --set triggers.github.branches[0]=main \
  --set docker.imageName=my-registry/app \
  -n tekton-pipelines
```

## Manual Pipeline Execution

Trigger a pipeline run manually:

```bash
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: vanitas-ci-pipeline-manual-
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: vanitas-ci-pipeline
  serviceAccountName: tekton-ci-sa
  params:
    - name: git-url
      value: "https://github.com/your-org/vanitas.git"
    - name: git-revision
      value: "main"
    - name: image-name
      value: "your-registry/vanitas"
    - name: image-tag
      value: "manual-$(date +%Y%m%d-%H%M%S)"
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
    - name: gradle-cache
      persistentVolumeClaim:
        claimName: gradle-cache-pvc
    - name: docker-credentials
      secret:
        secretName: ncr-credentials
EOF
```

## Monitoring

### Watch Pipeline Runs

```bash
kubectl get pipelinerun -n tekton-pipelines -w
```

### View Pipeline Logs

With Tekton CLI:
```bash
tkn pipelinerun logs <pipelinerun-name> -f -n tekton-pipelines
```

With kubectl:
```bash
# List pods
kubectl get pods -n tekton-pipelines

# View logs
kubectl logs -f <pod-name> -n tekton-pipelines
```

### Check Built Images

Images are pushed to: `kr-central-1.ncr.ntruss.com/<image-name>:<tag>`

Tag format: Short commit SHA (first 7 characters)

Example: `kr-central-1.ncr.ntruss.com/my-registry/vanitas:abc1234`

## Troubleshooting

### Pipeline Run Fails at Git Clone

**Symptom**: Git clone task fails with authentication error

**Solution**: Enable git credentials for private repos
```bash
helm upgrade my-app-ci ./tekton-ci \
  --set git.credentials.enabled=true \
  --set git.credentials.username=myuser \
  --set git.credentials.password=$GITHUB_TOKEN \
  --reuse-values
```

### Gradle Build OOMKilled

**Symptom**: Gradle build pod is killed due to out of memory

**Solution**: Increase memory limits
```bash
helm upgrade my-app-ci ./tekton-ci \
  --set pipeline.resources.gradleBuild.limits.memory=6Gi \
  --reuse-values
```

### Docker Push Fails with Unauthorized

**Symptom**: Docker build/push fails with "unauthorized" error

**Solution**: Verify NCR credentials
```bash
# Test credentials locally
docker login kr-central-1.ncr.ntruss.com \
  -u <ACCESS_KEY> \
  -p <SECRET_KEY>

# Update credentials in chart
helm upgrade my-app-ci ./tekton-ci \
  --set ncr.credentials.username=<NEW_KEY> \
  --set ncr.credentials.password=<NEW_SECRET> \
  --reuse-values
```

### Webhook Not Triggering

**Symptom**: Push events don't trigger pipeline

**Solutions**:

1. Check EventListener service:
```bash
kubectl get svc -n tekton-pipelines | grep listener
```

2. Check webhook delivery in GitHub:
   - Go to repo → Settings → Webhooks
   - Check "Recent Deliveries" for errors

3. Check EventListener logs:
```bash
kubectl logs -l eventlistener=vanitas-listener -n tekton-pipelines
```

4. Verify branch filter matches:
```bash
# Pipeline only triggers for configured branches
# Check values: triggers.github.branches
```

### Gradle Cache Not Working

**Symptom**: Build is slow, dependencies downloaded every time

**Solution**: Verify PVC exists
```bash
kubectl get pvc gradle-cache-pvc -n tekton-pipelines

# If missing, ensure gradle.cacheEnabled=true
helm upgrade my-app-ci ./tekton-ci \
  --set gradle.cacheEnabled=true \
  --reuse-values
```

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│                                                              │
│  Push to main → Webhook → EventListener (LoadBalancer)      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Tekton Triggers                           │
│                                                              │
│  TriggerBinding → Extract git-url, commit-sha, branch       │
│  TriggerTemplate → Create PipelineRun                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Tekton Pipeline                           │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Git Clone   │ →  │ Gradle Build │ →  │ Docker Build │  │
│  │              │    │              │    │   & Push     │  │
│  │ Clone repo   │    │ Build JAR    │    │ Build image  │  │
│  │              │    │ with cache   │    │ Push to NCR  │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            NCR (NHN Cloud Registry)                         │
│                                                              │
│  Image: kr-central-1.ncr.ntruss.com/my-app:abc1234         │
└─────────────────────────────────────────────────────────────┘
```

## Security Considerations

1. **NCR Credentials**: Store securely, never commit to Git
   ```bash
   # Use environment variables
   export NCR_USERNAME="..."
   export NCR_PASSWORD="..."

   helm install ... \
     --set ncr.credentials.username=$NCR_USERNAME \
     --set ncr.credentials.password=$NCR_PASSWORD
   ```

2. **Git Credentials**: Use personal access tokens, not passwords

3. **Webhook Secret**: Enable webhook secret validation
   ```bash
   # Generate secret
   WEBHOOK_SECRET=$(openssl rand -base64 32)

   helm upgrade ... \
     --set triggers.webhook.secretEnabled=true \
     --set triggers.webhook.secretToken=$WEBHOOK_SECRET
   ```

4. **RBAC**: ServiceAccount has minimal required permissions

## Advanced Usage

### Custom Dockerfile Location

```bash
helm install ... \
  --set docker.dockerfilePath=./docker/Dockerfile \
  --set docker.contextPath=.
```

### Multi-Stage Builds

The pipeline supports multi-stage Dockerfiles. Example:

```dockerfile
# Stage 1: Build
FROM gradle:8.5-jdk17 AS builder
WORKDIR /app
COPY . .
RUN gradle clean build -x test

# Stage 2: Runtime
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Custom Storage Class

```bash
helm install ... \
  --set gradle.cache.storageClass=fast-ssd \
  --set gradle.cache.size=10Gi
```

## Upgrading

```bash
helm upgrade my-app-ci ./tekton-ci \
  -f my-values.yaml \
  -n tekton-pipelines
```

## Uninstalling

```bash
helm uninstall my-app-ci -n tekton-pipelines

# Optionally delete PVC
kubectl delete pvc gradle-cache-pvc -n tekton-pipelines
```

## Contributing

This chart is designed to be reusable. To adapt for other languages/frameworks:

1. Modify `task-gradle-build.yaml` for different build tools
2. Adjust `values.yaml` for new parameters
3. Update `pipeline.yaml` to use new tasks

## License

MIT License
