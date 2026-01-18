# Tekton CI Helm Chart

Kotlin/Spring Boot 애플리케이션을 Gradle로 빌드하고 Docker 이미지를 NCR(NHN Cloud Registry)에 푸시하는 재사용 가능한 Tekton CI/CD 파이프라인입니다.

## 주요 기능

- 자동화된 CI 파이프라인: Git clone → Gradle build → Docker build → NCR push
- Tekton Triggers를 통한 GitHub webhook 연동
- Gradle 캐시 지원으로 빌드 속도 향상
- 여러 프로젝트에 재사용 가능
- Helm values를 통한 유연한 설정

## 사전 요구사항

- Kubernetes 1.20+
- Helm 3.0+
- **Tekton Pipelines** v0.50.0+ 설치
- **Tekton Triggers** v0.25.0+ 설치

### Tekton 설치

```bash
# Tekton Pipelines 설치
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Tekton Triggers 설치
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# 설치 확인
kubectl get pods -n tekton-pipelines
```

## 빠른 시작

### 1. Secret 값 설정

`values-secrets.yaml` 파일에 설정을 입력하세요:

```yaml
# values-secrets.yaml (git에 커밋하지 마세요!)
git:
  credentials:
    token: "ghp_xxxx"  # GitHub Personal Access Token (private repo인 경우)

ncr:
  url: "xxx.kr-central-1.ncr.ntruss.com"  # NCR Registry URL
```

### 2. Chart 설치

```bash
helm install my-app-ci ./tekton-ci \
  -f values.yaml \
  -f values-secrets.yaml \
  --set git.url=https://github.com/your-org/your-app.git \
  --set docker.imageName=your-app \
  -n tekton-pipelines
```

### 3. Webhook URL 확인

```bash
# LoadBalancer 서비스 타입인 경우
kubectl get svc -n tekton-pipelines | grep listener

# External IP가 webhook URL입니다
# 예: http://203.0.113.10:8080
```

### 4. GitHub Webhook 설정

GitHub 저장소에서:

1. **Settings** → **Webhooks** → **Add webhook**
2. **Payload URL**: `http://<EXTERNAL-IP>:8080`
3. **Content type**: `application/json`
4. **Events**: "Just the push event" 선택
5. **Active**: 체크

### 5. 파이프라인 테스트

`main` 브랜치에 커밋을 푸시하면 파이프라인이 자동으로 실행됩니다!

파이프라인 모니터링:

```bash
# 파이프라인 실행 상태 확인
kubectl get pipelinerun -n tekton-pipelines -w

# 로그 보기 (tekton CLI 설치: brew install tektoncd-cli)
tkn pipelinerun logs -f -n tekton-pipelines
```

## 설정

### Git 설정

| 파라미터 | 설명 | 기본값 |
|---------|------|--------|
| `git.url` | Git 저장소 URL | `https://github.com/your-org/vanitas.git` |
| `git.revision` | 빌드할 브랜치/태그/커밋 | `main` |
| `git.credentials.enabled` | Private repo용 인증 활성화 | `false` |
| `git.credentials.username` | Git 사용자명 | `""` |
| `git.credentials.password` | Personal Access Token | `""` |

### Gradle 설정

| 파라미터 | 설명 | 기본값 |
|---------|------|--------|
| `gradle.version` | Gradle 버전 | `8.14.3` |
| `gradle.javaVersion` | Java 버전 | `21` |
| `gradle.buildArgs` | Gradle 빌드 인자 | `clean build -x test` |
| `gradle.cacheEnabled` | Gradle 캐시 PVC 활성화 | `true` |
| `gradle.cache.size` | 캐시 PVC 크기 | `5Gi` |

### Docker/NCR 설정

| 파라미터 | 설명 | 기본값 |
|---------|------|--------|
| `ncr.url` | NCR 레지스트리 URL | `""` |
| `docker.imageName` | 이미지 이름 | `your-registry/vanitas` |
| `docker.dockerfilePath` | Dockerfile 경로 | `./Dockerfile` |
| `docker.contextPath` | 빌드 컨텍스트 경로 | `.` |

### 파이프라인 리소스

