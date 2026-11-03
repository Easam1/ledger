# 本機 AI 記帳軟體（暫名 Ledger）設計文件

目標平台：Android + Windows / macOS / Linux 桌面（Flutter 單一程式碼庫，之後可加 Web PWA）
參考：MOZE 4.0（專案、帳戶、類別、報表、月曆、快速記帳）
核心差異：每筆記錄可附圖當明細、拍照／截圖／語音自動記帳、AI 全部在本機執行

---

## 1. 產品原則

1. 少打字：能用圖片、語音、AI 帶入的欄位，不要求手動輸入。
2. 圖片即明細：收據、發票、截圖原圖永遠跟著記錄保存，點開就能對帳。
3. 本機優先：資料在 SQLite，AI 走本機 Ollama / Whisper，不依賴雲端帳號。
4. 先確認再入帳：AI 只負責「預填」，使用者按確認才寫入（可設定高信心度自動入帳）。

## 2. 功能規格

### 2.1 記帳（對應 MOZE 的「新增記錄」）
| 項目 | 說明 |
|---|---|
| 記錄類型 | 支出 / 收入 / 轉帳 / 應收 / 應付 / 系統（手續費、折扣、利息） |
| 欄位 | 金額、幣別、名稱、類別、帳戶、專案、商家、標籤、對象、日期時間、備註 |
| 附圖 | 一筆可附多張圖片（拍照、相簿、截圖、PDF 之後再做），縮圖顯示於列表與詳情 |
| 明細項目 | 一筆記錄下可有多個品項（品名、數量、單價、類別），對應 MOZE「單筆記錄支援多張發票歸帳」 |
| 快速記帳 | 桌面：全域快捷鍵；Android：桌面小工具／App Shortcut／分享選單 |

### 2.2 AI 記帳（全部本機）
| 入口 | 流程 |
|---|---|
| 拍照記帳 | 相機 → 視覺模型讀收據 → 回傳 JSON（商家、日期、總額、品項、建議類別）→ 預填表單，原圖自動附上 |
| 截圖記帳 | 選取行動支付／轉帳／網銀截圖（或分享到 App）→ 同上 |
| 語音記帳 | 按住說話 →「中午吃牛肉麵 一百二十 用現金」→ Whisper 轉文字 → 文字模型抽欄位 → 預填 |
| 批次匯入 | 一次選多張圖，背景佇列逐張處理，完成後進「待確認」收件匣 |
| 品項自動分類 | 對每個品項建議類別，使用者修正後寫入「商家／品名 → 類別」規則表，下次優先套用，不必再問 AI |

### 2.3 帳戶與專案
- 帳戶、帳戶分組、多幣別（含加密貨幣，匯率手動或可選擇抓取）。
- 專案（生活開銷、投資理財、旅遊…）、專案預算、統計專案。
- 類別、標籤、對象、商家皆為可管理清單。

### 2.4 報表與總覽
- 總覽：餘額／支出／收入卡片、期間趨勢圖、月曆（每日收支點）、即將到來的週期／分期事件。
- 報表：統計、排行、類別、帳戶、帳戶分組、專案、名稱、商家、標籤、對象、明細。
- 比較報表：多維度 × 跨時段表格。
- 搜尋：關鍵字、金額區間、日期、類別、是否有附圖。

### 2.5 資料與備份
- 匯入／匯出 CSV（相容 MOZE 欄位，方便從 MOZE 搬資料）。
- 本機備份（單一 zip：SQLite + 圖片）；可選擇同步資料夾（Syncthing／網路磁碟／Dropbox 資料夾），不綁帳號。
- 密碼／生物辨識鎖定。

## 3. 畫面結構

```
左側導覽（桌面）／底部導覽（手機）
├─ 總覽        餘額卡片 · 趨勢圖 · 月曆 · 待確認收件匣
├─ 專案        專案列表 → 預算／交易明細
├─ 帳戶        帳戶分組 · 餘額 · 轉帳
├─ 報表        統計 / 排行 / 類別 / 比較 …
├─ 記錄        全部明細（可篩選，縮圖預覽）
├─ 設定        類別 · 標籤 · 規則 · AI 模型 · 備份 · 匯入匯出
└─ ＋ 新增     手動 / 拍照 / 截圖 / 語音
```

