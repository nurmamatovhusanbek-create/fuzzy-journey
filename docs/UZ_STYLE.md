# Uzbek text: style guide and review process

The Uzbek strings (`godot/data/i18n/uz.json`, 2,025 keys) were first written by an AI, not a native speaker. A native reader found they do not sound native. This is how we fix that: decide the **words** first, then the **register**, then let natives edit in a sheet, with tools that stop the usual mistakes from coming back.

## 1. Orthography (done, enforced)
* Latin alphabet of the 2023 reform. `oʻ` and `gʻ` use **U+02BB** (ʻ). The tutuq belgisi (`maʼno`, `eʼlon`, `qalʼa`) uses **U+02BC** (ʼ). The file used three different marks (‘ 772×, ’ 48×, ' 47×); now one rule. `tools/uz_normalize.py --check` runs in `tools/test_all.sh`; `tools/add_i18n.py` normalises new strings by itself.
* Sentence case, no exclamation marks, no ALL CAPS in the data (the game capitalises titles itself).

## 2. Register
* Formal: **Siz** (polite plural) in every address; no *sen*.
* Dialog and tip sentences: polite imperative **-ing** (`Tanlang`, `Tasdiqlang`, `Navbatni tugating`).
* Buttons and menu items: the verbal noun **-ish** (`Saqlash`, `Bekor qilish`, `Yuklash`).
* Titles and labels: noun phrases (`Soliq siyosati`), not sentences.
* Numbers: a counted noun stays singular (`5 viloyat`, `3 ta viloyat`), never `5 viloyatlar`.
* Possession in the Uzbek way: `viloyatning aholisi`, not an English-order calque.

## 3. Words
* One word for one thing across the whole game. The audit found: treasury `xazina` (18) and `gʻazna` (10); army `qoʻshin` (82) and `armiya` (14); peace `sulh` (24) and `tinchlik` (15); envoy `elchi` (20) and `diplomat` (37).
* Prefer the Uzbek word where a standard one exists (`qoʻshin`, `viloyat`, `xazina`); keep international loans where Uzbek uses them (`diplomatiya`, `ultimatum`, `port`).
* `tools/uz_glossary.json` lists the 17 terms that matter most (each is used in dozens to hundreds of places), with what is there now and what I suggest, and why. **Native speakers decide these first**; one decision then spreads to every string.

## 4. Known limits
* Case endings are attached to names that the game fills in (`{b}ga`, `{a}dan`): 22 strings. These are right for most names but wrong after some endings (`-ka/-qa` after k/q, `-ning/-ni` rules). The better way is a postposition (`{b} bilan`, `{a} uchun`). A native should say which of the 22 to rewrite.
* Machine drafts tend to be word-for-word: check order, idiom, and whether a real Uzbek player would say it.

## 5. The process
1. `python3 tools/uz_review.py sheet.csv` builds the sheet (tier 1 glossary, tier 2 short UI strings, tier 3 long texts; `--since <commit>` limits it to strings that are new or changed). It opens in Excel or Google Sheets.
2. A native writes the better text in the column **Corrected (native)** (empty = fine).
3. `python3 tools/uz_import.py sheet.csv` applies it. It refuses a row whose `{placeholders}` differ from the English, and normalises apostrophes.
4. Glossary decisions are then applied across the file (a replace pass, then a native read of the changed lines), and the UI overflow tests check nothing got too long.
5. A machine translator such as Tilmoch can be a second opinion, never the authority.
