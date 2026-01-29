# takt-sandbox

[takt](https://github.com/nrslib/takt)（AIマルチエージェントオーケストレーションツール）をDockerコンテナ内で実行するためのサンドボックス環境。

ホストOSのファイルシステムを保護しつつ、taktのワークフローを安全に実行できる。

## 構成

```
takt-sandbox/
├── Dockerfile              # Debian slim + Node.js 20 + Claude Code + takt
├── docker-compose.yml      # volumes・環境変数設定
├── entrypoint.sh           # コンテナエントリポイント
├── bin/
│   └── takt                # ラッパースクリプト（認証トークン取得 + Docker実行）
└── setup.sh                # セットアップスクリプト（ビルド + PATH設定）
```

## セットアップ

### 前提条件

- Docker Desktop
- ホストに Claude Code がログイン済み（`claude login`）
- Python 3（macOS / Linux で標準搭載）

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

## 認証

ラッパースクリプト (`bin/takt`) が以下の優先順で認証情報を取得し、環境変数としてコンテナに渡す:

1. **環境変数 `CLAUDE_CODE_OAUTH_TOKEN`** — 既に設定されている場合はそのまま使用
2. **環境変数 `ANTHROPIC_API_KEY`** — API キーが設定されている場合はそのまま使用
3. **macOS キーチェーン** — `security` コマンドで `Claude Code-credentials` から OAuth トークンを抽出
4. **`~/.claude/.credentials.json`** — Linux 環境で使用されるファイルベースの認証

> **注意:** macOS の Claude Code はキーチェーンに認証情報を保存し、`.credentials.json` は使用しない。

## 仕組み

- Claude Code のセッションデータは named volume (`claude-data`) で永続化。セッション継続（resume）が可能
- 認証は OAuth トークンを `CLAUDE_CODE_OAUTH_TOKEN` 環境変数でコンテナに渡す（ファイルマウント不要）
- ホストの `~/.takt/` をマウントしてワークフロー・エージェント設定を共有
- プロジェクトディレクトリは `/workspace` にマウント（読み書き可能）
- ホストOSの他のファイルにはアクセスできない

## 既知の問題

### セッション競合によるエラー

**症状:** `Claude Code process exited with code 1` でワークフローが即座に失敗する。

**原因:** プロジェクトの `.takt/agent_sessions.json` に古いセッションIDが残っており、named volume 内に対応するセッションデータがない場合に発生する。Docker volume を削除した場合や、ホスト側で直接 takt を使った後にコンテナ経由で実行した場合に起きやすい。

**対処:**

```bash
# プロジェクトディレクトリで実行
rm .takt/agent_sessions.json
```

または:

```bash
takt /clear
```

### コンテナ内では Docker 操作ができない

サンドボックスコンテナ内に Docker は含まれていない。プロジェクトが `docker compose` 等を必要とする場合、テストやビルドはホスト側で別途行う必要がある。

### ワークフローが BLOCKED で中断する

**症状:** `Workflow blocked and no user input provided` でワークフローが途中で中断する。

**原因:** takt のエージェント（planner や coder）がユーザーへの確認事項を返した場合、コンテナ内ではユーザー入力を受け付けられないため BLOCKED 状態になりワークフローが中断する。これは sandbox 固有の問題ではなく、takt の非対話実行時の仕様。

**対処:** タスクの指示をより具体的にして、エージェントが確認を必要としないようにする。曖昧な要件や設計判断が必要な箇所は、あらかじめ指示に含めておく。

```bash
# NG: 曖昧な指示 → エージェントが確認事項を返して BLOCKED になりやすい
takt "この機能を改修して"

# OK: 具体的な指示 → エージェントが判断に迷わず実装まで進みやすい
takt "XXX関数のYYY処理を削除し、ZZZ条件でフィルタするように変更して"
```

### コンテナ内の Claude Code 設定

コンテナには認証トークンのみが環境変数で渡される。ホストの `~/.claude/settings.json` にある hooks や permissions はコンテナに持ち込まれないため、コンテナ内の Claude Code はデフォルト設定で動作する。