| 파라미터 | 설명 | 기본값 |
|---------|------|--------|
| `pipeline.resources.gitClone.requests.cpu` | Git clone CPU 요청 | `100m` |
| `pipeline.resources.gitClone.requests.memory` | Git clone 메모리 요청 | `128Mi` |
| `pipeline.resources.gradleBuild.requests.cpu` | Gradle 빌드 CPU 요청 | `1000m` |
| `pipeline.resources.gradleBuild.requests.memory` | Gradle 빌드 메모리 요청 | `2Gi` |
| `pipeline.resources.gradleBuild.limits.memory` | Gradle 빌드 메모리 제한 | `4Gi` |
| `pipeline.resources.dockerBuild.requests.cpu` | Docker 빌드 CPU 요청 | `500m` |
| `pipeline.resources.dockerBuild.requests.memory` | Docker 빌드 메모리 요청 | `1Gi` |

### Triggers 설정

| 파라미터 | 설명 | 기본값 |
|---------|------|--------|
| `triggers.enabled` | Tekton Triggers 활성화 | `true` |
| `triggers.eventListener.serviceType` | 서비스 타입 (LoadBalancer/ClusterIP) | `LoadBalancer` |
| `triggers.github.enabled` | GitHub webhook 활성화 | `true` |
| `triggers.github.branches` | 브랜치 필터 | `[main]` |

## 사용 예시

### 다른 프로젝트에 설치

```bash
helm install backend-ci ./tekton-ci \
  -f values-secrets.yaml \
  --set git.url=https://github.com/myorg/backend.git \
  --set docker.imageName=backend \
  -n tekton-pipelines
```

### Private 저장소

```bash
helm install private-app-ci ./tekton-ci \
  -f values-secrets.yaml \
  --set git.url=https://github.com/myorg/private-app.git \
  --set git.credentials.enabled=true \
  --set docker.imageName=private-app \
  -n tekton-pipelines
```

### 커스텀 Gradle 빌드

```bash
helm install custom-ci ./tekton-ci \
  -f values-secrets.yaml \
  --set git.url=https://github.com/myorg/custom-app.git \
  --set gradle.buildArgs="clean build test jacocoTestReport" \
  --set docker.imageName=custom-app \
  -n tekton-pipelines
```

### 멀티 브랜치

브랜치별로 별도 파이프라인 배포:

```bash
# Dev 파이프라인
helm install app-dev-ci ./tekton-ci \
  -f values-secrets.yaml \
  --set git.revision=develop \
  --set triggers.github.branches[0]=develop \
  --set docker.imageName=app-dev \
  -n tekton-pipelines

# Production 파이프라인
helm install app-prod-ci ./tekton-ci \
  -f values-secrets.yaml \
  --set git.revision=main \
  --set triggers.github.branches[0]=main \
  --set docker.imageName=app \
  -n tekton-pipelines
```

## 수동 파이프라인 실행

수동으로 파이프라인 실행 트리거:

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
      value: "vanitas"
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
EOF
```

## 모니터링

### 파이프라인 실행 확인

```bash
kubectl get pipelinerun -n tekton-pipelines -w
```

### 파이프라인 로그 보기

Tekton CLI 사용:
```bash
tkn pipelinerun logs <pipelinerun-name> -f -n tekton-pipelines
```

kubectl 사용:
```bash
# Pod 목록 확인
kubectl get pods -n tekton-pipelines

# 로그 보기
kubectl logs -f <pod-name> -n tekton-pipelines
```

### 빌드된 이미지 확인

이미지 위치: `<ncr-url>/<image-name>:<tag>`

태그 형식: 짧은 커밋 SHA (앞 7자)

예시: `xxx.kr-central-1.ncr.ntruss.com/vanitas:abc1234`

## 트러블슈팅

### Git Clone 실패

**증상**: Git clone 태스크가 인증 오류로 실패

**해결**: Private repo의 경우 git credentials 활성화
```bash
helm upgrade my-app-ci ./tekton-ci \
  --set git.credentials.enabled=true \
  -f values-secrets.yaml \
  --reuse-values
```

### Gradle 빌드 OOMKilled

**증상**: Gradle 빌드 Pod가 메모리 부족으로 종료됨

**해결**: 메모리 제한 증가
```bash
helm upgrade my-app-ci ./tekton-ci \
  --set pipeline.resources.gradleBuild.limits.memory=6Gi \
  --reuse-values
