# Vanitas Helm Charts with Tekton CI Implementation Plan

## 개요

2개의 독립적인 Helm chart를 생성합니다:
1. **vanitas**: Kotlin/Spring Boot 애플리케이션용 Kubernetes 배포 chart
2. **tekton-ci**: Git 저장소 → Gradle 빌드 → Docker 이미지 빌드 → NCR push를 수행하는 재사용 가능한 CI 파이프라인 chart

## 사용자 요구사항 정리

- **배포 위치**: tekton-ci는 별도의 독립 chart (재사용 가능)
- **이미지 레지스트리**: NCR (NHN Cloud Registry)
- **트리거 방식**: Tekton Triggers (Git webhook 자동화)
- **애플리케이션**: Kotlin/Spring Boot/Gradle
- **빌드 대상**: main 브랜치

## 아키텍처 결정 사항

### 1. Chart 분리 전략
- tekton-ci와 vanitas를 완전히 독립된 chart로 구성
- tekton-ci는 인프라/CI 관심사 (한 번 배포, 여러 프로젝트 재사용)
- vanitas는 애플리케이션 관심사 (빈번한 업데이트)

### 2. NCR 인증
- Kubernetes Secret (type: `kubernetes.io/dockerconfigjson`)
- values.yaml로 credentials 전달 (프로덕션에서는 External Secrets Operator 권장)

### 3. 이미지 태그 전략
- Git commit SHA 사용 (추적 가능, 불변)
- Webhook payload에서 commit SHA 추출

### 4. Gradle 캐시
- PersistentVolumeClaim으로 Gradle cache 저장
- 빌드 속도 향상 (첫 빌드: 5분 → 이후: 2-3분)

### 5. 파이프라인 구조
```
Tekton Pipeline:
  1. git-clone Task: 저장소 클론
  2. gradle-build Task: Gradle 빌드 (캐시 활용)
  3. docker-build-push Task: Kaniko로 이미지 빌드 및 NCR push

Tekton Triggers:
  - EventListener: Webhook 엔드포인트 노출 (LoadBalancer)
  - TriggerBinding: Webhook payload에서 데이터 추출
  - TriggerTemplate: PipelineRun 생성
```

## 레포지토리 구조

```
/Users/jjw/my/Dev/helm-charts/
├── README.md                          # 레포지토리 개요
├── vanitas/                           # 애플리케이션 Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── ingress.yaml
│   │   ├── hpa.yaml
│   │   ├── serviceaccount.yaml
│   │   └── NOTES.txt
│   ├── .helmignore
│   └── README.md
│
└── tekton-ci/                         # CI/CD 파이프라인 Helm chart
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    │   ├── _helpers.tpl
    │   ├── serviceaccount.yaml
    │   ├── role.yaml
    │   ├── rolebinding.yaml
    │   ├── secret-ncr.yaml            # NCR 인증
    │   ├── secret-git.yaml            # Git 인증 (optional)
    │   ├── configmap-gradle.yaml
    │   ├── pvc-gradle-cache.yaml      # Gradle 캐시용 PVC
    │   ├── task-git-clone.yaml
    │   ├── task-gradle-build.yaml
    │   ├── task-docker-build-push.yaml
    │   ├── pipeline.yaml              # 메인 파이프라인
    │   ├── eventlistener.yaml         # Webhook 리스너
    │   ├── triggerbinding.yaml        # Payload 데이터 추출
    │   ├── triggertemplate.yaml       # PipelineRun 생성
    │   └── NOTES.txt
    ├── .helmignore
    └── README.md
```

## 구현 단계

### Phase 1: vanitas Chart 구현

#### 1.1 기본 Chart 구조
- [ ] [vanitas/Chart.yaml](vanitas/Chart.yaml) 생성 (metadata, version 0.1.0)
- [ ] [vanitas/values.yaml](vanitas/values.yaml) 생성 (전체 설정 파라미터)
- [ ] [vanitas/.helmignore](vanitas/.helmignore) 생성

