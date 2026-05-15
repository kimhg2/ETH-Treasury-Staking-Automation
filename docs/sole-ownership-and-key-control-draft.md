# 이더리움 DVT 스테이킹 단독 소유권 및 DKG 키 통제 세부 운영지침(안)

문서 상태: Draft v0.3
작성 기준일: 2026-04-29
상위 규정: 디지털 자산의 취득 및 관리에 관한 규정(2026.03.06)
적용 범위: Obol Network 기반 Ethereum DVT staking, OVM contract withdrawal 구조, Safe 3-of-4 multisig, Web3Signer + KMS signer custody

본 문서는 회계법인, 준법감시인, 디지털 자산 위원회 및 내부 감사인이 회사의 자체 운영 Ethereum staking 구조를 검토할 수 있도록 작성한 세부 운영지침 초안이다. 본 문서는 법률 의견서 또는 세무 의견서가 아니며, 상위 규정과 관련 법령이 우선 적용된다.

## 제 1 장 총칙

### 제 1 조 (목적)

본 지침은 회사가 Obol Network 기반 분산 검증인 기술(DVT)을 이용하여 Ethereum staking을 수행하는 경우, 다음 각 호의 사항을 명확히 규정하는 것을 목적으로 한다.

1. staking된 ETH의 소유권 및 출금 통제권이 회사에 단독으로 귀속됨을 입증하는 온체인·오프체인 증빙 체계
2. OVM contract withdrawal 구조, Safe multisig 3-of-4 구조와 회사 내부 승인 체계의 연결 관계
3. Obol DKG(Distributed Key Generation) ceremony의 승인, 실행, 산출물 생성 및 보관 절차
4. validator key share, withdrawal credentials, Charon ENR 등 key-related artifact의 민감도 분류와 통제
5. 원본 key share가 단일 위치에서 재조합되지 않음을 회계감사 및 내부통제 관점에서 입증하는 절차

### 제 2 조 (적용 범위)

1. 본 지침은 회사가 직접 운영하거나 회사가 통제하는 관계인이 운영하는 Ethereum validator, Obol DVT cluster, OVM contract, Charon node, Web3Signer, KMS, Safe multisig 및 관련 approval workflow에 적용한다.
2. 본 지침은 상위 규정상 "자체 운영 / 내부 스테이킹" 방식의 세부 운영정책으로 사용한다.
3. 본 지침은 staking 예치, DKG, validator key share 생성, remote signer 등록, withdrawal credentials 검증, OVM role 및 owner 검증, Safe transaction proposal export, audit log 및 회계 증빙 보관에 적용한다.
4. 외부 수탁기관 또는 외부 staking service provider를 이용하는 경우에도 회사가 DVT cluster 또는 withdrawal credentials에 대한 통제권을 유지하는 범위에서는 본 지침을 준용한다.

### 제 3 조 (정의)

본 지침에서 사용하는 용어의 정의는 다음과 같다.

1. "Ethereum" 또는 "이더리움"이란 ETH를 기본 자산으로 사용하는 public blockchain network를 의미한다. 본 지침에서 Ethereum은 회사가 staking 대상으로 삼는 blockchain network를 말한다.
2. "ETH"란 Ethereum network의 native digital asset을 의미한다. 회사가 staking하는 원금 자산 및 staking reward의 기본 단위다.
3. "Blockchain" 또는 "블록체인"이란 거래 및 상태 변경 내역이 여러 참여자에게 분산 기록되는 원장 기술을 의미한다. Ethereum의 validator deposit, withdrawal credentials, Safe transaction, reward 등은 blockchain에서 검증 가능한 기록으로 남는다.
4. "Wallet Address" 또는 "주소"란 Ethereum network에서 자산을 보유하거나 contract와 상호작용할 수 있는 식별자를 의미한다. 주소 자체는 공개 정보이며, 해당 주소를 통제하려면 대응되는 개인키 또는 multisig governance가 필요하다.
5. "Private Key" 또는 "개인키"란 특정 주소 또는 validator signing 권한을 행사하기 위해 필요한 비밀값을 의미한다. 본 지침에서 개인키에는 Safe signer key, validator key share, keystore password, raw signing key material 등 회사 자산 또는 validator duty에 영향을 줄 수 있는 민감정보가 포함된다.
6. "Multisig"란 거래 실행 또는 권한 행사를 위해 복수의 signer 승인을 요구하는 구조를 의미한다. 본 지침의 Safe는 4명 signer 중 3명 이상이 승인해야 transaction을 실행할 수 있는 3-of-4 multisig 구조를 사용한다.
7. "OVM" 또는 "Obol Validator Manager"란 Obol cluster의 deposit, withdrawal, reward, principal recipient 등 validator 관련 권한을 관리하기 위해 배포되는 smart contract를 의미한다. 본 운영 모델에서는 Ethereum validator의 withdrawal credentials가 OVM contract address로 귀속되고, 해당 OVM contract의 owner 또는 관리자 권한은 회사 Safe가 보유한다.
8. "OVM Owner Address"란 OVM contract를 관리할 수 있는 owner 또는 admin address를 의미한다. 본 운영 모델에서는 OVM Owner Address가 회사 Safe address여야 한다.
9. "OVM Role"이란 OVM contract에서 deposit, withdrawal, reward 설정, principal 처리 등 특정 기능을 실행할 수 있도록 부여되는 권한을 의미한다. 회사 운영에서는 EOA 계정에 OVM role을 부여하지 않는 것을 원칙으로 한다.
10. "Safe"란 회사가 treasury execution 및 OVM owner/admin 계정으로 사용하는 Safe multisig contract를 의미한다. 회사 운영에서는 OVM Owner Address가 Safe address로 설정되어야 하며, Safe owner와 threshold는 on-chain으로 검증 가능해야 한다.
11. "Signer"란 Safe owner address의 개인키를 보유하거나 회사가 승인한 policy signer 권한을 가진 임직원 또는 지정 권한자를 의미한다. Signer는 기안자, 재무승인, 보안승인, 비상복구 역할로 구분한다.
12. "Staking" 또는 "스테이킹"이란 Ethereum network의 validator로 참여하기 위해 ETH를 예치하고, validator duty를 수행함으로써 protocol reward를 수취하는 행위를 의미한다. Staking은 원금 ETH가 특정 validator와 withdrawal credentials에 연결되므로, 예치 전 승인, 출금 권한 확인, reward 회계처리 및 slashing risk 관리가 필요하다.
13. "Validator" 또는 "검증인"이란 Ethereum proof-of-stake network에서 block proposal, attestation 등 consensus duty를 수행하는 주체를 의미한다. Ethereum validator는 validator public key로 식별되며, validator duty를 올바르게 수행하면 reward를 받고, 잘못 수행하거나 악의적 행위가 발생하면 penalty 또는 slashing을 받을 수 있다.
14. "Validator Public Key"란 validator를 식별하는 공개키를 의미한다. 회계 및 감사 증빙에서는 validator public key를 기준으로 deposit data, Beacon state, cluster lock, reward ledger를 연결한다.
15. "Validator Signing Key"란 validator duty에 필요한 서명 권한을 가진 key material을 의미한다. 본 운영 모델에서는 validator signing key raw material을 애플리케이션 DB 또는 공개 repository에 저장하지 않으며, Web3Signer + KMS 경로 밖으로 복제하지 않는다.
16. "Validator Key Share"란 DKG를 통해 각 operator에게 분산 생성되는 validator signing key 조각을 의미한다. 단일 key share만으로는 validator duty를 완전히 수행할 수 없도록 threshold 구조로 운영되며, 각 key share는 operator별로 분리 관리한다.
17. "Keystore"란 validator signing key 또는 key share를 암호화하여 저장하는 파일 형식을 의미한다. Keystore 파일과 password는 raw signing key material에 준하는 고위험 민감정보로 관리한다.
18. "Deposit" 또는 "예치"란 validator를 활성화하기 위해 ETH를 Ethereum deposit contract에 예치하는 행위를 의미한다. 회사 운영에서는 deposit transaction을 자동 서명하지 않으며, deposit data와 withdrawal credentials 검증 후 Safe approval 절차를 거쳐야 한다.
19. "Deposit Data"란 validator deposit에 필요한 validator public key, withdrawal credentials, deposit amount, signature 등을 포함하는 data file을 의미한다. 회계감사에서는 deposit data hash와 withdrawal credentials 검증 결과를 보관한다.
20. "Withdrawal Credentials"란 Ethereum validator의 출금 권한이 귀속되는 credential을 의미한다. 회사 운영에서는 withdrawal credentials가 OVM contract address로 귀속되어야 하며, 해당 OVM contract의 owner/admin이 회사 Safe로 설정되어 있어야 한다. 이는 staking된 ETH의 경제적 통제권 입증에 핵심 증빙이 된다.
21. "Principal Recipient"란 OVM 구조에서 validator 원금 또는 principal 관련 출금이 최종 귀속되는 주소를 의미한다. 회사 운영에서는 회사가 승인한 treasury address 또는 Safe로 설정되어야 한다.
22. "Principal Threshold"란 OVM 또는 관련 withdrawal 구조에서 validator 유지를 위해 남겨두어야 하는 최소 principal 기준을 의미한다. 이는 유동성, 회계 표시 및 출금 가능 금액 검토에 영향을 줄 수 있다.
23. "Rewards Split"이란 OVM 구조에서 staking reward가 어떤 주소 또는 참여자에게 어떤 비율로 배분되는지 정의하는 설정을 의미한다. 회사 운영에서는 reward recipient와 Obol fee, operator 보상 여부를 회계 증빙으로 분리한다.
24. "Fee Recipient"란 block proposal 또는 execution layer reward가 지급되는 Ethereum address를 의미한다. Fee recipient는 withdrawal credentials와 다른 개념이며, reward 수취 및 회계처리 관점에서 별도로 관리한다.
25. "Staking Reward" 또는 "스테이킹 보상"이란 validator duty 수행으로 발생하는 consensus reward, execution reward, MEV 관련 수취액 등을 의미한다. Staking reward는 원금 ETH와 구분하여 식별, 기록, 관리한다.
26. "Penalty"란 validator duty 미이행, offline 상태, sync 문제 등으로 발생할 수 있는 protocol-level 손실을 의미한다.
27. "Slashing"이란 double signing, surround vote 등 Ethereum protocol이 금지하는 행위가 발생할 경우 validator stake 일부가 삭감되는 중대한 penalty를 의미한다. Slashing risk가 있는 failover, signer 변경, validator 재활성화는 자동 실행하지 않는다.
28. "DVT"란 여러 operator가 하나의 Ethereum validator duty를 threshold 방식으로 수행하는 Distributed Validator Technology를 의미한다. DVT는 단일 node 또는 단일 key holder 장애에 대한 복원력을 높이지만, key share 생성·보관·운영에 대한 별도 통제가 필요하다.
29. "Obol Network"란 Ethereum DVT 운영을 위한 Charon client, DKG, cluster coordination 도구 등을 제공하는 protocol 및 ecosystem을 의미한다. 본 지침은 Obol Network 기반 DVT 운영을 전제로 한다.
30. "Charon"이란 Obol Network의 DVT middleware client를 의미한다. Charon은 operator 간 consensus duty coordination, peer communication, validator client와 signer 연결을 담당한다.
31. "Operator"란 DVT cluster에서 Charon node 및 관련 validator runtime을 운영하는 주체를 의미한다. 본 운영 모델은 4개의 operator host를 기준으로 하며, 각 operator는 자기 key share와 runtime artifact만 보유한다.
32. "Operator Host"란 Charon, validator client, observability component 등 DVT runtime이 실행되는 bare-metal 또는 승인된 server 환경을 의미한다. Operator host는 host-local secret과 deployment artifact의 보관 경계가 된다.
33. "Charon ENR"이란 Charon client가 DKG 및 cluster peer 통신에서 자신을 식별하기 위해 사용하는 Ethereum Node Record를 의미한다. ENR은 node identity와 연결 정보를 나타내는 public artifact이며, 자산 소유권 또는 출금 권한 증빙으로 사용하지 않는다.
34. "`charon-enr-private-key`"란 Charon ENR 생성을 위한 host-local network identity secret을 의미한다. 이는 withdrawal private key 또는 validator signing key가 아니나, DKG 참여와 cluster 연결에 필요한 운영상 민감정보로 관리한다.
35. "DKG" 또는 "분산 키 생성"이란 validator signing key를 단일 위치에서 생성하지 않고 여러 operator가 protocol에 참여하여 key share를 분산 생성하는 절차를 의미한다.
36. "Obol DKG Ceremony"란 Obol Charon client들이 cluster definition에 따라 validator key share를 분산 생성하는 공식 실행 절차를 말한다. 본 지침에서는 DKG 사전 승인, ENR 등록, 실행 환경 통제, 산출물 검증, 참관자 확인까지 포함한다.
37. "Cluster Definition"이란 DKG 실행 전 cluster 조건, operator address, Charon ENR, withdrawal address 또는 OVM contract address, fee recipient, validator count 등을 정의하는 `cluster-definition.json` 또는 Obol Launchpad proposal을 의미한다.
38. "Cluster Lock"이란 DKG 완료 후 생성되는 `cluster-lock.json`으로서, distributed validator public key, operator, threshold, cluster hash 등 Charon runtime에 필요한 정보를 포함하는 파일을 의미한다.
39. "Web3Signer"란 validator client가 로컬 keystore를 직접 사용하지 않고 외부 signer endpoint를 통해 validator duty signature를 요청하도록 하는 remote signer component를 의미한다.
40. "KMS"란 Key Management Service를 의미하며, key material의 생성, 보관, 사용 권한, audit log를 관리하는 보안 시스템을 말한다. 본 운영 모델에서는 Web3Signer와 KMS를 결합하여 validator signing path를 통제한다.
41. "Raw Key Material" 또는 "원본 key material"이란 암호화되기 전 또는 import 과정에서 노출될 수 있는 validator signing key, key share, keystore password, seed, mnemonic 등 비밀값을 의미한다.
42. "원본 key share"란 Web3Signer/KMS import 또는 host-local signer custody에 투입되기 전의 validator keystore, password, key share file 등 raw signing key material을 의미한다.
43. "Approval Workflow"란 deposit request, DKG ceremony, Safe proposal, signer binding, rollout 등 위험 작업을 사람이 검토하고 승인하는 절차를 의미한다.
44. "Audit Log"란 누가, 언제, 어떤 자원에 대해 어떤 승인·변경·실행을 수행했는지 기록하는 감사 추적 정보를 의미한다.
45. "증빙 패키지"란 회계법인, 준법감시인, 내부 감사인이 검토할 수 있도록 보관하는 온체인 링크, hash manifest, 승인 문서, 캡처, audit log, 참석자 확인서, 조직도 및 검증 결과 파일을 의미한다.

