# Vanitas Chart 상세 설명

## 개요

Vanitas는 Kotlin/Spring Boot 기반 웹 애플리케이션을 Kubernetes에 배포하기 위한 Helm chart입니다. Production-ready 설정을 기본으로 제공하며, HPA, Ingress, Health Check 등을 지원합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                        Ingress (optional)                    │ │
│  │                    vanitas.example.com                       │ │
│  └──────────────────────────┬──────────────────────────────────┘ │
│                             │                                     │
│  ┌──────────────────────────▼──────────────────────────────────┐ │
│  │                     Service (ClusterIP)                      │ │
│  │                        :8080                                 │ │
│  └──────────────────────────┬──────────────────────────────────┘ │
│                             │                                     │
│  ┌──────────────────────────▼──────────────────────────────────┐ │
│  │                       Deployment                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │ │
│  │  │   Pod 1     │  │   Pod 2     │  │   Pod N     │          │ │
│  │  │  (vanitas)  │  │  (vanitas)  │  │  (vanitas)  │   ◄── HPA│ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘          │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                             │                                     │
│  ┌──────────────────────────▼──────────────────────────────────┐ │
│  │                       ConfigMap                              │ │
│  │  SPRING_PROFILES_ACTIVE, JAVA_OPTS, custom configs           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 생성되는 Kubernetes 리소스

| 리소스 | 파일 | 조건 | 설명 |
|--------|------|------|------|
| Deployment | deployment.yaml | 항상 | 애플리케이션 Pod 관리 |
| Service | service.yaml | 항상 | ClusterIP 서비스 노출 |
| ConfigMap | configmap.yaml | 항상 | 환경 변수 설정 |
| ServiceAccount | serviceaccount.yaml | `serviceAccount.create=true` | Pod 실행 계정 |
| Ingress | ingress.yaml | `ingress.enabled=true` | 외부 HTTP 라우팅 |
| HPA | hpa.yaml | `autoscaling.enabled=true` | 자동 스케일링 |

## 템플릿 상세

### deployment.yaml

```yaml
주요 기능:
- ConfigMap 변경 시 자동 재배포 (checksum/config annotation)
- imagePullSecrets 지원 (private registry)
- Pod/Container Security Context
- Liveness/Readiness Probe (Spring Actuator)
- Resource limits/requests
- nodeSelector, tolerations, affinity 지원
```

**중요 설정:**
- `image.repository`: 컨테이너 이미지 저장소
- `image.tag`: 이미지 태그 (미설정 시 Chart.appVersion 사용)
- HPA 활성화 시 `replicas` 필드는 제외됨

### configmap.yaml

Pod에 주입되는 환경 변수:
- `SPRING_PROFILES_ACTIVE`: Spring Boot 프로파일 (기본: `prod`)
- `JAVA_OPTS`: JVM 옵션 (기본: `-Xmx768m -Xms512m -XX:+UseG1GC`)
- `config.customConfig`: 사용자 정의 key-value 설정

### hpa.yaml

자동 스케일링 설정:
- API Version: `autoscaling/v2`
- CPU/Memory 기반 스케일링
- 기본: 2~10 replicas, CPU 70%, Memory 80%

### ingress.yaml

- Ingress Class 지원 (`className`)
- TLS 설정 가능
- 다중 호스트/경로 지원

## values.yaml 구조

```yaml
# 기본 배포 설정
replicaCount: 2                    # HPA 비활성화 시 사용

# 이미지 설정
image:
  repository: kr-central-1.ncr.ntruss.com/your-registry/vanitas
  pullPolicy: IfNotPresent
  tag: ""                          # 빈 값 = Chart.appVersion 사용

# 보안 설정
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]

# 서비스 설정
service:
  type: ClusterIP
  port: 8080
  targetPort: 8080

# 리소스 제한
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

# 오토스케일링
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Health Check (Spring Boot Actuator)
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: http
  initialDelaySeconds: 60         # JVM 시작 시간 고려

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: http
  initialDelaySeconds: 30

# 애플리케이션 설정
config:
  springProfiles: "prod"
  javaOpts: "-Xmx768m -Xms512m -XX:+UseG1GC"
  customConfig: {}
```

## 헬퍼 함수 (_helpers.tpl)

| 함수 | 용도 | 예시 출력 |
|------|------|-----------|
| `vanitas.name` | Chart 이름 | `vanitas` |
| `vanitas.fullname` | 전체 리소스 이름 | `my-release-vanitas` |
| `vanitas.chart` | Chart 라벨 값 | `vanitas-0.1.0` |
| `vanitas.labels` | 공통 라벨 세트 | helm.sh/chart, app.kubernetes.io/* |
| `vanitas.selectorLabels` | Selector 라벨 | name, instance |
| `vanitas.serviceAccountName` | SA 이름 결정 | `my-release-vanitas` 또는 `default` |

## Spring Boot 연동

### 필수 의존성 (build.gradle.kts)

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-actuator")
}
```

### 필수 설정 (application.yml)

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
  health:
    livenessState:
      enabled: true
    readinessState:
      enabled: true
```

## 배포 시나리오

### 시나리오 1: 기본 배포 (개발환경)

```bash
helm install vanitas ./vanitas \
  --set image.repository=my-registry/vanitas \
  --set image.tag=latest \
  --set autoscaling.enabled=false \
  --set replicaCount=1
```

### 시나리오 2: Production 배포

```bash
helm install vanitas ./vanitas \
  --set image.repository=kr-central-1.ncr.ntruss.com/prod/vanitas \
  --set image.tag=abc1234 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=vanitas.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

### 시나리오 3: values 파일 사용

```yaml
# values-prod.yaml
image:
  repository: kr-central-1.ncr.ntruss.com/prod/vanitas
  tag: "v1.2.0"

replicaCount: 3

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: vanitas.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: vanitas-tls
      hosts:
        - vanitas.example.com

config:
  springProfiles: "prod"
  customConfig:
    DATABASE_URL: "jdbc:postgresql://db:5432/vanitas"
    REDIS_HOST: "redis-master"
```

```bash
helm install vanitas ./vanitas -f values-prod.yaml
```

## CI/CD 연동 (tekton-ci)

1. tekton-ci가 코드 빌드 후 NCR에 이미지 push
2. 이미지 태그는 Git commit SHA
3. vanitas chart로 해당 이미지 배포

```bash
# Pipeline에서 commit SHA 추출
IMAGE_TAG=$(kubectl get pipelinerun <name> \
  -o jsonpath='{.status.pipelineResults[?(@.name=="git-commit")].value}')

# 배포
helm upgrade --install vanitas ./vanitas \
  --set image.tag=${IMAGE_TAG}
```

## 트러블슈팅

### Pod가 시작되지 않음
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Health Check 실패
- `initialDelaySeconds` 증가 (JVM 시작 시간)
- Actuator 엔드포인트 확인: `curl localhost:8080/actuator/health`

### OOM (OutOfMemory)
- `resources.limits.memory` 증가
- `JAVA_OPTS`의 `-Xmx` 값 조정 (memory limit의 70~80%)

### Image Pull 실패
```bash
# imagePullSecrets 설정
helm upgrade vanitas ./vanitas \
  --set imagePullSecrets[0].name=ncr-credentials
```

## 버전 히스토리

| 버전 | 변경사항 |
|------|----------|
| 0.1.0 | 초기 릴리스 - Deployment, Service, ConfigMap, HPA, Ingress 지원 |
