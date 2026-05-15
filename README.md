# ETH Treasury Staking Automation

이 저장소는 ETH Treasury 사업자를 위한 스테이킹 자동화 플랫폼의 설계 문서와 현재 monorepo 구현 상태를 담고 있다.

핵심 목표는 다음과 같다.

- 스테이킹 운영 자동화
- Obol Network 기반 DVT 운영 표준화
- 신규 validator 생성 승인 워크플로우 표준화
- 모니터링, 알림, 정산, 리포팅 일원화
- Web3Signer + KMS 기반 validator signing key custody
- 4대 bare-metal operator 환경 자동화
- slash 위험 구간과 자금 집행 구간에 대한 승인형 반자동화
- Safe multisig OVM account 기반 execution 통제
- 향후 Solo, DVT, Pool, Restaking 전략을 동일한 운영 체계 아래에서 관리 가능한 구조 확보

## 문서 구성

- `docs/README.md`
  - 제품 범위, 아키텍처, 현재 구현 상태, CDVN runtime automation, inventory, secret, Web3Signer/KMS, approval/audit, observability, bring-up runbook, 공개 저장소 안전 체크를 통합한 단일 운영 문서
- `docs/local-runtime-test.md`
  - 실제 DKG artifact 없이 로컬에서 operator-local render/stage/verify와 rollout exclude 경계를 검증하는 smoke test runbook
- `docs/sole-ownership-and-key-control-draft.md`
  - Safe 기반 단독 소유권 입증, 3-of-4 signer governance, Obol DKG 세레머니, key share 노출 통제, 단일 위치 재조합 부존재 입증을 위한 제출용 문서 초안
- `AGENTS.md`
  - Harness Engineering, Codex, 구현 에이전트에게 전달할 작업 원칙과 제약
- `CONTRIBUTING.md`
  - 공개 저장소 기여 방식, 문서 동기화 기준, public-safe contribution 원칙
- `SECURITY.md`
  - 보안 취약점 보고 방식과 secret / runtime artifact 공개 금지 정책
- `LICENSE`
  - 공개 저장소 배포와 기여를 위한 라이선스 파일

## 현재 구현 상태

현재 레포는 초기 부트스트랩을 넘어서 핵심 조회 플로우와 CDVN runtime automation 진입점까지 반영된 상태다.

- `apps/web`
  - Next.js 기반 운영자 백오피스, Dashboard/Validators/Nodes/Clusters/Alerts/Deposits/Approvals/Rewards/Audit 화면
- `apps/api`
  - NestJS 기반 read API, auth stub + RBAC guard, OpenAPI 진입점
- `apps/worker`
  - health evaluation job 진입점
- `packages/db`
  - Prisma schema와 seed 데이터
- `packages/domain`
  - 도메인 타입과 운영 화면 fixture
- `packages/ui`
  - 운영 UI shell 컴포넌트
- `packages/config`
  - runtime env loader
- `packages/observability`
  - structured logger
- `infra/obol-cdvn`
  - `v1.9.5` pinned baseline mirror, `web3signer` / `observability` overlay, inventory 예시, `render/stage/verify/rollout/preflight/execute/drift-check/health-sync` 스크립트

자세한 현재 상태와 runtime 세부 handoff는 `docs/README.md`를 기준으로 본다.

## 빠른 시작

```bash
pnpm install
pnpm db:generate
pnpm db:push
pnpm db:seed
pnpm dev
```

기본 진입점:

- Web: `http://localhost:3000`
- API health: `http://localhost:4000/v1/health`
- API docs: `http://localhost:4000/docs`
- API inventory: `http://localhost:4000/v1/inventory/validators` (nodes/clusters/signers 동일 prefix)
- API workflows: `http://localhost:4000/v1/approvals`, `http://localhost:4000/v1/deposits`, `http://localhost:4000/v1/audit-logs`
- API insights: `http://localhost:4000/v1/alerts`, `http://localhost:4000/v1/rewards`

Web이 다른 주소의 API를 사용해야 하면 `API_BASE_URL`을 설정한다. 기본값은 `http://localhost:4000`이다.

## 제품 한 줄 정의

ETH Treasury 운영자가 validator 생애주기, 노드 운영, 자산 승인, 리스크 통제, 정산 리포팅을 하나의 플랫폼에서 관리할 수 있게 하는 운영 시스템.

## 설계 원칙

- 운영 자동화와 자금 자동집행은 분리한다.
- 키 생성, 예치, 출금, slash 가능 구간은 승인 워크플로우를 반드시 거친다.
- 노드 장애는 자동 감지하고 대응하되, slash 가능 동작은 자동 실행하지 않는다.
- Obol CDVN은 runtime baseline으로 사용하고 커스텀은 overlay로 분리한다.
- signer key custody는 Web3Signer + KMS에 고정한다.
- 스테이킹 전략과 인프라 실행을 분리해 확장 가능성을 확보한다.
- 모든 민감 행위는 감사 로그와 실행 이력을 남긴다.

## 우선 구현 범위

- validator inventory
- node fleet inventory
- DVT cluster inventory and signer topology
- CDVN host baseline and DKG lifecycle tracking
- alerting and health evaluation
- reward accounting dashboard
- deposit request workflow
- approval queue
- Safe proposal export and execution tracking
- role-based access control

## 이후 확장 범위

- multi-cluster DVT lifecycle automation
- remote signer policy hardening
- Safe module / policy automation
- execution client / consensus client version rollout automation
- multi-chain staking treasury support