### 제 4 조 (상위 규정과의 관계)

1. 본 지침은 상위 규정 중 다음 조항의 세부 운영 절차로 사용한다.
   - 제 5 조 디지털 자산 관리 절차
   - 제 7 조 거래 집행
   - 제 9 조 거래 기록 보관
   - 제 10 조 허용되는 스테이킹 방식
   - 제 11 조 승인 권한 및 한도
   - 제 12 조 보관, 소유권 및 키 관리 권한
   - 제 13 조 운영상 보호 장치
   - 제 14 조 스테이킹 보상 및 회계 처리
   - 제 15 조 모니터링, 보고 및 사고 보고
   - 제 19 조 개인키 보안 구조 및 기술 요건
   - 제 20 조 개인키 거버넌스 및 통제
2. 상위 규정 제 12 조에 따라 staking된 ETH의 소유권 및 통제권은 항상 회사에 귀속되어야 하며, 제3자가 회사의 디지털 자산에 대해 독립적으로 인출 또는 이전을 개시할 수 있는 구조를 허용하지 않는다.
3. 상위 규정 제 19 조의 적격 수탁기관, HSM, MPC 요건과 자체 운영 DVT + Web3Signer + KMS 구조의 정합성은 디지털 자산 위원회, 준법감시인, 회계법인 및 필요 시 이사회 검토 대상이다. 본 지침은 해당 검토에 필요한 통제 및 증빙 구조를 정의한다.
4. 본 지침과 상위 규정 또는 관련 법령이 상충하는 경우 상위 규정 및 관련 법령을 우선 적용한다.

### 제 5 조 (회계감사 대응 원칙)

1. 본 지침의 핵심 감사 명제는 다음과 같다.
   - 회사는 staking된 ETH의 withdrawal credentials를 OVM contract로 고정하고, 해당 OVM contract의 owner/admin 권한을 Safe multisig가 보유하도록 하여 경제적 출금 권한을 단독 통제한다.
   - Safe signer는 회사 내부 권한자 4명으로 구성되며, 3-of-4 승인 없이는 OVM owner/admin 권한 행사, 출금, 이전, 처분 또는 deposit 관련 자금 집행이 불가능하다.
   - DKG 과정에서 생성된 validator key share는 단일 위치에 재조합되지 않으며, 회사의 Web3Signer + KMS 경로 밖으로 복제되지 않는다.
   - ENR은 DVT node identity 증빙이며, 자산 소유권 또는 출금 권한 증빙이 아니다.
2. 회계감사 대응 시 ENR, Charon runtime, validator key share, Safe signer key, OVM role, withdrawal credentials를 혼동해서는 안 된다.
3. 거래 및 운영 증빙은 회계부서와 공유하고, 상위 규정 제 9 조 취지에 따라 최소 6년간 보관한다.

## 제 2 장 단독 소유권 입증 체계

### 제 6 조 (단독 소유권 입증 명제)

회사는 다음 각 호의 증빙을 모두 연결하여 staking된 ETH에 대한 단독 소유권 및 통제권을 입증한다.

1. DKG 또는 deposit 생성 시점의 `cluster-definition.json` 또는 Obol Launchpad proposal
2. `deposit_data.json`에 포함된 validator public key 및 withdrawal credentials
3. Beacon chain finalized state 또는 Etherscan validator page에서 조회되는 validator withdrawal credentials
4. withdrawal credentials가 귀속되는 OVM contract address
5. OVM contract의 owner/admin address가 회사 Safe address임을 보여주는 on-chain read result
6. Safe contract의 `getOwners()` 및 `getThreshold()` 조회 결과
7. Safe owner 4명의 실명, 부서, 직책 및 권한 배정표
8. 키 보유자가 회사 내 서로 다른 부서에 속함을 입증하는 조직도 및 HR 증빙
9. DKG, OVM role review, deposit request, Safe proposal export, rollout, signer 변경에 관한 approval 및 audit log

