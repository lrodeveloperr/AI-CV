# Japanese App Store listing draft

**Status:** `DRAFT_READY` — copy and commercial decisions are locked. Submission remains blocked on the final build, authentic screenshots, live policy/support URLs, App Store Connect configuration, and archive-level privacy/compliance checks.

The authoritative product scope is [`product/PRODUCT_SCOPE.md`](product/PRODUCT_SCOPE.md). Prices and entitlements are controlled by [`product/PRICING_AND_ENTITLEMENTS.md`](product/PRICING_AND_ENTITLEMENTS.md); this listing must remain consistent with that file.

## 1. Product-page metadata

### App name — 14/30 characters

**Production Japanese:** `履歴書・職務経歴書 AI作成`

**English:** [AI Résumé & Work History Maker]

This retains the two strongest high-intent Japanese search concepts while avoiding the misleading “fully local” claim when a user voluntarily enables private iCloud sync.

### Subtitle — 22/30 characters

**Production Japanese:** `登録不要・自己PR作成・和暦対応・PDF出力`

**English:** [No account, self-promotion writing, Japanese-era support, PDF export]

### Promotional text — 108/170 characters

**Production Japanese:**

> 登録不要で履歴書・職務経歴書を作成。和暦にも対応し、プレビューと同じPDFを書き出せます。Apple Intelligence対応端末では、確認済みの経歴から自己PRや志望動機の文章を提案します（AI機能はPro）。

**English:** [Create résumés and work-history documents without an account. On Apple Intelligence-capable devices, on-device AI suggests self-promotion and motivation text from your confirmed career facts. Export a PDF identical to the preview. AI features are Pro.]

### Keywords — 98/100 UTF-8 bytes

**Production field:** `就活,転職,志望動機,送付状,添え状,証明写真,レジュメ,カバーレター,職歴`

**English:** [job hunting, career change, motivation, cover letter, cover letter (alternate term), ID photo, résumé (loanword), cover letter (loanword), work history]

The name/subtitle terms are intentionally not repeated in the keyword field. 就活 and 転職 are the short forms users actually search; Apple does not reliably match them as substrings of 就職活動/転職活動.

### Full description

**Production Japanese:**

> 登録不要で、履歴書・職務経歴書・送付状を作成してPDFで書き出せる、就職・転職活動のための書類作成アプリです。和暦（令和・平成など）にも対応しています。
>
> 入力した経歴はお使いの端末に保存されます。Apple Intelligenceに対応した端末では、端末内のAIが、あなたが確認した経歴の事実だけをもとに、自己PR・志望動機・職務要約の文章を提案します。提案は承認するまで書類に反映されず、勤務先・在籍期間・資格などの事実は変更されません。
>
> 【主な機能】
> ・履歴書、職務経歴書、送付状の作成
> ・西暦・和暦の入力と表示
> ・書類をスキャンして文字認識（OCR）で入力を補助
> ・自己PR、志望動機、職務要約の文章を提案（Apple Intelligence対応端末のみ）
> ・文章の短縮、言い換え、応募先に合わせた調整
> ・提出するPDFと同じ仕上がりをプレビューで確認
> ・ページ数、入力漏れ、文字の見切れ、ファイルサイズをチェック
> ・PDFの共有と印刷
> ・応募先、選考状況、提出書類の管理
> ・iCloud同期（任意）でお手持ちのデバイス間でデータを同期
>
> 【無料でできること】
> 履歴書1件・職務経歴書1件の作成、完成プレビュー、PDFの書き出し（1回）をご利用いただけます。アカウント登録は不要です。
>
> 【Proでできること】
> 書類、応募先別バージョン、PDF書き出しが無制限になります。さらに、AIによる文章作成、OCR入力、送付状、応募管理、バージョン履歴、証明写真の調整、プライベートiCloud同期をご利用いただけます。
>
> 【ご注意】
> ・AIが提案した文章は、提出前に必ずご自身で内容をご確認ください。
> ・AI機能は、端末、OSのバージョン、言語、Apple Intelligenceの設定・利用状況によってはご利用いただけません。AIをご利用いただけない端末でも、手入力での編集、PDF作成、応募管理などの基本機能はお使いいただけます。
>
> 【Proのご案内（自動更新）】
> ・プランは月額と年額の2種類です。料金は購入画面に表示されます。
> ・購入の確認時にApple Accountへ請求されます。
> ・現在の期間が終了する24時間以上前に解約しない限り、同じ期間で自動的に更新されます。
> ・購入の復元とサブスクリプションの管理は、アプリ内のPro画面から行えます。
>
> 利用規約: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
> プライバシーポリシー: https://worksbienstudios.com/apps/rirekisho-ai/privacy/

