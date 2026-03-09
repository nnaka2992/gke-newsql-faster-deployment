# テーマ: 3大NewSQL、k8sでセルフホストするならどれが一番簡単か？

## レギュレーション

- mysql/psqlクライアントから接続できるまでを測定
- ホストするまでの手順数 x 実行時間でスコアを計算し、スコアか小さい順ほど順位が上
- 公式ドキュメントの手順通りやる
- 公式ドキュメントの手順が通らなかったら修整した箇所の数+1だけスコアを倍する
  - eg.
    - 0修整ならスコアx1
    - 1修整ならスコアx2
  - このとき自動化の都合で改変したものは修正とみなさない
- 1つのファイルへの変更は1回とする

## 動作環境

- GKE latest
  - リソースはmax(DB minimum requirements)
- kubectl / helmはドキュメント指定のバージョンをセットアップ済みとする

### 各DBの最小リソース要件

| DB | CPU (per pod) | Memory (per pod) | Pod数 | 合計CPU | 合計Memory |
|---|---|---|---|---|---|
| YugabyteDB | 0.5 vCPU | 0.5 Gi | 2 (master x1 + tserver x1) | 1 vCPU | 1 Gi |
| TiDB | ~1 vCPU | ~1 Gi | 3 (PD x1 + TiKV x1 + TiDB x1) | ~3 vCPU | ~3 Gi |
| CockroachDB | 2 vCPU | 8 Gi | 3 | 6 vCPU | 24 Gi |

### GKEクラスタ構成 (max要件に基づく)

- マシンタイプ: `e2-standard-4` (4 vCPU, 16 GB) x 3ノード
- 合計リソース: 12 vCPU, 48 GB
- ディスク: 50 GB SSD / ノード

## 対象手順書

### 対象手順の選定方法

最新バージョンのquickstart
複数手順ある場合、推奨の手順または一番最初に記載の手順

### 対象手順書

- YugabyteDB
  - <https://docs.yugabyte.com/stable/quick-start/kubernetes/>
- TiDB
  - <https://docs.pingcap.com/tidb-in-kubernetes/stable/get-started/>
- CockroachDB
  - <https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-with-cockroachdb-operator>