### 제 7 조 (증빙 패키지 구성)

단독 소유권 증빙 패키지는 다음 구조로 보관한다. 실제 주소, 실명, 내부 URL, KMS key ref, secret 원본은 공개 repository에 보관하지 않는다.

```text
/secure/evidence/ownership/YYYY-MM-DD/
  00_목차_및_요약.md
  01_위원회_사전승인/
  02_클러스터_정의/
  03_OVM_온체인_권한_증빙/
  04_출금_자격증명_검증/
  05_Safe_온체인_증빙/
  06_Safe_서명자_거버넌스/
  07_조직도_및_직무분리_증빙/
  08_감사로그_내보내기/
  09_테스트기록_운영표준_통합/  # 수동 테스트 기록을 설명자료로 사용할 경우
```

`00_목차_및_요약.md`에는 다음 값을 반드시 기재한다.

| 항목 | 값 |
| --- | --- |
| 증빙 패키지 식별번호 | `<OWNERSHIP_EVIDENCE_ID>` |
| 클러스터명 | `<CLUSTER_NAME>` |
| 네트워크 | `mainnet` 또는 `<TESTNET>` |
| OVM contract 주소 | `<OVM_CONTRACT_ADDRESS>` |
| Safe 주소 | `<SAFE_ADDRESS>` |
| 운영 표준 | `OVM_CONTRACT_WITHDRAWAL / SAFE_OWNER_ADMIN / NO_EOA_ROLE_GRANT / WEB3SIGNER_KMS` |
| 검증인 수 | `<N>` |
| 예치 요청 식별번호 | `<DEPOSIT_REQUEST_ID>` |
| DKG 세레머니 식별번호 | `<DKG_CEREMONY_ID>` |
| 승인 식별번호 목록 | `<APPROVAL_ID_LIST>` |
| 검토자 | `<NAME / DEPARTMENT>` |
| 검토일 | `<YYYY-MM-DD>` |

`01_위원회_사전승인/`에는 다음 문서를 보관한다.

```text
01_위원회_사전승인/
  01_스테이킹_승인_요청서.md
  02_디지털_자산_위원회_회의록.pdf
  03_승인_결의서.md
  04_재무_검토_메모.md
  05_준법_및_내부통제_검토_메모.md
  06_참석자_및_승인자_서명부.pdf
  07_이사회_승인서_해당시.pdf
```

각 문서의 내용은 다음을 기준으로 한다.

| 문서 | 주요 내용 |
| --- | --- |
| 스테이킹 승인 요청서 | 적용할 staking 방식, 예치 ETH 규모, validator 수, DKG 방식, OVM contract 주소, Safe owner/admin 주소, withdrawal credentials 정책, 주요 위험 |
| 디지털 자산 위원회 회의록 | 참석자, 의결 정족수, 검토사항, 질의응답, 승인 여부, 반대 또는 유보 의견 |
| 승인 결의서 | Obol DVT 방식 사용, 4 operator / threshold 3 구조, withdrawal credentials의 OVM contract 고정, OVM owner/admin의 Safe 설정, EOA role grant 금지, DKG 및 deposit request 진행 승인 문구 |
| 재무 검토 메모 | 원금 ETH, staking reward, fee recipient, 보상 인식, 장부 매핑 및 세무·회계 검토사항 |
| 준법 및 내부통제 검토 메모 | 회사 단독 소유권, 제3자 단독 인출 불가, Safe 3-of-4, key custody 및 직무분리 통제 |
| 참석자 및 승인자 서명부 | 위원, 준법감시인, 지정 임원, 필요 시 참관자 서명 |
| 이사회 승인서 | 상위 규정상 금액 또는 중요도 기준으로 이사회 승인이 필요한 경우 첨부 |

`02_클러스터_정의/`에는 다음 문서를 보관한다.

```text
02_클러스터_정의/
  01_cluster-definition.json
  02_클러스터_정의_검토서.md
  03_operator_ENR_매핑표.csv
  04_클러스터_정의_hash.txt
  05_Obol_GUI_또는_CLI_생성_증빙.pdf
  06_주요_파라미터_승인값_대조표.md
```

| 문서 | 주요 내용 |
| --- | --- |
| `cluster-definition.json` | DKG 실행 전 기준 파일. operator address, Charon ENR, OVM contract 또는 withdrawal address, fee recipient, validator count 등 포함 |
| 클러스터 정의 검토서 | cluster name, network, operator count, threshold, validator count, OVM contract address, OVM owner/admin Safe address, fee recipient 검토 결과 |
| operator ENR 매핑표 | operator별 담당자, operator address, public ENR, 생성 방식, 생성 일시, 등록 위치 |
| 클러스터 정의 hash | `cluster-definition.json`의 SHA256 또는 Obol에서 제공하는 definition/config hash |
| Obol GUI 또는 CLI 생성 증빙 | GUI 사용 시 화면 캡처, CLI 사용 시 secret이 제거된 command log 및 version 정보 |
| 주요 파라미터 승인값 대조표 | 위원회 승인값과 실제 cluster definition 값이 일치하는지 항목별 대조 |

`03_OVM_온체인_권한_증빙/`에는 다음 문서를 보관한다.

```text
03_OVM_온체인_권한_증빙/
  01_OVM_컨트랙트_주소_및_네트워크.md
  02_OVM_read_contract_조회결과.json
  03_OVM_owner_admin_Safe_검증표.md
  04_OVM_role_snapshot.csv
  05_OVM_role_변경이력.csv
  06_원금_수취주소_및_보상분배_검토서.md
  07_EOA_role_grant_부존재_확인서.md
```

| 문서 | 주요 내용 |
| --- | --- |
| OVM 컨트랙트 주소 및 네트워크 | OVM contract address, chain ID, Etherscan URL, Obol Launchpad URL, 사용 목적 |
| OVM read contract 조회결과 | owner/admin, role holder, principal recipient, reward split, principal threshold 등 on-chain read result |
| OVM owner/admin Safe 검증표 | OVM owner 또는 admin address가 회사 Safe address와 일치하는지 검증 |
| OVM role snapshot | DEPOSIT, WITHDRAWAL, SET_REWARD 등 role별 보유 address와 권한 범위 |
| OVM role 변경이력 | grant/revoke 관련 tx hash, block, 승인번호, 변경 사유 |
| 원금 수취주소 및 보상분배 검토서 | Principal Recipient, Rewards Split, Obol fee, operator reward 여부 및 회계 처리 영향 |
| EOA role grant 부존재 확인서 | 운영 기준상 EOA 계정에 OVM role을 부여하지 않았음을 확인. 테스트넷 예외가 있으면 운영 미적용으로 분리 |

`04_출금_자격증명_검증/`에는 다음 문서를 보관한다.

```text
04_출금_자격증명_검증/
  01_deposit_data.json
  02_deposit_data_hash.txt
  03_validator_목록.csv
  04_withdrawal_credentials_검증표.csv
  05_OVM_contract_address_도출_근거.md
  06_Beacon_state_조회결과.json
  07_검증자_서명확인서.pdf
```

| 문서 | 주요 내용 |
| --- | --- |
| `deposit_data.json` | validator public key, withdrawal credentials, deposit amount, signature 등 deposit 관련 데이터 |
| deposit data hash | `deposit_data.json` 원본성 확인용 SHA256 |
| validator 목록 | validator public key, cluster, validator index, owner entity, deposit request ID |
| withdrawal credentials 검증표 | deposit data상 credentials, Beacon state상 credentials, 도출된 OVM contract address, 일치 여부 |
| OVM contract address 도출 근거 | execution withdrawal credentials에서 OVM contract address를 도출한 방식 및 계산 근거 |
| Beacon state 조회결과 | 내부 Beacon API 또는 block explorer에서 조회한 validator state export |
| 검증자 서명확인서 | Finance reviewer, Security reviewer, Audit reviewer의 확인 및 서명 |

`05_Safe_온체인_증빙/`에는 다음 문서를 보관한다.

```text
05_Safe_온체인_증빙/
  01_Safe_주소_및_네트워크.md
  02_Safe_read_contract_조회결과.json
  03_Safe_owner_snapshot.txt
  04_Safe_owner_threshold_캡처.pdf
  05_Safe_owner_변경이력.csv
  06_Safe_module_guard_검토서.md
  07_Safe_transaction_관련_tx_hash_목록.csv
```

| 문서 | 주요 내용 |
| --- | --- |
| Safe 주소 및 네트워크 | Safe address, chain ID, Etherscan URL, Safe UI URL, OVM owner/admin 용도 |
| Safe read contract 조회결과 | `getOwners()`, `getThreshold()` 등 on-chain read result |
| Safe owner snapshot | snapshot block, snapshot time, threshold, owner 4개 주소 |
| Safe owner/threshold 캡처 | Etherscan read contract 또는 Safe UI의 owner/threshold 화면 캡처 |
| Safe owner 변경이력 | `AddedOwner`, `RemovedOwner`, `ChangedThreshold` event의 tx hash, block, 변경 사유 |
| Safe module/guard 검토서 | module, guard, fallback handler 등 제3자 독립 실행 가능성을 만들 수 있는 설정 검토 |
| Safe transaction 관련 tx hash 목록 | OVM role 관리, deposit, signer change, module change 등 관련 Safe transaction hash 목록 |