**English working translation:**

[AI Résumé & Work History Maker lets you create the documents needed for job hunting and career changes in Japan without registering for an account.

Your career records are managed on-device. On supported devices, Apple's on-device AI proposes self-promotion, motivation, and career-summary text using only facts you have confirmed. AI never silently changes factual details such as employers, employment periods, or qualifications.

Main features: create résumés, work-history documents, and cover letters; use Gregorian or Japanese-era dates; scan documents and recognize text to assist data entry; receive AI writing suggestions from confirmed career facts on supported devices; shorten, rewrite, and tailor text; preview the exact final PDF; check page count, missing fields, clipped text, and file size; share and print PDFs; track applications, selection status, and submitted documents; and optionally keep data across your own devices using private iCloud sync.

Free includes one résumé, one work-history document, exact preview, and one PDF export, with no account required.

Pro includes unlimited documents, application-specific variants, and PDF exports, plus supported-device AI writing, OCR input, cover letters, application tracking, version history, portrait adjustments, and private iCloud sync.

Always review AI suggestions before submitting. AI availability depends on device, OS, language, and Apple's system-model availability. Devices without AI support can still use manual editing, PDF creation, application tracking, and the other core features.

Pro is an auto-renewable subscription. Payment is charged to the Apple Account at confirmation and renews unless canceled at least 24 hours before renewal. Purchases can be restored and subscriptions managed from the app. Refer to the purchase screen for the localized App Store price.]

### What's New

Not applicable to version 1.0. For the first update, describe only shipped changes verified in that build.

## 2. Classification and availability

| Field | Locked draft value |
|---|---|
| Platform | iOS/iPadOS universal app |
| Version | 1.0 |
| Release | Manual release after approval |
| App price | Free |
| Primary language | Japanese |
| Initial storefront | Japan |
| Primary category | Productivity |
| Secondary category | Business |
| Age rating | Planned 4+; complete the current questionnaire against the final build |
| Account required | No |
| Ads | No |
| User-generated public content | No |
| Third-party content | No |
| Tracking | No |
| Encryption | Apple platform encryption only; final export-compliance answer pending archive inspection |
| Copyright | © 2026 WorksBien Studios Inc. |
| SKU | `RIREKISHO-AI-IOS-001` |
| Recommended bundle ID | `com.worksbienstudios.rirekishoai` |

Category availability and the exact age-rating result must be reconfirmed in the current App Store Connect record.

## 3. URLs

These are the intended public endpoints and must be published and tested before submission:

- Support: `https://worksbienstudios.com/apps/rirekisho-ai/support/`
- Privacy: `https://worksbienstudios.com/apps/rirekisho-ai/privacy/`
- Marketing: `https://worksbienstudios.com/apps/rirekisho-ai/`
- Terms: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

Do not submit placeholder, redirecting, access-controlled, or non-responsive URLs.

## 4. In-app purchases

### Pro monthly

- Reference name: `Rirekisho AI Pro Monthly`
- Recommended product ID: `com.worksbienstudios.rirekishoai.pro.monthly`
- Type: Auto-renewable subscription
- Duration: One month
- Japan price: ¥500
- Display name: プロ（月額） [Pro (Monthly)]
- Description: すべてのPro機能を1か月ごとに利用 [Use all Pro features, billed monthly]

### Pro annual

