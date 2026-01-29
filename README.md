# takt-sandbox

[takt](https://github.com/nrslib/takt)（AIマルチエージェントオーケストレーションツール）をDockerコンテナ内で実行するためのサンドボックス環境。

ホストOSのファイルシステムを保護しつつ、taktのワークフローを安全に実行できる。

## 構成

```
takt-sandbox/
├── Dockerfile              # Debian slim + Node.js 20 + Claude Code + takt
├── docker-compose.yml      # volumes設定（認証・設定の共有）
├── bin/
│   └── takt                # ラッパースクリプト（ホストのtaktを置き換え）
└── setup.sh                # セットアップスクリプト（ビルド + PATH設定）
```

## セットアップ

### 前提条件

- Docker Desktop
- ホストに Claude Code がログイン済み（`claude login`）

### インストール

```bash
git clone <this-repo>
cd takt-sandbox
./setup.sh
```

`setup.sh` は以下を自動実行する:

1. Docker イメージのビルド
2. takt / Claude Code のバージョン確認
3. シェル設定ファイル（`~/.zshrc` 等）への PATH 追記

セットアップ完了後、シェルを再読み込み:

```bash
source ~/.zshrc
```

### 使い方

任意のプロジェクトディレクトリで:

```bash
cd /path/to/your/project
takt "タスクの内容"
```

ラッパースクリプトが自動的にDockerコンテナ内でtaktを実行する。

## 仕組み

- ホストの `~/.claude/.credentials.json` のみをマウントして認証情報を共有（hooks や permissions 等のホスト固有設定は持ち込まない）
- ホストの `~/.takt/` をマウントしてワークフロー・エージェント設定を共有
- プロジェクトディレクトリは `/workspace` にマウント（読み書き可能）
- ホストOSの他のファイルにはアクセスできない

## 既知の問題

### セッション競合によるエラー

**症状:** `Claude Code process exited with code 1` でワークフローが即座に失敗する。

**原因:** プロジェクトの `.takt/agent_sessions.json` に、ホスト側や以前のコンテナ実行で作られた古いセッションIDが残っている場合、taktがそのセッションを resume しようとして失敗する。

**対処:**

```bash
# プロジェクトディレクトリで実行
rm .takt/agent_sessions.json
```

または:

```bash
takt /clear
```

**発生タイミング:** ホストとコンテナを行き来して takt を使った場合、コンテナを再構築した場合など。

### コンテナ内では Docker 操作ができない

サンドボックスコンテナ内に Docker は含まれていない。プロジェクトが `docker compose` 等を必要とする場合、テストやビルドはホスト側で別途行う必要がある。

### コンテナ内の Claude Code 設定

コンテナには認証情報（`.credentials.json`）のみが共有される。ホストの `~/.claude/settings.json` にある hooks や permissions はコンテナに持ち込まれないため、コンテナ内の Claude Code はデフォルト設定で動作する。