`06_Safe_서명자_거버넌스/`에는 다음 문서를 보관한다.

```text
06_Safe_서명자_거버넌스/
  01_Safe_서명자_권한배정표.md
  02_서명자별_주소_소유_확인서.pdf
  03_서명자별_key_custody_인수인계서.pdf
  04_서명자별_이해상충_확인서.pdf
  05_서명자_rotation_정책.md
  06_비상복구_권한_및_절차서.md
```

| 문서 | 주요 내용 |
| --- | --- |
| Safe 서명자 권한배정표 | 4명 signer의 역할, 실명, 부서, 직책, signer address, 승인 범위 |
| 서명자별 주소 소유 확인서 | 각 signer가 해당 Safe owner address를 통제한다는 확인 및 서명 |
| key custody 인수인계서 | hardware wallet 또는 policy signer 보관 책임, 보관 장소, 인수인계 일시 |
| 이해상충 확인서 | signer가 관련 거래 또는 운영 결정에 대해 이해상충이 없음을 확인 |
| signer rotation 정책 | 퇴사, 보직 변경, 휴직, 분실, 보안 사고 발생 시 owner 변경 절차 |
| 비상복구 권한 및 절차서 | signer 유실, 장애, 긴급 사고 발생 시 3-of-4 구조를 유지하며 복구하는 절차 |

`07_조직도_및_직무분리_증빙/`에는 다음 문서를 보관한다.

```text
07_조직도_및_직무분리_증빙/
  01_최신_조직도.pdf
  02_서명자별_재직_및_부서_확인서.pdf
  03_직무분리_검토서.md
  04_권한위임_또는_내부결재_규정.pdf
  05_HR_event_통보_및_signer_rotation_연계절차.md
```

| 문서 | 주요 내용 |
| --- | --- |
| 최신 조직도 | signer 4명이 서로 다른 부서 또는 상이한 조직에 속함을 보여주는 조직도 |
| 재직 및 부서 확인서 | signer별 실명, 부서, 직책, 재직 상태, 기준일 |
| 직무분리 검토서 | 기안, 재무승인, 보안승인, 비상복구 역할이 독립적으로 분리되어 있는지 검토 |
| 권한위임 또는 내부결재 규정 | signer 권한 부여의 내부 근거 및 위임 체계 |
| HR event 연계절차 | 퇴사, 전보, 휴직, 징계, 보안 사고 발생 시 Safe owner 변경 검토 trigger |

`08_감사로그_내보내기/`에는 다음 문서를 보관한다.

```text
08_감사로그_내보내기/
  01_approval_log_export.csv
  02_deposit_request_audit_log.csv
  03_DKG_ceremony_audit_log.csv
  04_OVM_role_audit_log.csv
  05_Safe_payload_export_log.csv
  06_runtime_stage_rollout_log.csv
  07_hash_manifest.txt
  08_로그_보관_및_무결성_확인서.md
```

| 문서 | 주요 내용 |
| --- | --- |
| approval log export | approval ID, policy type, resource ID, 요청자, 승인자, 승인시각, 최종상태 |
| deposit request audit log | deposit request 생성, 검증, 승인, export, submit tracking 이력 |
| DKG ceremony audit log | DKG plan, 참석자, 실행 시각, 산출물 hash, close sign-off 이력 |
| OVM role audit log | OVM role snapshot, grant/revoke 검토, EOA role grant 부존재 확인 이력 |
| Safe payload export log | Safe proposal payload 생성자, payload object key, safeTxHash, export 시각 |
| runtime stage/rollout log | `charon-artifact-stage`, rollout approval, stage metadata, rollout 결과 |
| hash manifest | 제출 패키지 내 주요 파일의 SHA256 목록 |
| 로그 보관 및 무결성 확인서 | audit log 보관 위치, 보관 기간, 변경 방지 방식, 검토자 확인 |

### 제 8 조 (Withdrawal Credentials의 OVM 귀속 및 Safe 통제 증빙)

1. 모든 validator의 withdrawal credentials는 회사가 승인한 OVM contract address로 귀속되어야 한다.
2. 해당 OVM contract의 owner 또는 admin 권한은 회사 Safe multisig address가 보유해야 한다.
3. "하드코딩" 또는 "고정"되었다는 표현은 `cluster-definition.json`, `deposit_data.json`, Beacon chain state가 모두 동일한 OVM contract address를 가리키고, OVM owner/admin on-chain read result가 회사 Safe address를 가리킨다는 의미로 사용한다.
4. 운영 환경에서는 EOA 계정에 OVM role을 부여하지 않는다. 테스트넷 또는 과거 검증 과정에서 EOA role grant가 사용된 경우, 해당 기록은 운영 미적용 예외로 분리하고 production evidence package에는 포함하지 않는다.
5. 다음 항목을 validator별로 제출 가능한 표 형태로 작성한다.

| 항목 | 제출값 | 증빙 방법 | 증빙 파일 |
| --- | --- | --- | --- |
| Validator public key | `<VALIDATOR_PUBKEY>` | deposit data / cluster lock / Beacon state | `validators.csv` |
| Withdrawal credentials | `<WITHDRAWAL_CREDENTIALS>` | deposit data와 Beacon state 대조 | `withdrawal-credentials.csv` |
| Derived withdrawal address | `<OVM_CONTRACT_ADDRESS>` | credentials 끝 20 bytes 또는 withdrawal address field 대조 | `derivation.md` |
| OVM contract address | `<OVM_CONTRACT_ADDRESS>` | OVM contract page / read contract | `ovm-address.md` |
| OVM owner/admin address | `<SAFE_ADDRESS>` | OVM read contract 또는 role 조회 | `ovm-owner-admin.md` |
| Safe address | `<SAFE_ADDRESS>` | Safe contract page / read contract | `safe-address.md` |
| Deposit data hash | `sha256:<HASH>` | hash manifest | `deposit-data.sha256` |
| Match result | `YES/NO` | reviewer sign-off | `withdrawal-review.md` |

6. 캡처 및 링크는 다음을 포함한다.
   - Etherscan OVM contract page: `https://etherscan.io/address/<OVM_CONTRACT_ADDRESS>`
   - Etherscan OVM read contract page: `https://etherscan.io/address/<OVM_CONTRACT_ADDRESS>#readContract`
   - Etherscan Safe address page: `https://etherscan.io/address/<SAFE_ADDRESS>`
   - Etherscan Safe read contract page: `https://etherscan.io/address/<SAFE_ADDRESS>#readContract`
   - Etherscan validator page 또는 Beacon explorer validator page: `<VALIDATOR_EXPLORER_URL>`
   - 내부 consensus client Beacon API 조회 결과: `/eth/v1/beacon/states/finalized/validators/<VALIDATOR_PUBKEY>`
7. 검토자는 다음을 확인한 후 서명한다.
   - validator public key 수와 approved validator count가 일치하는지
   - 모든 withdrawal credentials가 동일한 회사 OVM contract address에 귀속되는지
   - OVM owner/admin address가 회사 Safe address와 일치하는지
   - OVM role snapshot에서 EOA role grant가 존재하지 않는지
   - deposit data hash가 DKG 및 Safe proposal export 증빙과 일치하는지
   - deposit transaction 실행 주체와 무관하게 경제적 출금 권한이 OVM contract 및 회사 Safe governance에 귀속되는지

### 제 9 조 (OVM contract, Safe contract 및 4개 signer 주소의 온체인 연결 관계)

1. OVM contract와 Safe contract의 연결 관계, Safe contract와 4개 signer address의 연결 관계는 on-chain read result 및 event history로 제출 가능해야 한다.
2. 다음 snapshot을 매월 또는 신규 deposit 전 생성한다.

```text
OVM_CONTRACT_ADDRESS=<OVM_CONTRACT_ADDRESS>
OVM_OWNER_OR_ADMIN=<SAFE_ADDRESS>
OVM_ROLE_POLICY=NO_EOA_ROLE_GRANT
SAFE_ADDRESS=<SAFE_ADDRESS>
CHAIN_ID=<CHAIN_ID>
SNAPSHOT_BLOCK=<BLOCK_NUMBER>
SNAPSHOT_AT=<YYYY-MM-DDTHH:MM:SSZ>
THRESHOLD=3
OWNERS=<SIGNER_1_ADDRESS>,<SIGNER_2_ADDRESS>,<SIGNER_3_ADDRESS>,<SIGNER_4_ADDRESS>
ETHERSCAN_READ_CONTRACT_URL=https://etherscan.io/address/<SAFE_ADDRESS>#readContract
```

3. 제출 테이블은 다음 형식을 따른다.

| 구분 | 제출값 | 온체인 검증 방법 | 증빙 |
| --- | --- | --- | --- |
| OVM contract | `<OVM_CONTRACT_ADDRESS>` | Etherscan contract page | screenshot / URL |
| OVM owner/admin | `<SAFE_ADDRESS>` | OVM read contract | RPC result / Etherscan capture |
| OVM role policy | `NO_EOA_ROLE_GRANT` | role snapshot / event history | role CSV / reviewer sign-off |
| Safe contract | `<SAFE_ADDRESS>` | Etherscan contract page | screenshot / URL |
| Threshold | `3` | `getThreshold()` | RPC result / Etherscan capture |
| Owner 1 | `<SIGNER_1_ADDRESS>` | `getOwners()` | RPC result / Etherscan capture |
| Owner 2 | `<SIGNER_2_ADDRESS>` | `getOwners()` | RPC result / Etherscan capture |
| Owner 3 | `<SIGNER_3_ADDRESS>` | `getOwners()` | RPC result / Etherscan capture |
| Owner 4 | `<SIGNER_4_ADDRESS>` | `getOwners()` | RPC result / Etherscan capture |
| Owner change history | `<TX_HASH_LIST>` | `AddedOwner`, `RemovedOwner`, `ChangedThreshold` events | event CSV |

