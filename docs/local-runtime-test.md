# Local Runtime Test Runbook

이 문서는 실제 bare-metal host나 실제 DKG artifact 없이, 로컬에서 CDVN runtime automation 경계를 확인하는 절차다.

목표:

- operator-local render가 동작하는지 확인한다.
- `.charon` artifact가 control plane bundle에 stage되지 않도록 막히는지 확인한다.
- operator-local `--runtime-dir` stage가 동작하는지 확인한다.
- rollout 기본값이 `.charon`, `jwt.hex`, artifact metadata를 제외하는지 확인한다.

주의:

- 여기서 만드는 artifact는 dummy 파일이다.
- 실제 DKG output, validator key, keystore, mnemonic, seed를 절대 사용하지 않는다.
- 모든 산출물은 `/tmp/cdvn-local-runtime-test` 아래에 만든다.

## 1. 작업 디렉토리 초기화

```bash
BASE=/tmp/cdvn-local-runtime-test
rm -rf "$BASE"
mkdir -p "$BASE"
```

## 2. Baseline 확인

```bash
infra/obol-cdvn/scripts/verify-baseline.sh
```

기대 결과:

```text
Baseline verified: v1.9.5
```

## 3. Operator-local runtime render

`--host-file`은 operator 하나의 local manifest만 읽는다.
이 명령은 4대 전체 bundle이 아니라 `operator-1` runtime 하나만 만든다.

```bash
infra/obol-cdvn/scripts/render.sh \
  --cluster-file infra/obol-cdvn/inventory/cluster.example.yml \
  --host-file infra/obol-cdvn/inventory/operator-1.local.example.yml \
  --output-dir "$BASE/operator-1-runtime" \
  --force
```

기대 결과:

```text
Rendered operator runtime for operator-1 to /tmp/cdvn-local-runtime-test/operator-1-runtime
```

## 4. Rendered runtime verify

```bash
infra/obol-cdvn/scripts/verify.sh \
  --render-dir "$BASE/operator-1-runtime"
```

이 단계는 아직 `.charon` artifact가 없어도 통과해야 한다.

## 5. Local preflight dry-run

직접 runtime path를 넘겨도 metadata를 읽어 host를 식별해야 한다.
로컬 테스트에서는 deployment path를 runtime path로 override 한다.

```bash
infra/obol-cdvn/scripts/host-preflight.sh \
  --render-dir "$BASE/operator-1-runtime" \
  --deployment-path "$BASE/operator-1-runtime" \
  --local
```

## 6. Direct rollout dry-run

직접 runtime path를 넘겨도 rollout dry-run이 동작해야 한다.
기본값은 `.charon`, `jwt.hex`, artifact metadata를 제외한다.

```bash
infra/obol-cdvn/scripts/rollout.sh \
  --render-dir "$BASE/operator-1-runtime" \
  --approval-file infra/obol-cdvn/scripts/rollout-approval.example.env \
  --destination "$BASE/deploy/operator-1" \
  > "$BASE/operator-local-rollout-dry-run.out"

cat "$BASE/operator-local-rollout-dry-run.out"
```

출력에 아래 문장이 있어야 한다.

```text
Charon artifacts: excluded; stage them on the operator host with stage-charon-artifacts.sh --runtime-dir.
```

## 7. Dummy operator-local artifact 준비

이 source dir는 operator host-local artifact path를 흉내 내는 dummy 경로다.

```bash
mkdir -p "$BASE/operator-1-artifacts/.charon"
printf '{ "name": "local-dummy-cluster-lock" }\n' \
  > "$BASE/operator-1-artifacts/.charon/cluster-lock.json"
printf 'local-dummy-enr-private-key-do-not-use\n' \
  > "$BASE/operator-1-artifacts/.charon/charon-enr-private-key"
```

## 8. Operator-local artifact stage dry-run

```bash
infra/obol-cdvn/scripts/stage-charon-artifacts.sh \
  --runtime-dir "$BASE/operator-1-runtime" \
  --host-name operator-1 \
  --approval-file infra/obol-cdvn/scripts/charon-artifact-approval.example.env \
  --source-dir "$BASE/operator-1-artifacts"
```

출력에서 `Target mode: runtime-dir`가 보여야 한다.

## 9. Operator-local artifact stage execute

