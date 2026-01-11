# Helm Charts Repository - AI Agent Context

이 문서는 AI 에이전트가 이 repository를 이해하고 작업하는 데 필요한 컨텍스트를 제공합니다.

## Repository 개요

이 repository는 Kubernetes 애플리케이션 배포를 위한 Helm chart들을 관리합니다. 각 chart는 독립적으로 버전 관리되며, 특정 애플리케이션 또는 인프라 구성요소의 배포를 담당합니다.

## 기술 스택

- **Helm**: v3.0+
- **Kubernetes**: 1.19+ (애플리케이션), 1.20+ (CI/CD)
- **Container Registry**: NCR (NHN Cloud Registry)
- **CI/CD**: Tekton Pipelines + Triggers

## Chart 목록

| Chart | 용도 | 상태 |
|-------|------|------|
| [vanitas](./vanitas/) | Kotlin/Spring Boot 애플리케이션 배포 | Active |
| [tekton-ci](./tekton-ci/) | Tekton 기반 CI/CD 파이프라인 | Active |

## 디렉토리 구조

```
helm-charts/
├── README.md                    # 사용자용 문서
├── IMPLEMENTATION_PLAN.md       # 구현 계획 및 아키텍처
├── agents.md                    # AI 에이전트용 컨텍스트 (이 파일)
├── vanitas/                     # 애플리케이션 Helm chart
│   ├── Chart.yaml              # Chart 메타데이터
│   ├── values.yaml             # 기본 설정값
│   ├── templates/              # K8s 리소스 템플릿
│   │   ├── _helpers.tpl        # 헬퍼 함수
│   │   ├── deployment.yaml     # Deployment
│   │   ├── service.yaml        # Service
│   │   ├── configmap.yaml      # ConfigMap
│   │   ├── ingress.yaml        # Ingress (optional)
│   │   ├── hpa.yaml            # HorizontalPodAutoscaler
│   │   ├── serviceaccount.yaml # ServiceAccount
│   │   └── NOTES.txt           # 설치 후 안내
│   └── README.md               # Chart 문서
└── tekton-ci/                   # CI/CD 파이프라인 chart
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    │   ├── _helpers.tpl
    │   ├── serviceaccount.yaml
    │   ├── role.yaml
    │   ├── rolebinding.yaml
    │   ├── secret-ncr.yaml
    │   ├── secret-git.yaml
    │   ├── configmap-gradle.yaml
    │   ├── pvc-gradle-cache.yaml
    │   ├── task-git-clone.yaml
    │   ├── task-gradle-build.yaml
    │   ├── task-docker-build-push.yaml
    │   ├── pipeline.yaml
    │   ├── triggerbinding.yaml
    │   ├── triggertemplate.yaml
    │   ├── eventlistener.yaml
    │   └── NOTES.txt
    └── README.md
```

## Chart 작성 규칙

### 1. 표준 Helm 구조 준수
- `Chart.yaml`: apiVersion v2, semantic versioning
- `values.yaml`: 모든 설정은 이 파일에 기본값 정의
- `templates/_helpers.tpl`: 공통 헬퍼 함수 (name, fullname, labels, selectorLabels)

### 2. 네이밍 컨벤션
- Chart 이름: kebab-case (예: `tekton-ci`)
- 템플릿 파일: 리소스 종류에 따른 이름 (예: `deployment.yaml`, `service.yaml`)
- 헬퍼 함수: `{{ include "chartname.functionname" . }}`

### 3. 보안 고려사항
- Pod Security Context 적용 (`runAsNonRoot: true`)
- Container Security Context (`allowPrivilegeEscalation: false`)
- Secrets는 절대 하드코딩 금지 (values.yaml로 전달)

### 4. 라벨링 표준
```yaml
# 공통 라벨 (모든 리소스)
helm.sh/chart: {{ chartname }}-{{ version }}
app.kubernetes.io/name: {{ chartname }}
app.kubernetes.io/instance: {{ release name }}
app.kubernetes.io/version: {{ appVersion }}
app.kubernetes.io/managed-by: Helm

# Selector 라벨 (Deployment, Service)
app.kubernetes.io/name: {{ chartname }}
app.kubernetes.io/instance: {{ release name }}
```

## 주요 작업 가이드

### 새 Chart 추가
1. 디렉토리 생성: `chart-name/`
2. `Chart.yaml` 작성 (apiVersion: v2)
3. `values.yaml`에 기본값 정의
4. `templates/_helpers.tpl` 생성 (기존 chart에서 복사 후 수정)
5. 필요한 K8s 리소스 템플릿 작성
6. `README.md` 문서화
7. `helm lint` 검증

### Chart 수정
1. 기능 변경: `templates/*.yaml` 수정
2. 설정 추가: `values.yaml`에 기본값 추가, 템플릿에서 참조
3. 버전 업데이트: `Chart.yaml`의 `version` 필드 증가

### 검증 명령어
```bash
# Lint
helm lint ./chart-name

# Template 렌더링 (dry-run)
helm template my-release ./chart-name --output-dir /tmp/test

# 설치 테스트
helm install test-release ./chart-name --dry-run --debug
```

## Chart별 특성

### vanitas
- **용도**: Kotlin/Spring Boot 웹 애플리케이션 배포
- **핵심 리소스**: Deployment, Service, ConfigMap, HPA, Ingress
- **Health Check**: Spring Boot Actuator (`/actuator/health/liveness`, `/actuator/health/readiness`)
- **환경 변수**: ConfigMap을 통해 주입 (`SPRING_PROFILES_ACTIVE`, `JAVA_OPTS`, 커스텀 설정)

### tekton-ci
- **용도**: Git → Gradle Build → Docker Build → NCR Push 자동화
- **의존성**: Tekton Pipelines, Tekton Triggers 사전 설치 필요
- **주요 구성**:
  - Tasks: git-clone, gradle-build, docker-build-push
  - Pipeline: 3개 Task 순차 실행
  - Triggers: GitHub webhook → PipelineRun 자동 생성

## 환경 정보

- **Container Registry**: NCR (kr-central-1.ncr.ntruss.com)
- **Target Application**: Kotlin + Spring Boot + Gradle
- **Maintainer**: HeLLo2 (popt0@naver.com)

## 참고 문서

- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md): 상세 구현 계획 및 아키텍처 결정
- [vanitas/README.md](./vanitas/README.md): Vanitas chart 사용 가이드
- [tekton-ci/README.md](./tekton-ci/README.md): CI 파이프라인 설정 가이드
