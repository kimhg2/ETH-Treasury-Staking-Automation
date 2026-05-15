# Inventory

이 디렉토리는 4대 bare-metal operator host의 inventory와 host별 변수를 둔다.

원칙:

- 모든 host는 동일한 자동화 경로를 사용한다.
- client diversity가 필요하면 host profile 변수로 표현한다.
- 수동 snowflake 서버는 허용하지 않는다.

권장 파일:

- `cluster.example.yml`
  - cluster 단위 공통 설정 예시
- `operator-1.local.example.yml`
  - operator 하나가 자기 host-local runtime을 render할 때 쓰는 단일 host manifest 예시
- `hosts.example.yml`
  - 로컬 smoke test나 전체 bundle 검토용 host 목록 예시

필드 가이드:

- cluster
  - `overlayProfiles`: 쉼표로 구분한 overlay 적용 순서
  - `serviceOwner`: Prometheus remote write 라벨과 운영자 식별자
  - `web3signerUrl`: validator client가 붙을 Web3Signer endpoint
  - `web3signerMetricsTarget`: Prometheus가 스크레이프할 Web3Signer metrics target
  - `healthSyncUrl`: control plane으로 host 상태를 밀어 넣을 endpoint
  - `deploymentRoot`: bare-metal host에 rollout할 기본 경로
- hosts
  - `monitoringPeer`: cluster peer 라벨과 Grafana 표시에 사용할 식별자
  - `grafanaPort`, `prometheusPort`: host별 모니터링 포트 override
  - `sshUser`: rollout 시 사용할 SSH 사용자
  - `deploymentPath`: host별 runtime 배포 경로