```bash
infra/obol-cdvn/scripts/stage-charon-artifacts.sh \
  --runtime-dir "$BASE/operator-1-runtime" \
  --host-name operator-1 \
  --approval-file infra/obol-cdvn/scripts/charon-artifact-approval.example.env \
  --source-dir "$BASE/operator-1-artifacts" \
  --execute
```

기대 결과:

```text
Staged charon artifacts into /tmp/cdvn-local-runtime-test/operator-1-runtime/.charon
```

## 10. Staged runtime verify

```bash
infra/obol-cdvn/scripts/verify.sh \
  --render-dir "$BASE/operator-1-runtime"
```

이 단계에서는 `charon-artifacts-staging.env`가 있으므로 staged `.charon` 파일 존재 여부까지 확인한다.

## 11. Compose execute dry-run

실제 `docker compose up`을 실행하지 않고 planned command만 확인한다.

```bash
infra/obol-cdvn/scripts/rollout-exec.sh \
  --render-dir "$BASE/operator-1-runtime" \
  --approval-file infra/obol-cdvn/scripts/rollout-approval.example.env \
  --deployment-path "$BASE/operator-1-runtime" \
  --local \
  --skip-pull \
  --skip-up \
  --skip-health-check
```

## 12. Sensitive source 차단 확인

source dir에 `validator_keys` 같은 민감 경로가 있으면 stage가 실패해야 한다.

```bash
mkdir -p "$BASE/operator-1-artifacts/.charon/validator_keys"

if infra/obol-cdvn/scripts/stage-charon-artifacts.sh \
    --runtime-dir "$BASE/operator-1-runtime" \
    --host-name operator-1 \
    --approval-file infra/obol-cdvn/scripts/charon-artifact-approval.example.env \
    --source-dir "$BASE/operator-1-artifacts"; then
  echo "unexpected: sensitive source was accepted" >&2
  exit 1
else
  echo "sensitive source blocked as expected"
fi
```

기대 결과:

```text
Sensitive source path detected: ...
```

민감 경로를 다시 제거한다.

```bash
rmdir "$BASE/operator-1-artifacts/.charon/validator_keys"
```

## 13. Render bundle execute 차단 확인

`--render-dir --execute`는 기본적으로 막혀야 한다.
이 검사는 control plane render bundle에 operator artifact를 넣는 실수를 방지한다.

```bash
infra/obol-cdvn/scripts/render.sh \
  --cluster-file infra/obol-cdvn/inventory/cluster.example.yml \
  --hosts-file infra/obol-cdvn/inventory/hosts.example.yml \
  --output-dir "$BASE/cluster-render" \
  --force

if infra/obol-cdvn/scripts/stage-charon-artifacts.sh \
    --render-dir "$BASE/cluster-render" \
    --host-name operator-1 \
    --approval-file infra/obol-cdvn/scripts/charon-artifact-approval.example.env \
    --source-dir "$BASE/operator-1-artifacts" \
    --execute; then
  echo "unexpected: render bundle execute was accepted" >&2
  exit 1
else
  echo "render bundle execute blocked as expected"
fi
```

기대 결과:

```text
Refusing to stage operator artifacts into a render bundle.
```

## 14. Cluster bundle rollout exclude 확인

rollout 기본값은 `.charon/`, `charon-artifacts-staging.env`, `validator-pubkeys.txt`, `jwt/jwt.hex`를 제외한다.

```bash
infra/obol-cdvn/scripts/rollout.sh \
  --render-dir "$BASE/cluster-render" \
  --host-name operator-1 \
  --approval-file infra/obol-cdvn/scripts/rollout-approval.example.env \
  --destination "$BASE/deploy/operator-1" \
  > "$BASE/rollout-dry-run.out"

cat "$BASE/rollout-dry-run.out"
```

출력에 아래 문장이 있어야 한다.

```text
Charon artifacts: excluded; stage them on the operator host with stage-charon-artifacts.sh --runtime-dir.
```

## 15. Public safety check

```bash
scripts/check-public-repo-safety.sh
```

기대 결과:

```text
Public repo safety check passed.
```

## 완료 기준

아래가 모두 충족되면 로컬 smoke test를 통과한 것으로 본다.

- baseline verify 통과
- operator-local render 통과
- rendered runtime verify 통과
- local preflight dry-run 통과
- direct rollout dry-run 통과
- operator-local stage dry-run / execute 통과
- staged runtime verify 통과
- compose execute dry-run 통과
- sensitive source 차단 확인
- render bundle execute 차단 확인
- rollout artifact exclude 메시지 확인
- public safety check 통과
