# Helm Charts 저장소

Kubernetes에 애플리케이션과 CI/CD 파이프라인을 배포하기 위한 Helm 차트 저장소입니다.

## 차트 목록

### [vanitas](./vanitas/)

Vanitas Kotlin/Spring Boot 애플리케이션 배포를 위한 Helm 차트입니다.

**주요 기능:**
- Production-ready 배포 설정
- Horizontal Pod Autoscaling (HPA)
- Spring Boot Actuator 헬스 체크
- TLS 지원 Ingress
- 리소스 및 환경 변수 설정

**빠른 시작:**
```bash
helm install vanitas ./vanitas \
  --set image.repository=kr-central-1.ncr.ntruss.com/my-registry/vanitas \
  --set image.tag=abc1234
```

[상세 문서](./vanitas/README.md)

---

### [vanitas/tekton-ci](./vanitas/tekton-ci/)

Kotlin/Spring Boot 애플리케이션을 빌드하고 NCR(NHN Cloud Registry)에 푸시하는 재사용 가능한 Tekton CI/CD 파이프라인입니다.

**주요 기능:**
- 자동화된 CI: Git clone → Gradle build → Docker build → NCR push
- Tekton Triggers를 통한 GitHub webhook 연동
- Gradle 캐시로 빌드 속도 향상
- 여러 프로젝트에 재사용 가능
- 안전한 NCR 인증

**빠른 시작:**
```bash
helm install my-app-ci ./vanitas/tekton-ci \
  -f values.yaml \
  -f values-secrets.yaml \
  --set git.url=https://github.com/your-org/your-app.git \
  --set docker.imageName=your-app \
  -n tekton-pipelines
```

[상세 문서](./vanitas/tekton-ci/README.md)

---

## 사전 요구사항

### 애플리케이션 배포 (vanitas)
- Kubernetes 1.19+
- Helm 3.0+

### CI/CD 파이프라인 (tekton-ci)
- Kubernetes 1.20+
- Helm 3.0+
- Tekton Pipelines v0.50.0+
- Tekton Triggers v0.25.0+
- NCR (NHN Cloud Registry) 인증 정보

## 저장소 구조

```
helm-charts/
├── README.md                      # 이 파일
├── IMPLEMENTATION_PLAN.md         # 상세 구현 계획
└── vanitas/                       # 애플리케이션 Helm 차트
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/                 # 앱 배포 템플릿 (Deployment, Service 등)
    ├── README.md
    └── tekton-ci/                 # CI/CD 파이프라인 Helm 차트 (서브 차트)
        ├── Chart.yaml
        ├── values.yaml
        ├── values-secrets.yaml    # 민감 정보 (Git에 커밋 금지)
        ├── templates/             # Tekton 리소스 템플릿
        └── README.md
```

**구조 설명:**
- `vanitas/templates/`: 애플리케이션이 **어떻게 실행**되는지 정의 (Deployment, Service, Ingress 등)
- `vanitas/tekton-ci/templates/`: 애플리케이션이 **어떻게 빌드/배포**되는지 정의 (Pipeline, Task, Trigger 등)

## 전체 워크플로우 예시

### 1. Tekton 설치

```bash
# Tekton Pipelines 설치
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Tekton Triggers 설치
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# 확인
kubectl get pods -n tekton-pipelines
```

### 2. CI 파이프라인 배포

```bash
# Secret 값 설정 (values-secrets.yaml)
# git.credentials.token, ncr.url 등 설정

helm install vanitas-ci ./vanitas/tekton-ci \
  -f values.yaml \
  -f values-secrets.yaml \
  --set git.url=https://github.com/your-org/vanitas.git \
  --set docker.imageName=vanitas \
  -n tekton-pipelines
```

### 3. GitHub Webhook 설정

```bash
# Webhook URL 확인
kubectl get svc -n tekton-pipelines | grep listener

# GitHub에서 설정:
# Settings → Webhooks → Add webhook
# Payload URL: http://<EXTERNAL-IP>:8080
# Content type: application/json
# Events: Push events
```

### 4. 빌드 트리거

`main` 브랜치에 커밋을 푸시하면 파이프라인이 자동으로 실행됩니다:
1. 저장소 클론
2. Gradle로 빌드
3. Docker 이미지 빌드
4. 커밋 SHA를 태그로 NCR에 푸시

