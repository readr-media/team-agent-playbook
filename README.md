# team-agent-playbook

團隊 AI 輔助開發的共同規範，透過 GitHub Actions 自動同步進每個團隊 repo。

## 這個 repo 在做什麼

維護一份 canonical 的 `AGENTS.md`（[Linux Foundation Agentic AI Foundation 標準](https://agents.md/)），自動同步進每個團隊 repo。每個 target repo 還會額外收到：

- `CLAUDE.md` — 一行 `@AGENTS.md` import，讓 Claude Code 也讀到同一份規則
- `.gemini/settings.json` — 最小設定，讓 Gemini CLI 也讀 `AGENTS.md`

Codex CLI 與 Cursor 原生支援 `AGENTS.md`，不需要任何搭橋檔。

## 架構

```
readr-media/team-agent-playbook       ← canonical（public，本 repo）
  ├─ mirror-media/team-agent-playbook ← fork
  ├─ mirror-tv/team-agent-playbook    ← fork
  └─ mirrordaily/team-agent-playbook  ← fork
```

- 每個 fork 用該 org 自己的 PAT 執行同步流程，**只寫該 org 內的 repos**。
- canonical 更新後，3 個 fork 各自決定何時 sync（GitHub「Sync fork」或開內部 PR）。
- 沒有任何 PAT 跨 org 寫入，安全範圍與所有權清楚。

## Repo 結構

```
base/                       ← 會被同步進每個 target repo 的檔案
  AGENTS.md                 ← 團隊規範（含 TEAM-BASE 標記）
  CLAUDE.md                 ← @AGENTS.md import + 可選的 Claude-only 規則
  .gemini/settings.json     ← context.fileName 包含 AGENTS.md

templates/                  ← 一次性 scaffold，不會被同步
  SPEC.md                   ← 各專案架構與決策的骨架

scripts/
  update_base_section.py    ← 替換 target AGENTS.md 的 TEAM-BASE 區塊
  merge_gemini_settings.py  ← 合併 .gemini/settings.json 而不覆蓋既有設定
  sync.sh                   ← 主流程（由 Action 呼叫）
  init.sh                   ← 新 target repo 一次性 scaffold

.github/workflows/
  sync-agents.yml           ← base/** 變動時觸發；執行 scripts/sync.sh
```

## 同步流程怎麼運作

工作流程透過 GitHub topic `team-agent-playbook-managed` 在該 org 內搜尋 target repos（archived repos 會自動略過）。對每個納管的 repo：

1. **`AGENTS.md`** — 呼叫 `update_base_section.py`：
   - 檔案不存在：建立完整模板
   - 有 `<!-- TEAM-BASE-START -->` / `<!-- TEAM-BASE-END -->` 標記：只替換標記之間的內容（`## Project Customization` 區塊保留不動）
   - 檔案存在但無標記：印 GitHub Actions warning 並略過該 repo（需手動初始化）
2. **`CLAUDE.md`** — 確保第一行為 `@AGENTS.md`。檔案不存在則建立；import 在其他位置則移到首行；其他內容保留。
3. **`.gemini/settings.json`** — 呼叫 `merge_gemini_settings.py`，把必要的 `context.fileName` entries 合併進去，不覆蓋其他 keys。

只要任何檔案有變動，工作流程就會開一個 PR，title 為 `chore: sync AGENTS.md base (commit <hash>)`。單一 repo 失敗會印 warning，但不會中斷整個流程。

## SOP

### 更新 canonical 規範

1. 對 `main` 開 PR 編輯 `base/AGENTS.md`。
2. 取得至少一位團隊 maintainer 的 approval。
3. Merge。Action 自動執行，對每個納管的 repo 開 sync PR。

如果是 breaking changes（例如改動 TEAM-BASE 標記語法、刪除某個關鍵章節），PR title 加上 `[BREAKING]` prefix，並在 PR body 說明遷移方式。

### 把新的 repo 納入管理

target repos 透過 GitHub topic 自動發現，不需要維護中央清單。讓某個 repo 加入管理：

1. 在本機執行 `scripts/init.sh /path/to/target/repo`，把 `templates/SPEC.md` 放進去並把 `AGENTS.local.md` 加到 `.gitignore`。
2. Commit 並 push 初始化變更到 target repo。
3. **加上 topic `team-agent-playbook-managed`**：
   ```sh
   gh repo edit <org>/<repo> --add-topic team-agent-playbook-managed
   ```
   或在 GitHub 網頁上 Settings → Topics 加。
4. 手動觸發 sync workflow（`Actions → Sync AGENTS.md → Run workflow`）。第一次執行會透過 PR 建立 `AGENTS.md`、`CLAUDE.md`、`.gemini/settings.json`。

要退出管理就把 topic 拿掉。Archived repos 自動跳過。

### 把既有不合規的 `AGENTS.md` 遷移進來

如果 target repo 已經有 `AGENTS.md` 但**沒有** TEAM-BASE 標記，工作流程會印 warning 並略過。要遷入管理：

1. 手動把現有內容裡屬於團隊共用的部分用 `<!-- TEAM-BASE-START -->` 與 `<!-- TEAM-BASE-END -->` 包起來。專案特有規則移到結尾標記之後的 `## Project Customization` 章節。
2. Commit。下次 sync 就能正常替換標記之間的內容。

## 長期耐久原則

`base/AGENTS.md` 的維護者應該守住這幾條原則，避免把不必要的變動每天散播給所有 repo：

- **不綁工具版本。** `AGENTS.md` 會被多種工具讀，每家更新節奏不同。寫「Claude Code v2.x」這種規則會很快過時。
- **不綁流程細節。** 「PR 必須週四前 merge」這類東西不該寫進團隊憲法。
- **不把個人偏好包裝成規則。** 只有一個人在意的事，不算團隊標準。
- **Breaking changes 一定要明確標示。** PR 變動會讓既有 `## Project Customization` 失效（例如改標記語法）時，title 加 `[BREAKING]`，body 寫遷移路徑。

## 初始化清單（canonical repo）

- [ ] Repo visibility：**public**
- [ ] License：見 `LICENSE`
- [ ] Description 與 topics 填妥（建議 `agents-md`、`ai-coding`、`team-standards`）
- [ ] `main` 啟用 branch protection：require ≥1 PR review
- [ ] Repo secret `GH_TOKEN`：PAT，需該 org 內 target repos 的 contents:write 與 pull-requests:write 權限

target repos 透過 topic 發現，不需要中央清單。任何要納管的 repo 加上 topic `team-agent-playbook-managed` 即可。

forks（mirror-media、mirror-tv、mirrordaily）重複同樣的 secret 設定，scope 限自家 org 的 PAT。

## License

MIT — 見 [LICENSE](LICENSE)。