#### 1.2 핵심 템플릿
- [ ] [vanitas/templates/_helpers.tpl](vanitas/templates/_helpers.tpl): 라벨, 이름 헬퍼 함수
- [ ] [vanitas/templates/serviceaccount.yaml](vanitas/templates/serviceaccount.yaml)
- [ ] [vanitas/templates/deployment.yaml](vanitas/templates/deployment.yaml):
  - ConfigMap/Secret 참조
  - Health probes (Spring Boot Actuator)
  - Resource limits
  - Security contexts

#### 1.3 지원 템플릿
- [ ] [vanitas/templates/service.yaml](vanitas/templates/service.yaml): ClusterIP 서비스
- [ ] [vanitas/templates/configmap.yaml](vanitas/templates/configmap.yaml): 애플리케이션 설정
- [ ] [vanitas/templates/ingress.yaml](vanitas/templates/ingress.yaml): HTTP 라우팅 (조건부)
- [ ] [vanitas/templates/hpa.yaml](vanitas/templates/hpa.yaml): Autoscaling (조건부)

#### 1.4 문서화
- [ ] [vanitas/README.md](vanitas/README.md): 설치 및 설정 가이드
- [ ] [vanitas/templates/NOTES.txt](vanitas/templates/NOTES.txt): 설치 후 안내

#### 1.5 검증
```bash
helm lint vanitas/
helm template vanitas vanitas/ --output-dir /tmp/vanitas-test
```

### Phase 2: tekton-ci Chart 구현

#### 2.1 기본 Chart 구조
- [ ] [tekton-ci/Chart.yaml](tekton-ci/Chart.yaml) 생성 (Tekton 버전 명시)
- [ ] [tekton-ci/values.yaml](tekton-ci/values.yaml) 생성 (파이프라인 전체 설정)
- [ ] [tekton-ci/.helmignore](tekton-ci/.helmignore) 생성

#### 2.2 RBAC 및 Secret
- [ ] [tekton-ci/templates/serviceaccount.yaml](tekton-ci/templates/serviceaccount.yaml): 파이프라인 실행 SA
- [ ] [tekton-ci/templates/role.yaml](tekton-ci/templates/role.yaml): 최소 권한 (pods, pvc 관리)
- [ ] [tekton-ci/templates/rolebinding.yaml](tekton-ci/templates/rolebinding.yaml)
- [ ] [tekton-ci/templates/secret-ncr.yaml](tekton-ci/templates/secret-ncr.yaml): `.dockerconfigjson` 생성
- [ ] [tekton-ci/templates/secret-git.yaml](tekton-ci/templates/secret-git.yaml): Git 인증 (조건부)
- [ ] [tekton-ci/templates/configmap-gradle.yaml](tekton-ci/templates/configmap-gradle.yaml): Gradle 설정
- [ ] [tekton-ci/templates/pvc-gradle-cache.yaml](tekton-ci/templates/pvc-gradle-cache.yaml): 5Gi PVC

#### 2.3 Tekton Task 정의
- [ ] [tekton-ci/templates/task-git-clone.yaml](tekton-ci/templates/task-git-clone.yaml):
  - Git URL, revision 파라미터
  - source-code workspace 출력

- [ ] [tekton-ci/templates/task-gradle-build.yaml](tekton-ci/templates/task-gradle-build.yaml):
  - Gradle 8.5 + JDK 17 이미지 사용
  - gradle-cache workspace 마운트
  - `clean build -x test` 실행
  - 리소스: 1-2 CPU, 2-4Gi 메모리

- [ ] [tekton-ci/templates/task-docker-build-push.yaml](tekton-ci/templates/task-docker-build-push.yaml):
  - Kaniko executor 사용
  - NCR 인증 (secret 참조)
  - 이미지 빌드 및 push
  - image-digest, image-url 결과 반환

#### 2.4 Pipeline 정의
- [ ] [tekton-ci/templates/pipeline.yaml](tekton-ci/templates/pipeline.yaml):
  - Parameters: git-url, git-revision, image-name, image-tag
  - Workspaces: source-code, gradle-cache, docker-config
  - Tasks: git-clone → gradle-build → docker-build-push
  - Results: image-digest, image-url

