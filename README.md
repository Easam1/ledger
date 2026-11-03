# Ledger 記帳（電腦版）

MOZE 風格的本機記帳程式，Flutter 桌面版（Windows / macOS / Linux）。資料全部存在本機，不需網路。

## 功能（第一版：一般記帳）
- 記帳：支出／收入／轉帳、計算機鍵盤、帳戶、專案、商家、備註、**多張附圖**（點記錄可放大看）
- 總覽：餘額／支出／收入、近六個月趨勢（收入／支出／結餘）、近期記錄、月曆
- 記錄：搜尋、類型篩選、只看有附圖
- 帳戶、專案、報表（統計、類別圓餅、排行、專案、帳戶、商家）
- 設定：類別管理、載入範例資料、匯出 CSV、清除記錄

## 尚未做（之後再加）
照片分析自動記帳、語音記帳（本機 Ollama / Whisper，`server/` 內有先前的原型）、週期／分期事件、應收應付、Android 版面。

## 執行
需先安裝 Flutter SDK（3.19 以上）與各平台桌面工具鏈（Windows 需 Visual Studio 的「使用 C++ 的桌面開發」）。

```bash
cd ledger_desktop
flutter create . --platforms=windows,macos,linux   # 產生各平台資料夾（只需一次）
flutter pub get
flutter run -d windows        # 或 macos / linux
flutter build windows         # 打包成 exe
```

資料位置可在「設定」頁看到，備份時整個資料夾複製即可。

## 注意
- 這份程式碼是在無法安裝 Flutter 的環境撰寫，**尚未實際編譯**。第一次 `flutter run` 若出現編譯錯誤，把錯誤訊息貼回來即可修正。
- Windows 若啟動時找不到 sqlite3.dll，通常 `flutter pub get` 後重新 build 即可（已包含 sqlite3_flutter_libs）。

## 不想裝 Flutter？用 GitHub 自動打包 EXE
1. 在 GitHub 建一個新的 repository，把這個資料夾的內容全部上傳（含 `.github` 資料夾）。
2. 到 repository 的 Actions 頁籤 → 「Build Windows EXE」→ Run workflow。
3. 約 5～10 分鐘後，在該次執行頁面下方 Artifacts 下載 `Ledger-windows`，解壓縮後執行裡面的 `ledger.exe`（整個資料夾要一起保留）。