新增記錄頁（參考 MOZE 截圖）：頂部分頁（支出、收入、應收、應付、系統）→ 類別圖示格 → 圖片區＋金額＋名稱 → 帳戶／專案／商家／單次／日期／時間 → 標籤 → 備註。桌面為雙欄（右側數字鍵盤＋常用帳戶／專案），手機為單欄＋底部鍵盤。
AI 按鈕（相機、截圖、麥克風）固定在金額欄旁。

## 4. 資料庫（SQLite）

```
accounts(id, name, group_id, currency, initial_balance, icon, archived)
account_groups(id, name, sort)
categories(id, name, type, icon, color, parent_id, sort)
projects(id, name, icon, start, end, is_stats_only, budget_total)
project_budgets(id, project_id, category_id, amount)
entries(id, type, amount, currency, fx_rate, title, category_id, account_id,
        to_account_id, project_id, merchant_id, counterparty_id, note,
        ts, status[confirmed|pending], source[manual|photo|screenshot|voice|csv],
        ai_confidence, created_at, updated_at)
entry_images(id, entry_id, path, kind[receipt|screenshot|other], sha256, ocr_text)
entry_items(id, entry_id, name, qty, unit_price, amount, category_id)
entry_tags(entry_id, tag_id)
merchants(id, name) · tags(id, name) · counterparties(id, name)
category_rules(id, pattern, category_id, project_id, hits)      -- 使用者修正後學到的規則
recurring(id, template_json, rrule, next_run) · installments(...)
settings(key, value)
```
圖片檔存於 `<app data>/attachments/yyyy/mm/<sha256>.jpg`，資料庫只存相對路徑；以 sha256 去重。

## 5. 本機 AI 架構

```
[App]──HTTP──► Ollama  (視覺模型：收據/截圖 → JSON；文字模型：語音文字 → JSON)
   │  └──HTTP──► whisper_server.py (faster-whisper：音檔 → 文字)
   └─ 規則表命中則略過 LLM
```
- 建議模型（依硬體調整）：視覺 `qwen2.5vl:7b`（顯存不足可用 `qwen2.5vl:3b`），文字 `qwen2.5:7b`，語音 `faster-whisper small/medium`（繁中）。
- 輸出強制 JSON（Ollama `format: "json"`），欄位：`type, amount, currency, title, merchant, category, date, items[]`，金額再由程式驗算（品項加總 vs 總額，不符則標記低信心度）。
- 桌面：AI 服務跑在同一台電腦；Android：連到家中電腦的區網 IP（設定頁填入位址），App 本身不內建大型模型。
- 提示詞包含使用者目前的類別清單與規則，要求只從清單中選類別。
- 失敗策略：AI 不可用時，圖片仍可手動附上，欄位留空，不阻擋記帳。

## 6. 開發路線

| 階段 | 內容 |
|---|---|
| M1 原型（本專案已含） | SQLite、新增記錄、附圖、記錄列表／詳情、總覽、Ollama 收據辨識、Whisper 語音 |
| M2 | 帳戶／專案／預算、轉帳、類別管理、待確認收件匣、規則學習 |
| M3 | 報表（統計、排行、比較）、月曆、搜尋、CSV 匯入匯出（MOZE 格式） |
| M4 | 週期／分期事件、多幣別、備份／同步資料夾、鎖定 |
| M5 | Android 分享選單與桌面小工具、桌面全域快捷鍵、Web PWA 評估 |

## 7. 風險與備註

- 手機辨識品質取決於家中電腦的模型；建議先用 20～30 張自己的收據做準確率測試再調整提示詞。
- 台灣電子發票可另加 QR Code 解析（左右兩個 QR 含品項），比視覺模型更準，列為 M2 加分項。
- 原型程式碼尚未在 Flutter 環境實際編譯過，首次執行請先 `flutter create .` 補平台資料夾（見 README）。