#### 2.5 Tekton Triggers
- [ ] [tekton-ci/templates/eventlistener.yaml](tekton-ci/templates/eventlistener.yaml):
  - ServiceAccount 참조
  - LoadBalancer Service (외부 노출)
  - TriggerBinding/Template 참조

- [ ] [tekton-ci/templates/triggerbinding.yaml](tekton-ci/templates/triggerbinding.yaml):
  - GitHub webhook payload 파싱:
    - `$(body.repository.clone_url)` → git-url
    - `$(body.ref)` → branch 확인 (main만 허용)
    - `$(body.after)` → commit SHA (image tag로 사용)

- [ ] [tekton-ci/templates/triggertemplate.yaml](tekton-ci/templates/triggertemplate.yaml):
  - 고유한 PipelineRun 이름 생성 (타임스탬프 포함)
  - TriggerBinding에서 파라미터 수신
  - Workspace PVC 참조

#### 2.6 헬퍼 및 문서
- [ ] [tekton-ci/templates/_helpers.tpl](tekton-ci/templates/_helpers.tpl): dockerconfig 생성 함수
- [ ] [tekton-ci/templates/NOTES.txt](tekton-ci/templates/NOTES.txt): Webhook URL 출력
- [ ] [tekton-ci/README.md](tekton-ci/README.md): 상세 설치 가이드

#### 2.7 검증
```bash
helm lint tekton-ci/
helm template tekton-ci tekton-ci/ \
  --set git.url=https://github.com/test/test.git \
  --set ncr.credentials.username=test \
  --set ncr.credentials.password=test \
  --output-dir /tmp/tekton-test
```

### Phase 3: 통합 및 테스트

#### 3.1 사전 요구사항
```bash
# Tekton Pipelines 설치
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Tekton Triggers 설치
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# 설치 확인
kubectl get pods -n tekton-pipelines
```

#### 3.2 tekton-ci Chart 배포
```bash
helm install vanitas-ci tekton-ci/ \
  --set git.url=https://github.com/your-org/vanitas.git \
  --set docker.imageName=your-registry/vanitas \
  --set ncr.credentials.username=<NCR_ACCESS_KEY> \
  --set ncr.credentials.password=<NCR_SECRET_KEY> \
  -n tekton-pipelines
```

#### 3.3 수동 파이프라인 실행 테스트
```bash
# PipelineRun 생성
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: vanitas-manual-test
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: vanitas-ci-pipeline
  params:
    - name: git-url
      value: "https://github.com/your-org/vanitas.git"
    - name: git-revision
      value: "main"
    - name: image-name
      value: "your-registry/vanitas"
    - name: image-tag
      value: "manual-test"
  workspaces:
    - name: source-code
      emptyDir: {}
    - name: gradle-cache
      persistentVolumeClaim:
        claimName: gradle-cache-pvc
    - name: docker-config
      secret:
        secretName: ncr-credentials
  serviceAccountName: tekton-ci-sa
EOF

# 로그 확인
kubectl get pipelinerun -n tekton-pipelines -w
kubectl logs -f <pod-name> -n tekton-pipelines
```

#### 3.4 Webhook 설정
```bash
# EventListener 외부 IP 확인
kubectl get svc -n tekton-pipelines | grep listener

# GitHub 설정:
# Repository → Settings → Webhooks → Add webhook
# Payload URL: http://<EXTERNAL-IP>:8080
# Content type: application/json
# Events: Push events (main 브랜치)
```

#### 3.5 End-to-End 테스트
1. vanitas 저장소에 코드 변경 및 push
2. Webhook 트리거 확인
3. 파이프라인 실행 모니터링
4. NCR에서 이미지 확인 (태그: commit SHA)
5. vanitas chart로 애플리케이션 배포

```bash
# 이미지 태그 추출
IMAGE_TAG=$(kubectl get pipelinerun <name> -n tekton-pipelines \
  -o jsonpath='{.status.pipelineResults[?(@.name=="image-tag")].value}')

# 애플리케이션 배포
helm install vanitas vanitas/ \
  --set image.repository=kr-central-1.ncr.ntruss.com/your-registry/vanitas \
  --set image.tag=${IMAGE_TAG} \
  -n default

# 확인
kubectl rollout status deployment/vanitas -n default
kubectl port-forward svc/vanitas 8080:8080 -n default
curl http://localhost:8080/actuator/health
```