4. OVM owner/admin 변경, OVM role grant/revoke, Safe owner 변경, threshold 변경, module enable, guard 변경, fallback handler 변경은 모두 고위험 변경으로 분류하고, 디지털 자산 위원회 또는 별도 지정 승인자의 사전 승인을 받아야 한다.

### 제 10 조 (회계감사 주장별 증빙 매핑)

| 감사 주장 | 주요 질문 | 제출 증빙 |
| --- | --- | --- |
| 권리와 의무 | staking된 ETH의 경제적 출금 권한이 회사에 있는가 | withdrawal credentials, OVM owner/admin 스냅샷, Safe 소유자 스냅샷, 조직도 |
| 실재성 | validator와 staking 포지션이 실제 존재하는가 | validator public key, Beacon state, deposit transaction |
| 완전성 | 승인된 validator 전부가 장부와 증빙에 포함되었는가 | validator inventory, deposit request, cluster lock |
| 정확성 | validator 수, deposit amount, reward 기록이 정확한가 | deposit data, reward ledger, execution/consensus reward report |
| 기간귀속 | 예치, 보상, withdrawal event가 올바른 기간에 반영되었는가 | block timestamp, transaction hash, period report |
| 내부통제 | 키 생성 및 사용이 승인과 직무분리 하에 수행되었는가 | DKG 점검표, Safe 거버넌스, audit log |

### 제 11 조 (절차 중단 기준)

다음 각 호 중 하나라도 발생하면 deposit submit, Safe proposal export 또는 validator activation 절차를 중단한다.

1. withdrawal credentials가 승인된 OVM contract address와 일치하지 않는다.
2. OVM owner/admin address가 승인된 Safe address와 일치하지 않는다.
3. OVM role snapshot에서 승인되지 않은 EOA role grant가 확인된다.
4. Safe owner 수가 4명이 아니거나 threshold가 3이 아니다.
5. Safe owner 중 실명, 부서, 권한 배정이 확인되지 않은 signer가 있다.
6. `cluster-definition.json`, `deposit_data.json`, Beacon state 중 하나라도 validator public key 또는 withdrawal credentials가 불일치한다.
7. DKG 산출물 hash, approval ID, audit log ID가 서로 연결되지 않는다.
8. validator key share 원본이 중앙 repository, shared drive, control plane DB 또는 evidence package에 수집된 정황이 확인된다.

## 제 3 장 Safe 3-of-4 거버넌스 구조

### 제 12 조 (3-of-4 거버넌스 원칙)

1. 회사 Safe는 4명의 signer와 threshold 3 구조를 원칙으로 한다.
2. 회사 Safe는 OVM owner/admin 권한을 보유하는 treasury execution account로 사용한다.
3. 어떤 1인도 staking된 ETH의 출금, 이전, 처분 또는 deposit 자금 집행을 단독으로 실행할 수 없다.
4. Safe signer 구성은 기안자, 재무승인, 보안승인, 비상복구 역할로 분리한다.
5. signer는 회사 내 서로 다른 부서 또는 상이한 조직에 속해야 한다.
6. signer의 퇴사, 보직 변경, 장기 휴가, 이해상충, 키 분실, 보안 사고 발생 시 즉시 signer rotation approval을 개시한다.

### 제 13 조 (권한 배정표)

실제 실명, 부서, 직책, 임직원 식별자는 secure evidence path에만 보관한다.

| Safe role | Signer address | 실명 | 소속 부서 | 직책 | 주 책임 | 승인 범위 | 보유 매체 | 대체/복구 기준 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 기안자 | `<SIGNER_1_ADDRESS>` | `<NAME_1>` | Treasury Operations | `<TITLE>` | deposit request, Safe payload 초안, 운영 변경 기안 | 기안 및 1차 검토. 단독 집행 불가 | hardware wallet / policy signer | Treasury Ops 대체자 승인 |
| 재무승인 | `<SIGNER_2_ADDRESS>` | `<NAME_2>` | Finance / Accounting | `<TITLE>` | 예치 금액, 회계 귀속, reward 검토 | 자금 집행 승인 필수 signer | hardware wallet / policy signer | CFO 또는 위임권자 승인 |
| 보안승인 | `<SIGNER_3_ADDRESS>` | `<NAME_3>` | Security / Risk | `<TITLE>` | key custody, withdrawal credentials, signer 변경 검토 | key / signer / rollout 위험 승인 필수 signer | hardware wallet / policy signer | CISO 또는 위임권자 승인 |
| 비상복구 | `<SIGNER_4_ADDRESS>` | `<NAME_4>` | Executive / Compliance / BCP | `<TITLE>` | 사고 대응, signer 유실, 긴급 복구 | 비상 승인 및 교착 해소. 단독 집행 불가 | hardware wallet / policy signer | 이사회 또는 대표 승인 |

### 제 14 조 (조직도 및 직무분리 증빙)

1. 제출 패키지에는 다음 자료를 첨부한다.
   - 최신 조직도 PDF 또는 HR export
   - signer별 재직 상태, 부서, 직책 증빙
   - signer별 key custody 인수인계서
   - signer별 이해상충 확인서
   - 승인 권한 위임 규정 또는 이사회/경영진 승인 문서
2. 조직도 검토 기준은 다음과 같다.

| 검토 항목 | 기준 | 결과 |
| --- | --- | --- |
| 4명 signer가 서로 다른 부서에 속하는가 | Treasury, Finance, Security/Risk, Executive/Compliance 등으로 분리 | `<YES/NO>` |
| 재무승인과 보안승인이 독립되어 있는가 | Finance와 Security/Risk 분리 | `<YES/NO>` |
| 기안자가 단독 집행 권한을 갖지 않는가 | Safe threshold 3 및 내부 승인 규정으로 제한 | `<YES/NO>` |
| 비상복구 signer가 일상 집행자와 분리되어 있는가 | 운영 담당 부서와 분리 | `<YES/NO>` |
| HR event 발생 시 signer rotation trigger가 있는가 | 퇴사, 보직 변경, 휴직, 사고 발생 시 즉시 검토 | `<YES/NO>` |

### 제 15 조 (내부 시스템 role과 Safe signer의 구분)

1. control plane의 RBAC role은 Safe signer 권한을 대체하지 않는다.
2. 시스템 role은 workflow, approval, audit trace를 관리하며, 최종 자금 집행은 외부 Safe multisig에서 threshold 충족으로 통제한다.
3. 권장 매핑은 다음과 같다.

| Governance role | 시스템 role | 관련 권한 |
| --- | --- | --- |
| 기안자 | `TREASURY_OPERATOR` | `deposits:write`, `safe-proposals:write` |
| 재무승인 | `FINANCE_REVIEWER` 또는 `APPROVER` | `rewards:read`, `approvals:read`, `approvals:decide` |
| 보안승인 | `APPROVER` 또는 `ADMIN` | `approvals:decide`, `audit:read`, `inventory:read` |
| 비상복구 | `APPROVER` | `approvals:decide`, `audit:read` |
| 감사자 | `AUDITOR` | read-only |

## 제 4 장 DKG Ceremony 절차

### 제 16 조 (DKG 사전 승인)

DKG 시작 전 디지털 자산 위원회 또는 회사가 지정한 승인자는 다음 사항을 승인한다.

| 항목 | 필수값 | 승인자 |
| --- | --- | --- |
| Ceremony ID | `<DKG_CEREMONY_ID>` | DKG Coordinator |
| Network | `mainnet` 또는 `<TESTNET>` | Finance + Security |
| Cluster name | `<CLUSTER_NAME>` | Treasury + Infra |
| Operator count | `4` | Security |
| Threshold | `3` | Security + Finance |
| Validator count | `<N>` | Finance |
| Withdrawal address | `<OVM_CONTRACT_ADDRESS>` | Finance + Security |
| OVM owner/admin address | `<SAFE_ADDRESS>` | Finance + Security |
| OVM role policy | `NO_EOA_ROLE_GRANT` | Security + Compliance |
| Fee recipient | `<FEE_RECIPIENT_ADDRESS>` | Finance |
| Safe owner snapshot | 4 owners / threshold 3 | Security |
| Web3Signer/KMS namespace | `<KMS_NAMESPACE>` | Security |
| Evidence path | `/secure/evidence/dkg-control/<DATE>/` | Audit |

### 제 17 조 (참석자 및 책임)