- Reference name: `Rirekisho AI Pro Annual`
- Recommended product ID: `com.worksbienstudios.rirekishoai.pro.annual`
- Type: Auto-renewable subscription
- Duration: One year
- Japan price: ¥3,000
- Display name: プロ（年額） [Pro (Annual)]
- Description: すべてのPro機能を1年ごとに利用 [Use all Pro features, billed annually]

Both products belong to one subscription group. The annual option should be visually recommended and may state the calculated equivalent of ¥250/month in the paywall, using StoreKit-derived localized price data. Product IDs are immutable after creation; confirm the bundle identifier before creating them.

## 5. App Privacy draft

**Planned label:** Data Not Collected.

This is a plan, not a final declaration. It is valid only if the shipped build has no developer-accessible analytics, advertising, external AI, crash-reporting upload, account backend, or other collection. Private CloudKit data and StoreKit behavior must be evaluated against Apple's current definitions using the final build.

Permissions:

- Camera: requested only after the user selects document scanning.
- Photos: system photo picker; do not request broad library access.
- Face ID/Touch ID: requested only after the user enables app lock.
- iCloud: used only after the user enables synchronization.
- No location, microphone, contacts, advertising identifier, or tracking permission.

Suggested camera usage text:

- Japanese: `履歴書や職務経歴書を読み取り、入力を補助するためにカメラを使用します。`
- English: [The camera is used to scan résumés and work-history documents to assist data entry.]

Suggested Face ID usage text:

- Japanese: `保存した経歴と応募書類を保護するためにFace IDを使用します。`
- English: [Face ID is used to protect your saved career history and application documents.]

## 6. Screenshot story

Use authentic final UI and consistent fictional sample data. Do not place a feature in a screenshot unless it works in the submitted build. Prepare current accepted iPhone and iPad sizes after checking Apple's live screenshot specifications.

1. **Outcome**
   - Japanese caption: 登録不要。履歴書は端末内で完成 [No account. Complete your résumé on-device.]
   - UI: exact résumé preview with a clear “free” context and fictional data.
2. **AI path — label as Pro**
   - Japanese caption: 確認した経歴からAIが文章を提案 [AI suggests wording from facts you confirmed.]
   - UI: fact chips, proposed paragraph, diff/approve controls, and a visible プロ [Pro] badge.
3. **Proof**
   - Japanese caption: 完成PDFを確認して、そのまま提出 [Preview the final PDF and submit it directly.]
   - UI: PDF preflight with page count, file size, validation status, and native share action.

Optional later screenshots may cover OCR import, Japanese-era conversion, application tracking, and private iCloud sync. The icon concept is a crisp document silhouette with a verification check and restrained native-AI sparkle; it must contain no small text and must be tested at search-result size.

## 7. App Review notes

Paste only after paths and labels match the final build:

> This app does not require an account. The reviewer can create one résumé and one work-history document, preview both, and export one PDF without purchasing.
>
> Core review path: launch → “Start without an account” → create a career profile → add sample employment/education → create a document → preview PDF → share/export.
>
> Pro purchase path: Settings → Pro. “Restore Purchases” and “Manage Subscription” are on the same screen. The free path remains available if no purchase is made.
>
> AI drafting uses Apple's on-device Foundation Models framework and is shown only when the current device, OS, language, and model availability support it. It sends no prompts to our server and never directly changes canonical dates, employers, qualifications, or other facts. Generated text appears as a proposal and requires explicit approval. If AI is unavailable, the app explains why; manual editing, OCR, PDF creation, tracking, and sync remain testable.
>
> Camera permission appears only after Scan Document is selected. Face ID/Touch ID permission appears only after App Lock is enabled. Photo import uses the system picker. Private iCloud sync is optional.
>
> No reviewer login or special hardware is required. No third-party AI, analytics, advertising, or account SDK is included.

The private App Review contact name, telephone number, and email must be entered directly in App Store Connect and must not be committed to this public repository.

## 8. Localization rule

The production `ja` metadata contains natural Japanese only. This document pairs Japanese with English working translations for team review; do not paste the bracketed English translations into the Japanese App Store fields.
