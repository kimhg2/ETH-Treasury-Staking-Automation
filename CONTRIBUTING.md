# Contributing

## 목적

이 문서는 이 공개 저장소에 기여할 때 지켜야 할 최소 기준을 정리한다.

이 레포는 일반적인 앱 저장소가 아니다.
운영 자동화, approval 경계, signer custody 제약을 같이 다루므로
기여 시 편의성보다 안정성과 감사 가능성을 우선해야 한다.

## 먼저 읽을 문서

기여 전에 아래 문서를 먼저 보는 것을 권장한다.

1. `docs/README.md`
2. `AGENTS.md`
3. `SECURITY.md`

runtime automation, 운영 경계, approval/audit, public repo safety를 만지는 경우에도
source of truth는 `docs/README.md`다.

## 기여 범위

이 공개 저장소에는 아래 기여를 환영한다.

- 문서 개선
- UI / API / worker 개선
- domain model 개선
- baseline / overlay / scripts 개선
- 테스트, lint, typecheck 개선
- public-safe example 파일 개선

반대로 아래는 public repo에 직접 넣으면 안 된다.

- 실제 `cluster.yml`, `hosts.yml`
- 실제 approval 파일
- rendered runtime 산출물
- `.charon` artifact
- `jwt.hex`
- cert / key / CA
- 실제 host 주소, 내부 URL, deployment path

## 절대 원칙

이 레포에 기여할 때 아래 원칙을 반드시 지킨다.

- mnemonic, seed, raw secret, validator key material을 커밋하지 않는다.
- slash risk가 있는 동작을 자동 실행 쪽으로 넓히지 않는다.
- approval이 필요한 경계를 우회하지 않는다.
- 실제 운영값은 example 파일로 대체하거나 placeholder로 둔다.
- runtime 변경이 있으면 관련 문서를 같이 갱신한다.

## 개발 환경

기본 설치와 확인 명령은 아래를 기준으로 한다.

```bash
pnpm install
pnpm lint
pnpm typecheck
pnpm build
```

DB 관련 로컬 확인이 필요하면 아래를 쓴다.

```bash
pnpm db:generate
pnpm db:push
pnpm db:seed
```

## 변경 유형별 기대 사항

### 문서 변경

- 기존 문서와 용어를 맞춘다.
- `docs/README.md`를 source of truth로 유지한다.
- 운영 경계가 바뀌면 `docs/README.md`의 안전 계약, approval/audit, bring-up runbook도 같이 갱신한다.

### 앱 / 패키지 변경

- TypeScript strict 기준을 깨지 않는다.
- domain logic를 UI로 밀어 넣지 않는다.
- 최소한 `pnpm lint`, `pnpm typecheck`는 통과시키는 편이 맞다.

### infra / script 변경

- baseline 직접 수정 대신 overlay와 script 경계를 유지한다.
- dry-run 가능한 경우 기본 동작은 dry-run을 유지한다.
- approval required 경로는 계속 approval 입력을 요구해야 한다.
- 가능하면 변경된 스크립트는 `bash -n` 수준 검증까지 한다.

## 문서 동기화 규칙

아래 성격의 변경은 관련 문서를 함께 업데이트해야 한다.

- 새로운 script 추가
- runtime flow 변경
- approval flow 변경
- secret handling 변경
- public repo safety 기준 변경

주로 같이 확인할 문서는 아래다.

- `README.md`
- `docs/README.md`

## 공개 저장소 안전 점검

push 전에 아래 스크립트를 실행하는 것을 권장한다.

```bash
scripts/check-public-repo-safety.sh
```

이 스크립트는 아래 같은 공개 금지 파일이 repo 안에 남아 있는지 검사한다.

- `.tmp-cdvn-*`
- rendered `.env`
- `charon-enr-private-key`
- `cluster-lock.json`
- `validator-pubkeys.txt`
- `jwt.hex`
- cert / key / CA

자세한 기준은 `docs/README.md`의 공개 저장소 안전 체크를 본다.

## Pull Request 가이드

PR에는 최소한 아래를 포함하는 편이 좋다.

- 무엇을 바꿨는지
- 왜 바꿨는지
- 어떤 리스크를 줄이거나 어떤 흐름을 개선했는지
- 어떤 검증을 했는지
- 어떤 문서를 같이 갱신했는지

infra 또는 approval 경계 변경이라면
"자동화 범위가 넓어졌는가"를 명시적으로 적는 편이 좋다.

## 이슈 제보

기능 요청이나 일반 버그는 공개 issue로 올려도 된다.

하지만 아래는 공개 issue로 올리면 안 된다.

- secret 노출
- 실제 host 정보 유출
- approval 우회 가능성
- signer / key custody 관련 취약점

이런 내용은 `SECURITY.md` 기준으로 보고한다.

## 아주 짧은 결론

이 저장소에 기여할 때 가장 중요한 것은 아래 두 가지다.

- 실제 운영값과 secret은 절대 public repo에 넣지 않는다.
- runtime / approval 경계를 바꾸면 문서와 검증을 같이 업데이트한다.