| 역할 | 성명 | 부서 | 책임 | 서명 |
| --- | --- | --- | --- | --- |
| DKG Coordinator | `<NAME>` | Treasury Operations | 계획, 일정, evidence index 작성 | YES |
| Operator 1 | `<NAME>` | Infra Operations | operator-1 ENR/DKG 실행, artifact hash 제출 | YES |
| Operator 2 | `<NAME>` | Infra Operations | operator-2 ENR/DKG 실행, artifact hash 제출 | YES |
| Operator 3 | `<NAME>` | Infra Operations | operator-3 ENR/DKG 실행, artifact hash 제출 | YES |
| Operator 4 | `<NAME>` | Infra Operations | operator-4 ENR/DKG 실행, artifact hash 제출 | YES |
| Security Observer | `<NAME>` | Security / Risk | key exposure 통제, 네트워크 통제 확인 | YES |
| Finance Observer | `<NAME>` | Finance / Accounting | validator count, deposit amount, OVM contract 및 Safe owner/admin 확인 | YES |
| Audit Observer | `<NAME>` | Internal Audit / Compliance | 증빙 완결성 확인 | YES |

### 제 18 조 (ENR 생성 및 등록 통제)

1. 각 operator는 DKG 참여 전 자기 Charon client의 ENR을 생성한다.
2. ENR은 Charon client의 public identity이며, 다른 Charon client가 해당 node를 식별하고 연결하기 위한 정보다.
3. `charon-enr-private-key`는 ENR private key로서 host-local 운영 secret이다. 이는 validator withdrawal key 또는 Safe signer key가 아니나, DKG 참여와 cluster 운영에 필요한 민감정보로 관리한다.
4. ENR 생성 방식은 Obol GUI 또는 Docker/CLI 중 하나를 사용할 수 있다. 두 방식 모두 다음 증빙을 남긴다.

| 항목 | GUI 사용 시 | Docker/CLI 사용 시 |
| --- | --- | --- |
| 생성자 | operator 담당자 | operator 담당자 |
| 생성 위치 | 승인된 host 또는 secure workstation | 승인된 host 또는 secure workstation |
| 증빙 | ENR 입력/등록 화면 캡처 | redacted command log |
| public ENR | cluster definition에 등록 | cluster definition에 등록 |
| private key | 화면/문서에 노출 금지 | `.charon/charon-enr-private-key` host-local |
| 승인 | Security Observer 확인 | Security Observer 확인 |

5. ENR 등록 결과는 `cluster-definition.json`의 operator address와 ENR 매핑으로 보관한다.
6. ENR은 소유권 증빙이 아니며, 회계감사 문서에서는 DVT node participation 및 operator identity onboarding 증빙으로만 사용한다.
7. ENR 변경 또는 `charon-enr-private-key` 분실은 cluster 운영 위험으로 즉시 보고하고, 신규 ENR 등록 및 cluster 변경 절차는 별도 approval을 받아야 한다.

### 제 19 조 (실행 환경)

1. `cluster-definition.json` 검토, OVM contract address, Safe owner/admin address, hash manifest 작성은 오프라인 또는 내부 제한망 환경에서 수행할 수 있다.
2. 실제 Obol DKG 실행은 Charon participant 간 peer discovery 및 통신이 필요하므로 완전한 air-gap 환경으로 표현하지 않는다.
3. DKG 실행 환경은 일반 인터넷 접근을 허용하지 않고, 필요한 Charon peer, relay, internal endpoint만 allowlist로 제한한다.
4. 실행 환경 기준은 다음과 같다.

| 통제 항목 | 기준 | 증빙 |
| --- | --- | --- |
| 물리/논리 위치 | 승인된 operator host 또는 격리된 signer subnet | host inventory, access log |
| 네트워크 | Charon peer / relay / 필수 endpoint만 allowlist | firewall rule export, DNS log |
| 화면 캡처 | OS screenshot, 회의 녹화, 원격 제어 녹화 금지 | observer checklist |
| 외부 저장장치 | USB mass storage 차단 또는 사용 금지 | MDM policy, 현장 확인서 |
| 브라우저/메일 | DKG host에서 브라우저, 메신저, 이메일 사용 금지 | command history, observer checklist |
| 터미널 로그 | secret 출력 금지, command 중심 기록 | redacted terminal log |
| 파일 권한 | secret artifact는 owner-only permission | `ls -l` 결과 |
| 시간 동기화 | NTP 또는 승인된 time source | host preflight 결과 |

### 제 20 조 (DKG 단계별 절차)

1. DKG plan 생성
   - `DKG_CEREMONY_ID`, cluster name, validator count, threshold, OVM contract address, OVM owner/admin Safe address를 기록한다.
   - Finance와 Security가 사전 승인한다.
2. OVM 및 Safe ownership snapshot 생성
   - OVM contract의 owner/admin, role holder, principal recipient, rewards split을 조회한다.
   - OVM owner/admin address가 회사 Safe address와 일치하는지 확인한다.
   - OVM role snapshot에서 승인되지 않은 EOA role grant가 없는지 확인한다.
   - `getOwners()`와 `getThreshold()`를 조회한다.
   - 4 owners / threshold 3 결과를 증빙 패키지에 저장한다.
3. ENR 생성 및 등록
   - 각 operator가 ENR을 생성한다.
   - public ENR만 creator 또는 Launchpad에 제출한다.
   - `charon-enr-private-key`는 operator host-local path에만 보관한다.
4. Cluster definition 검토
   - operator address, ENR, withdrawal address, fee recipient, network, validator count를 확인한다.
   - `withdrawal_address` 또는 equivalent OVM address field가 승인된 OVM contract address와 일치해야 한다.
   - OVM owner/admin Safe address는 별도 on-chain read result로 확인한다.
   - definition hash 또는 config hash를 기록한다.
5. DKG 실행
   - 각 operator는 같은 cluster definition을 사용하여 DKG에 참여한다.
   - DKG 중 key material 출력, 화면 공유, 녹화, 파일 복사를 금지한다.
   - coordinator는 진행 상태와 hash만 기록하고 key share 내용을 수집하지 않는다.
6. 산출물 확인
   - 각 operator는 자기 환경에서 `cluster-lock.json`, validator keystore share, deposit data를 확인한다.
   - `deposit_data.json`에서 withdrawal credentials가 OVM contract address로 귀속되는지 검증한다.
7. Web3Signer/KMS 등록
   - validator key share는 Web3Signer + KMS 경로로만 import 또는 등록한다.
   - KMS key alias, Web3Signer public key visibility, KMS audit log를 기록한다.
   - raw key share file은 중앙 제출 패키지에 복사하지 않는다.
8. Artifact stage approval
   - runtime에는 승인된 `.charon` artifact만 stage한다.
   - 이 repository의 `stage-charon-artifacts.sh` 기준 허용 대상은 `cluster-lock.json`, `charon-enr-private-key`, optional `validator-pubkeys.txt`이다.
   - `validator_keys/`, `keystore-*.json`, mnemonic, seed, password file, key share file은 stage 대상이 아니다.
9. Audit close
   - 참석자와 참관자가 checklist에 서명한다.
   - control plane에는 approval id, hash, object key, key alias, reviewer, audit log ID만 저장한다.

### 제 21 조 (DKG 산출물 분류)

| 산출물 | 민감도 | 중앙 제출 패키지 | operator host | 비고 |
| --- | --- | --- | --- | --- |
| `cluster-definition.json` | 중간 | 가능 | 가능 | OVM contract address와 ENR mapping 검토 대상 |
| public ENR | 낮음/중간 | 가능 | 가능 | node identity, 소유권 증빙 아님 |
| `charon-enr-private-key` | 높음 | 원본 금지, 필요 시 hash/fingerprint만 | host-local only | DKG/cluster node identity secret |
| `cluster-lock.json` | 중간 | hash 및 사본 가능 | 가능 | Charon cluster 운영 artifact |
| `deposit_data.json` | 중간 | hash 및 검증용 사본 가능 | 필요 시 가능 | deposit 전 승인 대상 |
| validator pubkey list | 낮음/중간 | 가능 | 가능 | inventory 및 Web3Signer public key 검증 |
| validator keystore share | 높음 | 금지 | Web3Signer/KMS import path에서만 처리 | 중앙 수집 금지 |
| keystore password | 높음 | 금지 | KMS/import 절차 밖 보관 금지 | secret |
| mnemonic / seed | 높음 | 금지 | 금지 | 본 운영 모델에서 생성/보관하지 않음 |
| KMS key alias | 중간 | 가능 | 가능 | raw key 아님 |
| KMS audit log | 중간 | 요약 가능 | 가능 | key import/use 증빙 |

## 제 5 장 개인키 생성 절차 위험 통제

### 제 22 조 (키 노출 가능 시점 및 통제)

| 시점 | 노출 가능 정보 | 위험 | 통제 |
| --- | --- | --- | --- |
| ENR 생성 | `charon-enr-private-key` | node identity 탈취, DKG 참여 실패 | host-local 생성, git commit 금지, backup 통제 |
| cluster definition 작성 | OVM contract address, operator ENR | 잘못된 withdrawal address 또는 operator mapping | 2인 이상 review, OVM/Safe snapshot 대조 |
| DKG 실행 중 | validator key share 생성 과정 | 화면/로그/네트워크 유출 | 화면 녹화 금지, egress allowlist, 참관자 체크 |
| 산출물 생성 직후 | keystore share, password, deposit data | 파일 복제, 중앙 수집 | host-local 처리, chmod, no USB, no central copy |
| Web3Signer/KMS import | key share import input | raw material 잔존 | KMS import log, 임시 파일 제거, dual control |
| artifact stage | `.charon` artifact | validator key를 실수로 stage | allowlist stage script, sensitive path detection |
| deposit payload export | deposit data, Safe payload | 승인 전 submit | approval workflow, Safe external signing only |
| 운영 시작 | Web3Signer endpoint, pubkeys | signer 오연결, slash risk | signer inventory, slashing protection, health check |

