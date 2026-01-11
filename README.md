# Helm Charts Repository

This repository contains Helm charts for deploying applications and CI/CD pipelines to Kubernetes.

## Available Charts

### 📦 [vanitas](./vanitas/)

Helm chart for deploying the Vanitas Kotlin/Spring Boot application.

**Features:**
- Production-ready deployment configuration
- Horizontal Pod Autoscaling (HPA)
- Spring Boot Actuator health checks
- Ingress support with TLS
- Configurable resources and environment variables

**Quick Start:**
```bash
helm install vanitas ./vanitas \
  --set image.repository=kr-central-1.ncr.ntruss.com/my-registry/vanitas \
  --set image.tag=abc1234
```

[📖 Full Documentation](./vanitas/README.md)

---

### 🚀 [tekton-ci](./tekton-ci/)

Reusable Tekton CI/CD pipeline for building Kotlin/Spring Boot applications and pushing to NCR (NHN Cloud Registry).

**Features:**
- Automated CI: Git clone → Gradle build → Docker build → NCR push
- GitHub webhook integration with Tekton Triggers
- Gradle cache for faster builds
- Highly configurable and reusable across projects
- Secure NCR authentication

**Quick Start:**
```bash
helm install my-app-ci ./tekton-ci \
  --set git.url=https://github.com/your-org/your-app.git \
  --set docker.imageName=your-registry/your-app \
  --set ncr.credentials.username=$NCR_ACCESS_KEY \
  --set ncr.credentials.password=$NCR_SECRET_KEY \
  -n tekton-pipelines
```

[📖 Full Documentation](./tekton-ci/README.md)

---

## Prerequisites

### For Application Deployment (vanitas)
- Kubernetes 1.19+
- Helm 3.0+

### For CI/CD Pipeline (tekton-ci)
- Kubernetes 1.20+
- Helm 3.0+
- Tekton Pipelines v0.50.0+
- Tekton Triggers v0.25.0+
- NCR (NHN Cloud Registry) credentials

## Repository Structure

```
helm-charts/
├── README.md                    # This file
├── IMPLEMENTATION_PLAN.md       # Detailed implementation plan
├── vanitas/                     # Application Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── README.md
└── tekton-ci/                   # CI/CD Pipeline Helm chart
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    └── README.md
```

## Complete Workflow Example

### 1. Install Tekton

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Install Tekton Triggers
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# Verify
kubectl get pods -n tekton-pipelines
```

### 2. Deploy CI Pipeline

```bash
helm install vanitas-ci ./tekton-ci \
  --set git.url=https://github.com/your-org/vanitas.git \
  --set docker.imageName=your-registry/vanitas \
  --set ncr.credentials.username=$NCR_ACCESS_KEY \
  --set ncr.credentials.password=$NCR_SECRET_KEY \
  -n tekton-pipelines
```

### 3. Configure GitHub Webhook

```bash
# Get webhook URL
kubectl get svc -n tekton-pipelines | grep listener

# Configure in GitHub:
# Settings → Webhooks → Add webhook
# Payload URL: http://<EXTERNAL-IP>:8080
# Content type: application/json
# Events: Push events
```

### 4. Trigger Build

Push a commit to the `main` branch. The pipeline will automatically:
1. Clone the repository
2. Build with Gradle
3. Build Docker image
4. Push to NCR with commit SHA as tag

### 5. Deploy Application

```bash
# Get the image tag from the pipeline
IMAGE_TAG=$(kubectl get pipelinerun <pipelinerun-name> \
  -n tekton-pipelines \
  -o jsonpath='{.status.pipelineResults[?(@.name=="git-commit")].value}')

# Deploy the application
helm install vanitas ./vanitas \
  --set image.repository=kr-central-1.ncr.ntruss.com/your-registry/vanitas \
  --set image.tag=${IMAGE_TAG}
```

### 6. Access Application

```bash
# Port forward for testing
kubectl port-forward svc/vanitas 8080:8080

# Visit http://localhost:8080
curl http://localhost:8080/actuator/health
```

## Chart Versioning

Charts follow semantic versioning:
- **Major**: Breaking changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes

Current versions:
- `vanitas`: v0.1.0
- `tekton-ci`: v0.1.0

## Development

### Linting Charts

```bash
# Lint vanitas chart
helm lint ./vanitas

# Lint tekton-ci chart
helm lint ./tekton-ci
```

### Testing Charts

```bash
# Dry run vanitas
helm install vanitas-test ./vanitas --dry-run --debug

# Dry run tekton-ci
helm install tekton-test ./tekton-ci \
  --dry-run --debug \
  --set git.url=https://github.com/test/test.git \
  --set ncr.credentials.username=test \
  --set ncr.credentials.password=test
```

### Rendering Templates

```bash
# Render vanitas templates
helm template vanitas ./vanitas --output-dir /tmp/vanitas

# Render tekton-ci templates
helm template tekton-ci ./tekton-ci \
  --set git.url=https://github.com/test/test.git \
  --output-dir /tmp/tekton-ci
```

## Troubleshooting

### Common Issues

#### Tekton not installed
```bash
# Error: no matches for kind "Pipeline" in version "tekton.dev/v1beta1"
# Solution: Install Tekton Pipelines and Triggers (see Prerequisites)
```

#### NCR authentication fails
```bash
# Error: unauthorized: authentication required
# Solution: Verify NCR credentials and ensure they're correctly set
docker login kr-central-1.ncr.ntruss.com -u <key> -p <secret>
```

#### Gradle build fails with OOM
```bash
# Solution: Increase memory limits in tekton-ci
helm upgrade tekton-ci ./tekton-ci \
  --set pipeline.resources.gradleBuild.limits.memory=6Gi \
  --reuse-values
```

#### Webhook not triggering
```bash
# Check EventListener service
kubectl get svc -n tekton-pipelines | grep listener

# Check webhook delivery in GitHub
# Repository → Settings → Webhooks → Recent Deliveries
```

## Best Practices

### Security
- Never commit credentials to Git
- Use Kubernetes Secrets or external secret managers
- Enable webhook secret validation for production
- Use least-privilege RBAC policies

### Resource Management
- Set appropriate resource requests and limits
- Use HPA for automatic scaling
- Enable Gradle cache for faster builds
- Monitor resource usage

### CI/CD
- Use commit SHA for image tags (immutable, traceable)
- Implement proper health checks
- Test in staging before production
- Keep build logs for troubleshooting

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the charts
5. Submit a pull request

## Support

For issues and questions:
- Create an issue in this repository
- Check the documentation in each chart's README
- Review the [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) for detailed architecture

## License

MIT License

## Maintainers

- **HeLLo2** - popt0@naver.com