```

### Webhook이 트리거되지 않음

**증상**: Push 이벤트가 파이프라인을 트리거하지 않음

**해결**:

1. EventListener 서비스 확인:
```bash
kubectl get svc -n tekton-pipelines | grep listener
```

2. GitHub에서 webhook 전송 확인:
   - 저장소 → Settings → Webhooks
   - "Recent Deliveries"에서 오류 확인

3. EventListener 로그 확인:
```bash
kubectl logs -l eventlistener=vanitas-listener -n tekton-pipelines
```

4. 브랜치 필터 확인:
```bash
# 파이프라인은 설정된 브랜치에서만 트리거됨
# values의 triggers.github.branches 확인
```

### Gradle 캐시 미작동

**증상**: 빌드가 느리고 매번 의존성 다운로드

**해결**: PVC 존재 확인
```bash
kubectl get pvc gradle-cache-pvc -n tekton-pipelines

# 없으면 gradle.cacheEnabled=true 확인
helm upgrade my-app-ci ./tekton-ci \
  --set gradle.cacheEnabled=true \
  --reuse-values
```

## 파이프라인 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub 저장소                            │
│                                                              │
│  main에 Push → Webhook → EventListener (LoadBalancer)       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Tekton Triggers                           │
│                                                              │
│  TriggerBinding → git-url, commit-sha, branch 추출          │
│  TriggerTemplate → PipelineRun 생성                         │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Tekton Pipeline                           │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Git Clone   │ →  │ Gradle Build │ →  │ Docker Build │  │
│  │              │    │              │    │   & Push     │  │
│  │ 저장소 클론  │    │ 캐시로 JAR   │    │ 이미지 빌드  │  │
│  │              │    │ 빌드         │    │ NCR에 Push   │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            NCR (NHN Cloud Registry)                         │
│                                                              │
│  이미지: xxx.kr-central-1.ncr.ntruss.com/my-app:abc1234    │
└─────────────────────────────────────────────────────────────┘
```

## 보안 고려사항

1. **Git 인증 정보**: 비밀번호 대신 Personal Access Token 사용, Git에 절대 커밋 금지
   ```bash
   # values-secrets.yaml 사용 (.gitignore에 추가됨)
   helm install ... -f values.yaml -f values-secrets.yaml
   ```

2. **Webhook Secret**: webhook secret 검증 활성화
   ```bash
   # 시크릿 생성
   WEBHOOK_SECRET=$(openssl rand -base64 32)

   helm upgrade ... \
     --set triggers.webhook.secretEnabled=true \
     --set triggers.webhook.secretToken=$WEBHOOK_SECRET
   ```

3. **RBAC**: ServiceAccount는 최소 필요 권한만 보유

## 고급 사용법

### 커스텀 Dockerfile 위치

```bash
helm install ... \
  --set docker.dockerfilePath=./docker/Dockerfile \
  --set docker.contextPath=.
```

### 멀티 스테이지 빌드

파이프라인은 멀티 스테이지 Dockerfile을 지원합니다. 예시:

```dockerfile
# Stage 1: 빌드
FROM gradle:8.14.3-jdk21 AS builder
WORKDIR /app
COPY . .
RUN gradle clean build -x test

# Stage 2: 런타임
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 커스텀 Storage Class

```bash
helm install ... \
  --set gradle.cache.storageClass=fast-ssd \
  --set gradle.cache.size=10Gi
```

## 업그레이드

```bash
helm upgrade my-app-ci ./tekton-ci \
  -f values.yaml \
  -f values-secrets.yaml \
  -n tekton-pipelines
```

## 삭제

```bash
helm uninstall my-app-ci -n tekton-pipelines

# PVC도 삭제하려면
kubectl delete pvc gradle-cache-pvc -n tekton-pipelines
```

## 기여

이 chart는 재사용 가능하도록 설계되었습니다. 다른 언어/프레임워크에 적용하려면:

1. `task-gradle-build.yaml`을 다른 빌드 도구용으로 수정
2. `values.yaml`에 새 파라미터 추가
3. `pipeline.yaml`을 새 태스크 사용하도록 업데이트

## 라이선스

MIT License