### 제 23 조 (기술적 통제)

1. DKG 시작 전 다음 통제를 적용한다.
   - MDM 또는 OS policy로 화면 녹화와 screenshot 기능을 제한한다.
   - 회의 도구 녹화 기능은 비활성화하고, 필요 시 녹화 OFF 상태를 캡처한다.
   - DKG host에서 브라우저, 메신저, 이메일 클라이언트 사용을 금지한다.
   - USB mass storage 사용을 금지하거나 MDM으로 차단한다.
   - firewall egress를 Charon peer, relay, 필요한 endpoint로 제한한다.
   - DKG 작업 디렉토리와 output directory 권한을 owner-only로 설정한다.
   - operator별 host에서 다른 operator의 artifact가 존재하지 않는지 확인한다.
2. DKG 실행 중 다음 통제를 적용한다.
   - secret 또는 keystore 내용을 터미널에 출력하지 않는다.
   - 화면 공유가 필요한 경우 public key, hash, 진행 상태만 표시한다.
   - 참관자는 key material이 화면, 로그, 채팅, 티켓에 노출되지 않았음을 확인한다.
   - command output은 redaction 후 evidence package에 저장한다.
3. DKG 완료 직후 다음 통제를 적용한다.
   - `deposit_data.json`과 `cluster-lock.json` hash를 생성한다.
   - validator pubkey list와 withdrawal credentials를 추출한다.
   - key share import가 필요한 경우 Web3Signer/KMS 절차에서만 처리한다.
   - 임시 key share file은 KMS import 정책에 따라 삭제 또는 봉인한다.
   - 중앙 control plane에는 raw file이 아니라 hash, object key, approval id, key alias만 저장한다.

### 제 24 조 (원본 key share 단일 위치 재조합 부존재 입증)

세레머니 완료 후 다음 절차로 원본 key share가 단일 위치에 재조합되지 않았음을 입증한다.

1. Operator별 artifact attestation
   - 각 operator는 자기 host-local path에 자기 artifact만 존재했음을 서명한다.
   - 다른 operator의 keystore share를 수령하지 않았음을 명시한다.
2. 중앙 저장소 negative check
   - control plane DB, evidence package, repo, shared drive에 key share 원본이 없는지 확인한다.
   - 공개 repository는 `scripts/check-public-repo-safety.sh` 결과를 첨부한다.
   - secure evidence path는 별도 file scan 결과를 redaction 후 첨부한다.
3. KMS/Web3Signer proof
   - operator별 KMS namespace 또는 key alias가 분리되어 있음을 제출한다.
   - KMS audit log에서 import/use event가 operator별로 분리되어 있음을 확인한다.
   - Web3Signer public key visibility가 validator pubkey list와 일치하는지 확인한다.
4. Stage metadata 확인
   - 각 operator runtime의 `charon-artifacts-staging.env`에 validator keystore가 포함되지 않았음을 확인한다.
   - `CLUSTER_LOCK_SHA256`, `ENR_SHA256`, `PUBKEY_COUNT`, `APPROVAL_ID`만 제출한다.
5. Observer certificate
   - Security Observer와 Audit Observer가 "single-location recombination not observed" 확인서에 서명한다.

### 제 25 조 (위험 및 통제 매트릭스)

| Risk ID | 위험 | 영향 | 통제점 | 증빙 |
| --- | --- | --- | --- | --- |
| R-01 | withdrawal address 오입력 | 출금 권한 상실 또는 타 계정 귀속 | DKG 전 OVM contract address 2인 검토, deposit data 검증 | OVM snapshot, withdrawal credentials CSV |
| R-02 | OVM owner/admin 불일치 | 단독 소유권 증빙 약화 | OVM owner/admin read result와 Safe address 대조 | OVM read result, reviewer sign-off |
| R-03 | 승인되지 않은 EOA role grant | 제3자 또는 개인 EOA가 OVM 기능 실행 가능 | role snapshot, event history, NO_EOA_ROLE_GRANT 확인 | role CSV, EOA 부존재 확인서 |
| R-04 | Safe owner / threshold 불일치 | 내부 승인 통제 약화 | `getOwners()`, `getThreshold()` snapshot, event history 검토 | Etherscan/RPC result |
| R-05 | ENR private key 노출 | node identity 탈취, DKG 실패 | host-local 보관, git commit 금지, backup 통제 | operator attestation |
| R-06 | DKG 중 화면 캡처/녹화 | key share 노출 | 녹화 금지, 화면 공유 금지, 참관자 확인 | observer checklist |
| R-07 | 외부 네트워크 유출 | key material exfiltration | egress allowlist, DNS/firewall log 검토 | firewall export |
| R-08 | key share 중앙 수집 | DVT 보안 모델 훼손 | operator-local custody, 중앙 DB 저장 금지 | zero-recombination attestation |
| R-09 | key share 단일 위치 재조합 | slash/절도 위험 | 각 operator key share 분리, KMS namespace 분리 | KMS alias mapping |
| R-10 | DKG 산출물 변조 | 잘못된 validator 활성화 | SHA256 manifest, lock verification, reviewer sign-off | hash manifest |
| R-11 | 승인 없는 deposit submit | 자금 집행 통제 실패 | deposit request approval, Safe external signing | Approval/AuditLog |
| R-12 | slash risk 이중 활성화 | validator slashing | Web3Signer slashing protection, failover approval | signer logs |
| R-13 | Web3Signer 오연결 | 서명 실패 또는 잘못된 key 사용 | signer inventory, mTLS/internal network, public key check | metrics, signer inventory |
| R-14 | runtime에 secret 포함 | public repo 또는 rollout 유출 | `verify.sh`, `rollout.sh` exclude, public safety check | script output |
| R-15 | signer 퇴사/보직변경 미반영 | 권한자 불일치 | 월간 owner review, HR trigger, rotation approval | HR org proof, Safe event |

### 제 26 조 (기록 보관 및 보고)

1. DKG, deposit, Safe proposal, signer 변경, rollout 및 Web3Signer/KMS import 관련 기록은 회계부서와 공유하고 최소 6년간 보관한다.
2. 다음 항목은 정기 사후관리 보고서에 포함한다.
   - active validator count
   - pending deposit count
   - Safe owner snapshot
   - signer health 및 Web3Signer health
   - slashing / penalty / downtime event
   - reward 및 fee recipient 수취 내역
   - DKG 또는 signer 관련 exception
3. slashing, penalty, 운영 중단, signer compromise, key material exposure, OVM owner/admin mismatch 또는 Safe owner mismatch가 발생한 경우 준법감시인 및 디지털 자산 위원회에 지체 없이 보고한다.

## 제 6 장 테스트 기록과 운영 표준의 통합

### 제 27 조 (기존 수동 검증 기록의 지위)

1. `obol cluster dkg 구성.pdf`와 `PFSC-Obol Cluster OVM 구성-290426-045521.pdf`는 회사가 Obol DKG, OVM, Safe 구조를 실제로 검증한 테스트넷 또는 수동 운영 기록으로 보관한다.
2. 위 수동 기록은 production 운영 절차의 원본 증빙이 아니라, 운영 표준을 설계하기 위한 선행 검증 자료로 분류한다.
3. `obol cluster dkg 구성.pdf`에 포함된 단일 서버 4개 폴더 구성, Obol GUI 기반 DKG, Docker CLI 기반 ENR 생성, 로컬 `validator_keys` mount 방식은 테스트 환경의 기능 검증 기록으로 본다.
4. 이후 완료된 Web3Signer mount 및 external signer 연결 검증은 로컬 `validator_keys` mount 방식에서 production signer custody 모델로 전환 가능함을 보여주는 추가 테스트 증빙으로 보관한다.
5. `PFSC-Obol Cluster OVM 구성-290426-045521.pdf`에 포함된 EOA role grant 또는 EOA 기반 deposit 예시는 production 운영 표준으로 채택하지 않는다. production 운영에서는 OVM owner/admin을 Safe로 설정하고, EOA 계정에 OVM role을 부여하지 않는다.

### 제 28 조 (수동 기록과 레포지토리 자동화 절차의 차이 통합 기준)