### Phase 4: 문서화

- [ ] 루트 [README.md](README.md) 업데이트:
  - 레포지토리 개요
  - Chart 목록 및 설명
  - Quick start 가이드

- [ ] Chart별 README 완성:
  - vanitas/README.md: 설치, 설정, 예제
  - tekton-ci/README.md: 사전요구사항, Webhook 설정, 재사용 예제

## 주요 설정 파라미터

### vanitas/values.yaml
```yaml
image:
  repository: kr-central-1.ncr.ntruss.com/your-registry/vanitas
  tag: ""  # CI에서 빌드된 이미지 태그

replicaCount: 2

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: vanitas.example.com
      paths:
        - path: /
          pathType: Prefix
```

### tekton-ci/values.yaml
```yaml
git:
  url: "https://github.com/your-org/vanitas.git"
  revision: "main"

docker:
  registry: "kr-central-1.ncr.ntruss.com"
  imageName: "your-registry/vanitas"

ncr:
  credentials:
    secretName: ncr-credentials
    username: ""  # NCR Access Key ID
    password: ""  # NCR Secret Key

gradle:
  version: "8.5"
  javaVersion: "17"
  buildArgs: "clean build -x test"
  cache:
    size: "5Gi"

pipeline:
  resources:
    gradleBuild:
      requests:
        cpu: 1000m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

triggers:
  enabled: true
  eventListener:
    serviceType: LoadBalancer

imageTag:
  strategy: "git-sha"  # commit SHA를 이미지 태그로 사용
```

## 검증 체크리스트

- [ ] Tekton Pipelines/Triggers 설치 및 정상 작동
- [ ] tekton-ci chart 설치 성공
- [ ] vanitas chart 설치 성공
- [ ] NCR credentials secret 정상 생성
- [ ] Git clone task 성공
- [ ] Gradle build task 성공 (캐시 동작 확인)
- [ ] Docker build & push 성공 (NCR에 이미지 확인)
- [ ] EventListener service 외부 접근 가능
- [ ] GitHub webhook 설정 및 동작
- [ ] Push 이벤트로 파이프라인 자동 트리거
- [ ] End-to-end 파이프라인 완료
- [ ] CI 빌드 이미지로 vanitas 배포 성공
- [ ] 애플리케이션 health check 통과

## 추가 고려사항

### 보안
- Pod Security Standards 적용
- 컨테이너 non-root 실행
- Network Policy로 Tekton namespace 격리
- NCR credentials 주기적 로테이션

### 성능 최적화
- Gradle 캐시 PVC 크기 조정 (5Gi → 10Gi)
- Parallel task 실행 (추후)
- Docker layer 캐싱

### Multi-environment
- dev/staging/prod별 별도 파이프라인
- Branch별 트리거 (dev 브랜치 → dev 파이프라인)
- Environment별 values 파일

### 고급 기능 (추후)
- 취약점 스캔 (Trivy)
- SBOM 생성
- 자동 롤백
- Blue-green 배포
- 통합 테스트 추가

## 주요 파일 (우선순위 순)

1. **tekton-ci/values.yaml**: 전체 CI 파이프라인 중심 설정
2. **tekton-ci/templates/pipeline.yaml**: CI 워크플로우 핵심 로직
3. **tekton-ci/templates/task-gradle-build.yaml**: Kotlin/Gradle 빌드 처리
4. **tekton-ci/templates/eventlistener.yaml**: Webhook 자동화 게이트웨이
5. **tekton-ci/templates/secret-ncr.yaml**: NCR 인증 (push 필수)
6. **vanitas/values.yaml**: 애플리케이션 런타임 설정
7. **vanitas/templates/deployment.yaml**: 핵심 워크로드
8. **vanitas/templates/_helpers.tpl**: 공유 템플릿 함수
9. **tekton-ci/templates/triggerbinding.yaml**: Webhook 데이터 추출
10. **tekton-ci/README.md**: 사용자 문서