### 5. 애플리케이션 배포

```bash
# 파이프라인에서 이미지 태그 가져오기
IMAGE_TAG=$(kubectl get pipelinerun <pipelinerun-name> \
  -n tekton-pipelines \
  -o jsonpath='{.status.pipelineResults[?(@.name=="git-commit")].value}')

# 애플리케이션 배포
helm install vanitas ./vanitas \
  --set image.repository=kr-central-1.ncr.ntruss.com/your-registry/vanitas \
  --set image.tag=${IMAGE_TAG}
```

### 6. 애플리케이션 접속

```bash
# 테스트용 포트 포워딩
kubectl port-forward svc/vanitas 8080:8080

# http://localhost:8080 접속
curl http://localhost:8080/actuator/health
```

## 차트 버전 관리

차트는 시맨틱 버저닝을 따릅니다:
- **Major**: 호환성을 깨는 변경
- **Minor**: 새 기능, 하위 호환
- **Patch**: 버그 수정

현재 버전:
- `vanitas`: v0.1.0
- `tekton-ci`: v0.1.0

## 개발

### 차트 린트

```bash
# vanitas 차트 린트
helm lint ./vanitas

# tekton-ci 차트 린트
helm lint ./vanitas/tekton-ci
```

### 차트 테스트

```bash
# vanitas dry run
helm install vanitas-test ./vanitas --dry-run --debug

# tekton-ci dry run
helm install tekton-test ./vanitas/tekton-ci \
  --dry-run --debug \
  --set git.url=https://github.com/test/test.git \
  --set ncr.url=test.ncr.ntruss.com
```

### 템플릿 렌더링

```bash
# vanitas 템플릿 렌더링
helm template vanitas ./vanitas --output-dir /tmp/vanitas

# tekton-ci 템플릿 렌더링
helm template tekton-ci ./vanitas/tekton-ci \
  --set git.url=https://github.com/test/test.git \
  --output-dir /tmp/tekton-ci
```

## 트러블슈팅

### 자주 발생하는 문제

#### Tekton이 설치되지 않음
```bash
# 에러: no matches for kind "Pipeline" in version "tekton.dev/v1beta1"
# 해결: Tekton Pipelines와 Triggers 설치 (사전 요구사항 참조)
```

#### NCR 인증 실패
```bash
# 에러: unauthorized: authentication required
# 해결: NCR 인증 정보 확인
docker login kr-central-1.ncr.ntruss.com -u <key> -p <secret>
```

#### Gradle 빌드 OOM
```bash
# 해결: tekton-ci에서 메모리 제한 증가
helm upgrade tekton-ci ./vanitas/tekton-ci \
  --set pipeline.resources.gradleBuild.limits.memory=6Gi \
  --reuse-values
```

#### Webhook이 트리거되지 않음
```bash
# EventListener 서비스 확인
kubectl get svc -n tekton-pipelines | grep listener

# GitHub에서 webhook 전송 확인
# 저장소 → Settings → Webhooks → Recent Deliveries
```

## 모범 사례

### 보안
- Git에 인증 정보 절대 커밋 금지
- Kubernetes Secrets 또는 외부 시크릿 매니저 사용
- 프로덕션에서 webhook secret 검증 활성화
- 최소 권한 RBAC 정책 사용

### 리소스 관리
- 적절한 리소스 requests/limits 설정
- 자동 스케일링을 위한 HPA 사용
- 빠른 빌드를 위한 Gradle 캐시 활성화
- 리소스 사용량 모니터링

### CI/CD
- 이미지 태그로 커밋 SHA 사용 (불변, 추적 가능)
- 적절한 헬스 체크 구현
- 프로덕션 전 스테이징에서 테스트
- 트러블슈팅을 위한 빌드 로그 보관

## 기여

기여를 환영합니다! 다음 절차를 따라주세요:

1. 저장소 포크
2. 기능 브랜치 생성
3. 변경사항 작성
4. 차트 테스트
5. Pull Request 제출

## 지원

문의 및 질문:
- 이 저장소에 이슈 생성
- 각 차트의 README 문서 확인
- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)에서 상세 아키텍처 확인

## 라이선스

MIT License

## 관리자

- **HeLLo2** - popt0@naver.com