| 항목 | 수동 검증 기록 | 레포지토리 운영 표준 | 회계감사 제출 기준 |
| --- | --- | --- | --- |
| 실행 환경 | 단일 서버에 4개 operator directory를 구성한 Hoodi 테스트 | 4대 bare-metal operator host에 동일한 render/stage/rollout 절차 적용 | 테스트 기록은 기능 검증 자료로 분리하고, production은 host별 preflight 및 rollout log 제출 |
| CDVN baseline | 문서상 Charon Docker `v1.9.0` 또는 Obol GUI 기준 command | `infra/obol-cdvn`의 pinned baseline `v1.9.5` 및 overlay 사용 | baseline version, render output, verify result를 production evidence로 제출 |
| ENR 생성 | Docker CLI로 ENR 생성 후 GUI에 등록 | GUI 또는 CLI 모두 허용하되 operator별 ENR mapping과 `charon-enr-private-key` host-local 보관 증빙 필수 | ENR은 node identity onboarding 증빙으로만 제출하고 소유권 증빙으로 사용하지 않음 |
| DKG 실행 | Obol Launchpad GUI와 operator별 DKG command 실행 | DKG는 반자동화 영역으로 두고, 사전 승인, observer checklist, artifact hash, audit log를 결합 | DKG command log는 redaction 후 보관하고, key share 원본은 제출하지 않음 |
| withdrawal 구조 | 수동 문서에 Safe, OVM, role 예시가 혼재 | withdrawal credentials는 OVM contract로 고정, OVM owner/admin은 Safe로 검증 | deposit data, Beacon state, OVM read result, Safe read result를 함께 제출 |
| OVM role | 테스트 예시에서 EOA role grant 가능성이 존재 | EOA role grant 금지. OVM 기능 실행은 Safe governance를 통해 통제 | role snapshot 및 EOA role grant 부존재 확인서 제출 |
| validator client signing | 로컬 `.charon/validator_keys` mount로 초기 테스트 | Web3Signer + KMS overlay를 production signer path로 사용 | 로컬 mount 기록은 smoke test로 분리하고, Web3Signer reachability, pubkey visibility, KMS audit log 제출 |
| artifact stage | 수동 directory의 `.charon` 산출물을 직접 사용 | `stage-charon-artifacts.sh` allowlist로 `cluster-lock.json`, `charon-enr-private-key`, optional pubkeys만 stage | `validator_keys/`, keystore, password가 stage되지 않았다는 verify result 제출 |
| deposit 실행 | GUI 또는 EOA 기반 실행 예시가 존재 | deposit transaction은 자동 서명하지 않고 Safe payload export 및 사람 승인 후 외부 실행 | approval ID, payload hash, Safe tx hash, submit tracking log 제출 |

### 제 29 조 (테스트 기록 편입 시 추가 보관 문서)

수동 검증 기록을 회계법인 설명자료로 사용할 경우, 다음 문서를 별도 folder에 보관한다.

```text
09_테스트기록_운영표준_통합/
  01_테스트_기록_분류표.md
  02_운영_표준_차이_대조표.md
  03_Web3Signer_전환_검증서.md
  04_EOA_role_grant_운영미적용_확인서.md
  05_로컬_validator_keys_mount_테스트_한정_확인서.md
  06_production_운영_표준_승인서.md
```

| 문서 | 주요 내용 |
| --- | --- |
| 테스트 기록 분류표 | 각 PDF가 테스트넷, 수동 검증, production 운영 중 어디에 해당하는지 분류 |
| 운영 표준 차이 대조표 | PDF 절차와 현재 repo 자동화 절차의 차이, 채택 여부, 폐기 여부 |
| Web3Signer 전환 검증서 | local validator key mount 테스트 이후 Web3Signer mount, external signer endpoint, public key visibility 검증 결과 |
| EOA role grant 운영미적용 확인서 | 테스트 예시 또는 과거 기록상 EOA role grant가 production OVM에 적용되지 않았음을 확인 |
| 로컬 validator_keys mount 테스트 한정 확인서 | 로컬 `validator_keys` mount 방식이 production signer custody 정책이 아님을 확인 |
| production 운영 표준 승인서 | OVM contract withdrawal, Safe owner/admin, no EOA role, Web3Signer + KMS 구조를 운영 표준으로 승인 |

## 별지 1. 출금 자격 증명(Withdrawal Credentials) 검증표

| 검증인 공개키 | Deposit data상 출금 자격 증명 | Beacon state상 출금 자격 증명 | 도출된 OVM contract 주소 | OVM 일치 여부 | OVM owner/admin Safe 일치 여부 | EOA role 부존재 | 검토자 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `<0x...>` | `<0x01...>` | `<0x01...>` | `<OVM_CONTRACT_ADDRESS>` | YES | YES | YES | `<NAME>` |

## 별지 2. OVM 및 Safe 온체인 스냅샷

```text
OVM_CONTRACT_ADDRESS=<OVM_CONTRACT_ADDRESS>
OVM_OWNER_OR_ADMIN=<SAFE_ADDRESS>
OVM_ROLE_POLICY=NO_EOA_ROLE_GRANT
OVM_ROLE_SNAPSHOT_BLOCK=<BLOCK_NUMBER>
PRINCIPAL_RECIPIENT=<PRINCIPAL_RECIPIENT_ADDRESS>
REWARDS_SPLIT=<REWARDS_SPLIT_SUMMARY>
SAFE_ADDRESS=<SAFE_ADDRESS>
CHAIN_ID=<CHAIN_ID>
SNAPSHOT_BLOCK=<BLOCK_NUMBER>
SNAPSHOT_AT=<YYYY-MM-DDTHH:MM:SSZ>
THRESHOLD=3
OWNERS=<SIGNER_1_ADDRESS>,<SIGNER_2_ADDRESS>,<SIGNER_3_ADDRESS>,<SIGNER_4_ADDRESS>
ETHERSCAN_READ_CONTRACT_URL=https://etherscan.io/address/<SAFE_ADDRESS>#readContract
REVIEWER=<NAME / DEPARTMENT>
```

## 별지 3. DKG 세레머니 점검표

| 단계 | 확인 항목 | 결과 | 서명 |
| --- | --- | --- | --- |
| 사전 승인 | DKG plan, validator count, OVM contract address, Safe owner/admin 승인 | `<PASS/FAIL>` | `<NAME>` |
| OVM snapshot | OVM owner/admin Safe 일치 및 EOA role grant 부존재 확인 | `<PASS/FAIL>` | `<NAME>` |
| ENR 생성 | 각 operator ENR 생성 및 private key host-local 보관 | `<PASS/FAIL>` | `<NAME>` |
| cluster definition | operator address, ENR, OVM withdrawal address, fee recipient 검토 | `<PASS/FAIL>` | `<NAME>` |
| 실행 환경 | 녹화 금지, 외부망 제한, USB 제한, 참관자 확인 | `<PASS/FAIL>` | `<NAME>` |
| DKG 실행 | 4 operator 동시 참여, secret 출력 없음 | `<PASS/FAIL>` | `<NAME>` |
| 산출물 hash | `cluster-lock.json`, `deposit_data.json` hash 생성 | `<PASS/FAIL>` | `<NAME>` |
| withdrawal 검증 | 모든 validator가 OVM contract withdrawal credentials 사용 | `<PASS/FAIL>` | `<NAME>` |
| Web3Signer/KMS | key share가 승인된 signer path에만 등록 | `<PASS/FAIL>` | `<NAME>` |
| 부존재 확인 | 중앙 저장소에 raw key share 없음 | `<PASS/FAIL>` | `<NAME>` |

## 별지 4. 원본 key share 단일 위치 재조합 부존재 확인서

```text
DKG_CEREMONY_ID=<DKG_CEREMONY_ID>
CLUSTER_NAME=<CLUSTER_NAME>
DATE=<YYYY-MM-DD>

확인 사항:
1. 4개 operator key share 원본은 중앙 control plane, public repo, shared drive, evidence package에 수집되지 않았다.
2. 각 operator는 자기 host-local 또는 Web3Signer/KMS import path에서만 key share를 처리했다.
3. stage-charon-artifacts.sh는 validator_keys, keystore, mnemonic, seed, password 파일을 stage하지 않았다.
4. 제출 패키지에는 hash, public key, OVM contract address, Safe address, approval metadata, KMS alias reference만 포함된다.

Security Observer: <NAME / SIGNATURE / TIME>
Audit Observer: <NAME / SIGNATURE / TIME>
DKG Coordinator: <NAME / SIGNATURE / TIME>
```

## 별지 5. 회계법인 검토 필요 사항

| 검토 항목 | 쟁점 | 제출 자료 |
| --- | --- | --- |
| 자체 운영 DVT의 상위 규정 정합성 | 상위 규정 제19조의 적격 수탁기관/HSM/MPC 요건과 Web3Signer + KMS + DVT 구조의 정합성 | 본 지침, KMS 설계, Web3Signer 설계, 조직도 |
| OVM withdrawal + Safe governance 구조 | OVM contract와 Safe owner/admin 구조가 회사 단독 소유권 입증에 충분한가 | withdrawal credentials, OVM read result, Safe owner snapshot |
| DKG key share 성격 | validator key share가 출금/이전 권한인지, consensus signing 권한인지 | Obol DKG docs, cluster lock, deposit data |
| reward 회계 처리 | 원금 ETH와 staking reward 식별·기록 방식 | reward ledger, fee recipient report |
| 외부 operator 여부 | 제3자가 독립적으로 인출 또는 이전을 개시할 수 있는가 | OVM role snapshot, Safe structure, signer governance, DKG operator contract |

## 참고 자료

- 상위 규정: 디지털 자산의 취득 및 관리에 관한 규정(2026.03.06)
- Obol Distributed Key Generation docs: https://docs.obol.org/docs/learn/charon/dkg
- Obol Cluster Configuration docs: https://docs.obol.org/learn/charon/cluster-configuration
- Obol Charon CLI Reference: https://docs.obol.org/learn/charon/charon-cli-reference
- Obol Create a DV With a Group: https://docs.obol.org/run-a-dv/start/create-a-dv-with-a-group
- Etherscan OVM address template: `https://etherscan.io/address/<OVM_CONTRACT_ADDRESS>`
- Etherscan Safe address template: `https://etherscan.io/address/<SAFE_ADDRESS>`
