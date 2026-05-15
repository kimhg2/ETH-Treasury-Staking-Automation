# Runtime Scripts

이 디렉토리는 CDVN baseline과 overlay를 조합해 실제 배포 단위를 만드는 스크립트를 둔다.

현재 스크립트:

- `render.sh`
  - pinned baseline을 복제하고 cluster/host inventory를 반영한 runtime을 생성한다.
  - 실운영에서는 `--cluster-file` + `--host-file`로 operator 하나의 local runtime을 만드는 흐름을 우선한다.
  - `--hosts-file`은 4대 전체 bundle을 로컬에서 검토하거나 smoke test 할 때 사용한다.
- `stage-charon-artifacts.sh`
  - operator host의 approved `.charon` artifact source에서 `cluster-lock.json`, `charon-enr-private-key`, optional validator pubkeys만 host-local runtime에 allowlist stage 한다.
- `verify-baseline.sh`
  - pinned baseline mirror 필수 파일과 secret exclusion을 확인한다.
- `verify.sh`
  - rendered runtime이 baseline version, overlay, secret 규칙과 staged `.charon` artifact 규칙을 만족하는지 확인한다.
- `rollout.sh`
  - approval manifest를 확인한 뒤 rendered runtime을 대상 경로로 rsync 한다. 기본값은 `.charon/`, artifact staging metadata, validator pubkeys를 제외한다.
- `host-preflight.sh`
  - host의 docker / compose / rsync / curl, deployment path, disk 여유를 dry-run 또는 원격 실행으로 점검한다.
- `rollout-exec.sh`
  - approval manifest를 다시 확인한 뒤 `docker compose config/pull/up/ps` 순서를 dry-run 또는 원격 실행으로 수행한다.
- `drift-check.sh`
  - rendered runtime과 배포된 경로 사이의 차이를 확인한다.
- `health-sync.sh`
  - rendered metadata를 control plane health sync endpoint로 전송한다.
- `rollout-approval.example.env`
  - rollout 승인 파일 형식 예시
- `charon-artifact-approval.example.env`
  - `.charon` artifact stage 승인 파일 형식 예시

스크립트는 다음 원칙을 따른다.

- idempotent 해야 한다.
- 4대 host에 동일한 진입 방식으로 적용되어야 한다.
- 위험 작업은 approval 결과를 입력으로 받아야 한다.
- operator-specific DKG artifact 원본은 control plane이나 중앙 staging host에 모으지 않는다.
- 실운영 artifact stage는 operator host에서 `stage-charon-artifacts.sh --runtime-dir`로 수행한다.
