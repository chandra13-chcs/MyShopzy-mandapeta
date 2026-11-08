# MyShopzy Rider - Flutter app - STATUS

Read this file first, before changing anything. Frontend only, mock data
layer, Provider for state. See scope rules at the end.

## DONE (Features 1-9 all written)
- Feature 1: login (name + phone), mock OTP, splash
  (`main.dart`, `app_strings.dart`, `rider.dart`, `auth_service.dart`,
  `primary_button.dart`, `splash_screen.dart`, `login_screen.dart`, `otp_screen.dart`)
- Feature 2: Home with bottom tabs + Online/Offline switch + today stats
  (`screens/home_screen.dart`). Cannot go offline during an active delivery.
- Feature 3: incoming order popup, 30s countdown, accept/reject, timeout=reject,
  **queue for orders that arrive while busy** (see this round, below)
  (`widgets/incoming_order_card.dart`, `services/order_repository.dart` (abstract),
  `services/mock_order_service.dart`, `services/rider_controller.dart`)
- Feature 4: 5-step active delivery (`screens/active_delivery_screen.dart`)
- Feature 5: call shop/customer + Google Maps, both legs of the trip
  (`utils/format.dart`: callNumber, openMaps, openRoute)
- Feature 6: delivery OTP + photo proof (`screens/delivery_proof_screen.dart`, image_picker)
- Feature 7: earnings (today/7 days/total) + history, **now with a tap-through
  detail screen showing the proof photo** (`screens/earnings_screen.dart`,
  `screens/history_detail_screen.dart`)
- Feature 8: COD collect checkbox, cash-in-hand + deposit, withdraw,
  **now requires a saved UPI ID / bank account first** (`screens/wallet_screen.dart`)
- Feature 9: profile, avg rating, notifications list + on/off, language
  English/Telugu/Hindi (`screens/profile_screen.dart`,
  `screens/notifications_screen.dart`, `constants/translations.dart`)
- Active delivery is saved and restored after closing the app (`Order.toJson/fromJson`,
  `RiderController.load/_save`). A "Resume current delivery" card shows on Home.
- "Report a problem" on the delivery screen (shop closed, customer not answering,
  wrong address, vehicle problem): releases the order, adds a notification,
  calls `OrderRepository.rejectOrder`. (`reportIssue` in the controller.)
- Emergency (SOS) button in the delivery screen app bar: calls 112.
- Daily target card on Home (`RiderController.dailyTarget`, `dailyBonus`;
  the bonus is DISPLAY ONLY - a backend must pay it).
- Login + OTP screens translated (English/Telugu/Hindi) with a language
  picker on the login screen.
- Rider document verification (KYC) demo: Aadhaar/PAN details and three photos,
  pending/approved/rejected states, simulated admin decision, and online gating.

## ADDED IN SESSION 9 (still never compiled)
- **Order cancelled mid-delivery**: `OrderRepository.cancelledOrders` (Stream of order ids).
  The controller handles all 3 cases: popup on screen (closes it), waiting in the queue
  (removes it), active delivery (releases it and shows a full-screen "Order cancelled"
  notice from `widgets/incoming_order_overlay.dart`; OK returns to Home; extra text if the
  rider had already picked up). New: `RiderController.cancelled`, `acknowledgeCancelled()`.
- **Loading + error states** (the real server can fail): `accept()` now asks the server first
  (spinner on the Accept button, `accepting`), `completeDelivery()`, `withdraw()` and the new
  `depositCash()` return an error key (null = success) shown on screen; the rider can retry.
  Wallet shows a progress bar and disables buttons while a call runs.
- **Backend handoff**: `API_CONTRACT.md` (every call + JSON the server must provide) and
  `lib/services/api_order_repository.dart` (compiling skeleton, NOT wired in).
- **Mock test switches** in `MockOrderService`: `cancelOneIn` (default 5 = 1 in 5 accepted
  orders is cancelled 25 s later; 0 = never) and `failOneIn` (default 0; set 4 to make 1 in 4
  server calls fail). Change them to test the new screens.
- 7 new translation keys (161 per language).
Tests: accept a few orders - one should get cancelled after ~25 s (notice + back to Home);
set `failOneIn = 3`, then try Accept / Confirm delivery / Withdraw / Deposit and see the
error messages and retry.
Known edge: if the rider goes offline during the 0.4 s "accepting" wait, the server may have
accepted while the app reports a failure. Tell the backend to expire unconfirmed accepts.

## ADDED IN SESSION 8 (still never compiled)
Real-world features that need no backend. Files changed: `models/order.dart`,
`services/rider_controller.dart`, `services/mock_order_service.dart`,
`utils/format.dart`, `constants/translations.dart` (154 keys x en/te/hi),
`widgets/incoming_order_card.dart`, and screens `home`, `active_delivery`,
`notifications`, `earnings`, `profile`.
- **Accurate order countdown**: the 30 s popup timer now counts against a real
  deadline (not "minus 1 per tick"), so it stays correct if the phone pauses the app.
- **Tip, customer note, ETA**: `Order.tip` (already INCLUDED in `earning`),
  `Order.note`, `Order.etaMinutes` (getter). Shown on the popup and delivery screen.
  Old saved orders without these fields still load. Backend: send `tip` + `note`.
- **Pickup checklist**: at "Picked up the order" the rider must tick every item
  (`_confirmPickup` in `active_delivery_screen.dart`; items = `Order.items` split by commas).
- **Trip timer**: live clock since accepting (`RiderController.acceptedAt`, saved with
  the active delivery); turns red + "running late" after ETA + 15 min.
- **Copy address** button on the delivery screen (Flutter built-in clipboard).
- **Online time today** + **acceptance rate** on Home (`onlineSecondsToday`,
  `acceptanceRate`; saved in shared_preferences). Going offline with a popup open
  does NOT count against the acceptance rate. Online time is saved when the rider
  goes offline (if the app is killed while online, that session is not counted).
- **Confirm dialogs** for going offline and for signing out (`confirmDialog` in `utils/format.dart`).
- **Notification badge** on the bell (`unreadCount`), opening the screen marks all read,
  "Clear all" button.
- **Earnings filter** chips: Today / 7 days / All.

## STILL NOT DONE ON PURPOSE (needs packages/permissions or the backend)
Live GPS + in-app map, push alerts when the app is closed (FCM), secure KYC
upload/admin approval, real payouts, real SMS OTP, real customer ratings,
server-side cash limit.
All of these need your friend's backend; the screens already talk only to
`OrderRepository` / `AuthService`, so nothing in the UI has to change.

## ADDED IN SESSION 7 (still never compiled)
- **Dark theme** works now: Profile -> Theme (Auto / Light / Dark), saved on the phone.
  All fixed light colours were replaced with `utils/theme_colors.dart` helpers
  (`tint`, `tintBorder`). NEW RULE: never use `Colors.xxx.shade50/100/200` for
  backgrounds - use `tint(context, Colors.xxx)`.
- **Help & support** screen (`screens/help_screen.dart`): call support, WhatsApp,
  emergency 112, 5 FAQs (en/te/hi). Open it from Profile. Put the REAL support
  numbers in `constants/app_config.dart` (now placeholders).
- **Edit profile** (`screens/edit_profile_screen.dart`): name, vehicle type
  (bike/scooter/cycle) and number plate (validated like TS09AB1234; cycle needs none).
  `Rider` has `vehicleType`, `vehicleNumber`; `AuthService.updateProfile()`.
- **Cash limit**: `RiderController.codCashLimit` (Rs 2000). Above it the rider
  cannot go online and gets no new orders until cash is deposited in the Wallet;
  warnings on Home and Wallet. The backend must also enforce this.
- **Earnings chart**: last 7 days bar chart (`last7DaysEarnings`, `_WeekChart`).
- **No-internet strip** on every screen (`widgets/no_internet_banner.dart`,
  uses `dart:io` lookup every 10 s, no package).

## NOT DONE ON PURPOSE (need packages + Android/iOS setup, cannot be checked without a compiler)
- Alerts when the app is closed (`flutter_local_notifications` + a foreground service).
  Without a backend no order can arrive while closed anyway, so this belongs with push (FCM).
- Live GPS + in-app map (`geolocator`, `flutter_map`): needs location permissions.
- Real KYC document storage and admin approval require backend integration.

## ADDED IN THIS ROUND (still never compiled - see below)
- **Order queue**: a new order that arrives while the rider already has a
  popup showing or an active delivery no longer gets silently dropped - it
  waits (up to 5) and is shown automatically the moment the rider is free.
  New: `RiderController._queue`, `_presentIncoming()`, `_tryShowNext()`,
  `queueLength` getter. Called after reject/timeout, after a delivery
  completes, and after "report a problem". Cleared when going offline.
  Home screen shows "more orders waiting: N" under the online switch.
- **Route preview before accepting**: the incoming-order popup now has a
  "View full route on map" button (shop -> customer, via the new
  `openRoute()` in `utils/format.dart`), so the rider can check the whole
  trip before deciding, not just one leg at a time like the in-delivery
  Navigate buttons.
- **Sound + vibration** when a new order arrives (`HapticFeedback.vibrate()`
  + `SystemSound.play()` in `RiderController._presentIncoming` - both are
  built into Flutter, no new package was added).
- **History detail screen**: tapping a row in Earnings -> Delivery history
  now opens `HistoryDetailScreen`, showing the proof photo (if the file
  still exists on the phone), pickup/drop info, items, cash collected and
  rating. `DeliveryRecord` gained `shopAddress`, `customerName`, `items`,
  `payment` fields (old saved data without them still loads fine - they
  default to empty/online).
- **Payout ID required before withdrawing**: Wallet screen now has a
  "UPI ID or bank account number" field, saved once via
  `RiderController.setPayoutId()` / `payoutId`, and required (shows
  `err_payout_id`) before the first withdrawal - closer to how a real
  payout flow works.
- New translation keys added for all of the above, in English, Telugu
  and Hindi: `view_route`, `orders_waiting`, `payout_id_label`,
  `err_payout_id`, `no_photo`.

## BUILD AND VALIDATION (2026-11-06)
- Ran `flutter create .`, retaining the existing app sources and pubspec.
- Ran `flutter pub get` successfully.
- Added Android package visibility queries for `tel:` dialing and `https:` viewing
  in `android/app/src/main/AndroidManifest.xml`.
- Added `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in
  `ios/Runner/Info.plist`.
- `flutter analyze`: no issues found. Fixed a stale template widget test, a
  redundant null assertion, and const-related lints without changing app behavior.
- `flutter test`: passed (splash screen widget test).
- `flutter build web`: succeeded; the built app rendered and showed the sign-in
  screen. A mock new-order offer and its route-preview UI also rendered in a
  browser run.
- Full manual delivery script remains incomplete; see ISSUES below.

## AUTHENTICATION UPDATE (2026-11-06)
- `AuthService.requestOtp()` is asynchronous; verification returns `false` for an
  incorrect code and lets storage/network failures throw. Mock login stores a
  token in shared preferences for later backend integration.
- Login and OTP screens now show loading indicators and translated retry errors.
  OTP resend is available after a 30-second countdown.
- The OTP screen reads the mock code from `AuthService.demoOtp` and displays it
  only when `AppConfig.showDemoOtp` is enabled. Added English, Telugu and Hindi
  strings for the OTP hint, request/verification errors, and resend countdown.
- `flutter analyze`: no issues found. `flutter test`: passed.

## KYC DOCUMENT VERIFICATION (2026-11-06)
- Added `KycData`, the `KycRepository` boundary, persisted `MockKycService`,
  and Provider-backed `KycService`. The mock saves submitted data locally and
  pushes a simulated decision 3 seconds later in demo mode (15 seconds in real
  validation mode). Pending decisions resume after reopening the app; if the
  deadline passed while closed, the mock decides on load.
- `MockKycService.approveMode` supports `'approve'` (default), `'reject'`, and
  `'random'`. Demo mode approves unless the mode is `'reject'`; rejection uses
  a translated Aadhaar-photo clarity reason.
- Added the KYC form/status screen and routes after login and on app startup.
  Demo mode requires only Aadhaar, PAN and passport photos; Aadhaar/PAN numbers
  are optional but validated when entered. Real validation requires the numbers
  and photos. The live checklist shows unmet requirements and reasons, and field
  errors appear on blur. Approval displays a success state for 1.5 seconds and
  then clears the back stack while opening Home; the button can open Home sooner.
  Home blocks going online until approval; `KycService` updates the controller's
  approval flag so the online switch is enabled after approval. Approved KYC now
  survives sign out so the same rider returns directly to Home after sign in;
  unapproved KYC is still cleared on sign out. Demo mode also has a
  "Skip verification (demo)" action that persists local approval and follows the
  same success-card/navigation path.
- Backend handoff added to `API_CONTRACT.md`: `GET /rider/kyc`,
  multipart `POST /rider/kyc`, and the pushed `kycStatus` event. A real backend
  must store photos securely and use the admin panel for decisions.
- Validation: `flutter analyze` reports no issues, `flutter test` passes, and
  `flutter build web` succeeds. Ran a Flutter hot restart; the web-server run
  reported that no debug browser client was connected.
- Manual KYC check: create account -> OTP -> KYC screen -> confirm Submit is
  disabled and the checklist shows missing items -> upload only the three photos
  -> Submit becomes enabled -> submit -> pending for 3 seconds -> approval ->
  Home opens automatically -> go Online and verify mock orders arrive -> sign out
  -> sign in and confirm it goes directly to Home. Test "Skip verification
  (demo)" separately and
  confirm the same success card and Home navigation. To test real validation,
  change `kycDemoMode` to `false` in `lib/constants/app_config.dart` and confirm
  Aadhaar number, PAN number and all three photos are required. For rejection, set
  `MockKycService.approveMode = 'reject'` before a fresh submission, verify the
  reason and prefilled form, then correct/resubmit. Try app restart while pending
  and verify the saved status/deadline is honored.

## Test script (manual)
Create account (any name, 10-digit phone) -> OTP -> KYC screen -> confirm Submit
is disabled and the checklist explains missing items -> upload Aadhaar, PAN and
passport photos only -> Submit becomes enabled -> submit -> pending for 3 seconds
-> approved -> Home opens automatically -> go Online and verify mock orders arrive
-> sign out -> Sign in
with the approved account -> Home opens directly. Also test "Skip verification
(demo)" from the KYC form and confirm it opens Home after the success state.
Then change `kycDemoMode` to `false` in `lib/constants/app_config.dart` and
confirm Aadhaar number, PAN number and all three photos are required. To test
rejection, set `MockKycService.approveMode = 'reject'`
before a fresh submission and verify the translated reason, preserved values and
resubmit path. Reopen during a pending decision and verify its saved deadline and
status.

Continue the full delivery flow:
toggle Online ->
order popup after ~4s -> try "View full route on map" -> Accept -> tap
through 4 steps, using Call/Navigate on both the shop leg and the customer
leg -> enter shown demo code, take photo, tick COD box if shown -> Confirm
-> check Earnings/Wallet updated, tap a history row to see its detail
screen -> in Wallet, try Withdraw with no UPI ID saved (should be blocked),
then save one and withdraw again -> while Active, let a second mock order
arrive and confirm it shows "more orders waiting" on Home, then appears
automatically after you finish or report a problem on the current one.

## DISTANCE LIMITS: FOOD AND PARCEL ORDERS
- Added `OrderType` to orders and delivery history, with backward-compatible
  defaults for saved JSON that does not contain a type. The active order also
  saves its app-calculated pickup distance.
- Food orders are limited to a rider-to-shop pickup of at most
  `AppConfig.foodMaxPickupKm` (2.0 km) and a shop-to-customer drop of at most
  `AppConfig.foodMaxDropKm` (10.0 km). Parcels are limited to
  `AppConfig.parcelMaxKm` (25.0 km) total.
- The controller gets the rider's foreground location while online, filters
  invalid offers before popup/queue/acceptance-rate accounting, and checks
  pickup distance again before accepting. If location is unavailable, food
  offers are ignored and parcel offers are still checked by total distance.
- The mock generates about 70% food and 30% parcel orders around the rider's
  latest location, calculates route distance from coordinates, and applies the
  food/parcel earning formulas. Change the three constants in
  `lib/constants/app_config.dart` to adjust the limits.
- Added translated type chips and distance labels to order/active/history
  details, plus the configured distance-rules card on Home. The backend
  contract documents the server-side limits; server enforcement remains
  authoritative.
- Added Geolocator and foreground location permissions for Android/iOS.
- Validation: `flutter analyze` and `flutter test` pass. The running Flutter
  app hot-reloaded successfully with no reported runtime errors.
- Manual distance test: go online and watch the debug console; out-of-limit
  offers should be ignored with a reason. The popup should show only valid
  orders with the correct Food/Parcel chip and pickup/drop or parcel distance.
  Temporarily change `foodMaxPickupKm` to `0.1` and confirm almost no food
  orders appear. Restore it to `2.0` afterward.

## IN-APP DELIVERY MAP
- Added `DeliveryMap` using OpenStreetMap tiles via `flutter_map` and `latlong2`.
  It shows the rider's live location, the pickup point, the customer, the
  straight-line segment to the next stop, distance to that stop, recenter
  control, and OpenStreetMap attribution.
- The incoming-order popup includes a non-interactive pickup-to-customer map
  preview. The active delivery screen shows the live map above the address;
  the target changes from pickup to customer after the rider marks the order
  picked up. Tile load failures leave a gray map with markers visible.
- Added the Android INTERNET permission and localized map labels in English,
  Telugu, and Hindi. Google Maps navigation remains unchanged.
- Validation: `flutter pub get`, `flutter analyze`, `flutter test`, and
  `flutter build web` pass.
- Manual map check: accept an order -> map shows rider, shop and customer ->
  after "Picked up" the line goes to the customer -> turn off internet -> map
  shows markers without crashing -> switch to dark theme and confirm the map
  remains readable.

## PASSWORD REGISTRATION AND SIGN-IN
- Login now offers Create account and Sign in modes. Registration validates a
  password and confirmation before requesting the existing OTP screen; that
  screen was not changed. The mock stores accounts separately from the active
  rider profile, using a per-account random salt and SHA-256 hash only.
- Returning riders can sign in with phone and password. Wrong phone/password
  uses the same message; five consecutive failures block sign-in for 30
  seconds. Forgot password uses the demo OTP and replaces the stored hash.
  Signing out removes only the active rider profile/token, not demo accounts.
- Password reset and sign-in remain in `AuthService`; production endpoints and
  password-storage/rate-limit requirements are documented in
  `API_CONTRACT.md`.
- Validation: `flutter pub get`, `flutter analyze`, `flutter test`, and
  `flutter build web` pass.
- Manual password test: Create account with a weak password -> button stays
  disabled -> mismatching confirm shows error -> enter a valid password and
  verify OTP -> complete KYC -> sign out -> Sign in with the same phone and
  password works -> wrong password shows the shared credentials error -> five
  wrong tries lock sign-in for 30 seconds -> Forgot password changes the
  password -> old password no longer works and new password works -> check in
  dark theme.

## Extra tests for session 8
Accept an order -> trip timer runs; note/tip show when present; copy address ->
snackbar; at the shop tap "Picked up" -> must tick all items; Home shows online
time + acceptance %; toggle offline -> confirm box; sign out -> confirm box;
bell shows a number, opens -> number disappears, "Clear all" empties; Earnings
chips Today / 7 days / All change the list.

## REMAINING FRONTEND FEATURES (do in this order, AFTER the app compiles)
1. Compile + fix `flutter analyze` errors; Android `<queries>` + iOS Info.plist; test script.
2. Polish: app icon + app name (flutter_launcher_icons), pull-to-refresh on Earnings/Wallet,
   `intl` dates, order-card entrance animation, widget tests in `test/`.
3. Live GPS + in-app map: `geolocator` (+ `flutter_map`, no paid key) with location
   permissions; show rider position, route to shop/customer, send location through a new
   `OrderRepository.updateLocation()`.
4. FCM background delivery for new orders: backend high-priority data push and app
   background handler integration; the app-side local notification channel is implemented.
5. Real KYC backend: secure photo upload, admin approval integration, and server-side
   enforcement of verification status.
6. Terms + privacy screen, "About / app version", sign-in consent checkbox.
7. Customer rating + feedback text after delivery; ratings breakdown on Profile.
8. Weekly statement / payout receipt screen (copy or share as text with `share_plus`).
9. Accessibility: large-text check, TalkBack labels, bigger tap targets; tablet layout check.
10. Backend swap: fill `ApiOrderRepository` + `AuthService` per API_CONTRACT.md, move
    OTP/photo checks and the cash limit to the server.

## PENDING / KNOWN GAPS (for next session, in priority order)
1. Complete the end-to-end manual delivery script on an Android/iOS device
   (see ISSUES below); the app now analyzes, tests, and builds for web.
2. (done in session 7) Dark theme - old note: NOT added on purpose - several screens use fixed light
   colors (e.g. `Colors.orange.shade50`, `Colors.red.shade50`) that would
   be unreadable in dark mode. Fix those colors (use `Theme.of(context)`
   or dark-aware variants) before adding dark theme support.
3. Background app-closed order delivery still needs a high-priority FCM data push and
   app-side FCM handler; see `API_CONTRACT.md`. Local notifications are used while the
   app is minimized.
4. Polish: empty/loading states are done for history/payouts/notifications;
   still missing: app icon/name, `intl` package for nicer date formatting,
   pull-to-refresh, order-card entrance animation.
5. Backend swap (later, by a backend dev): write `ApiOrderRepository implements
   OrderRepository` and pass it in `main.dart`: `RiderController(repository: ...)`.
   Also replace the mock OTP in `auth_service.dart`. Nothing in this round
   touched that boundary - the screens still only know about `OrderRepository`.

## DELIVERY OTP VERIFICATION AND SUCCESS FLOW
- Delivery proof enables Confirm only after a four-digit OTP and a picked photo.
  The OTP check shows a one-second locked spinner; an incorrect code shakes and
  clears only the OTP field, retains the photo, and shows a support hint after
  three attempts.
- A correct OTP opens the animated check flow: OTP verified, photo verification,
  then Delivery completed. `RiderController.completeDelivery` remains the single
  operation that clears the active order and updates history/earnings. The
  success screen prevents concurrent calls and offers Retry after repository
  failures without discarding the proof form's OTP or photo.
- The completed summary shows order, type, pickup/drop names, distance,
  delivered time, all-inclusive earnings (with tip indicated), COD cash due,
  and today's delivery/earning totals. It returns to Home once, either by user
  action/back or automatically after six seconds; View earnings leaves Home
  underneath the earnings page.
- Delivery-success test on Chrome and Android, including dark theme: accept an
  order -> reach customer -> proof screen -> confirm stays disabled until OTP
  and photo are present -> enter a wrong OTP -> verify shake/red message and
  retained photo -> enter the correct OTP -> verify spinner, animated green
  check and OTP verified -> photo verification -> Delivery completed -> verify
  summary and earnings -> Back to Home -> confirm Home stats and history.
  Repeat with a COD order and verify the cash line; repeat with prepaid and
  verify the cash line is absent. Also force a completion network failure and
  verify Retry keeps the active delivery and completes it once on success.
- Validation for this flow: `flutter analyze`, `flutter test`, and
  `flutter build web` pass; Chrome hot reload succeeds with no runtime errors.
  An Android debug build was attempted but stalled while Gradle provisioned
  NDK 28.2.13676358 and was stopped. No Android device/emulator is connected,
  so mobile runtime and the manual delivery scenarios remain unverified.

## ISSUES
- The original Submit failure was blank Aadhaar/PAN values being rejected; the current demo logic now treats blank numbers as valid. Submit is enabled by `_formValid && !kyc.submitting && !_pickingPhoto && kyc.errorKey != 'kyc_load_error'`; `_formValid` checks valid Aadhaar/PAN values and all three photos. After three photos no required check is false unless a typed number is malformed; there are no bank/passbook fields.
- Both number controllers call `setState` on changes, and each successful photo pick calls `setState`; the live-button update is wired.
- Mock submit persists `pending` and schedules a decision after 3 seconds; demo approval sets `approved` unless `approveMode == 'reject'`. KycService updates RiderController, then KycScreen shows success for 1.5 seconds and clears the stack to Home; Start working can open it sooner.
- Splash, sign-in, and OTP load KYC and route approved riders to Home; pending, not-submitted, and rejected riders go to KYC. Before this fix, both sign-out paths also reset saved KYC, so the approved state did not survive the requested sign-out/sign-in test.
- `KycService` is provided in `main.dart` after `RiderController` and above the MaterialApp screens, with the controller injected into it.
- Manual testing was only partial. No Android emulator or physical Android/iOS
  device was available; the complete sequence (accept, delivery steps, photo
  proof, OTP, cash collection, payout/history and queue) was not verified.
- The KYC form, image selection, and 3-second simulated approve/reject flow
  still need manual verification on a device with the image picker.
- The browser run rendered the app and mock order popup, but the Flutter canvas
  interaction was not reliable enough to complete the delivery flow. Native
  camera/photo-picker and dialer/maps behavior also require device verification.
- Web compatibility bug: delivery proof used `Image.file`, and history and KYC
  preview paths depended on `dart:io` `File`, which cannot load the web picker's
  blob URLs (and `Image.file` is unsupported on web). The internet strip also
  imported `dart:io` and queried `InternetAddress.lookup` from a widget, causing
  a false offline state/build failure in Chrome. Proof and history/KYC now use
  `PickedImage`, with web network-image and native file-image implementations
  selected conditionally. Connectivity now uses a shared service: web starts
  online and updates from repository failures/successes, while native checks
  two DNS hosts and requires two failed checks before showing the banner.
- Pre-fix `lib/` inventory (line numbers at the scan):
  - `screens/delivery_proof_screen.dart:1,130` — `dart:io`, `Image.file`, `File`.
  - `screens/history_detail_screen.dart:1,21,30` — `dart:io`, `File`,
    `existsSync`, `Image.file`.
  - `screens/kyc_screen.dart:2,692-693` — `dart:io`, `Image.file`, `File`.
  - `widgets/no_internet_banner.dart:2,31` — `dart:io`,
    `InternetAddress.lookup`.
  - No `FileImage`, `Platform.`, `path_provider`, or `.readAsBytes` matches.
- Current `dart:io` use is isolated to conditional native implementations:
  `widgets/picked_image_io.dart:1,13` (`FileImage`/`File`) and
  `services/connectivity_probe_io.dart:2,9` (`InternetAddress.lookup`).
  There are no direct `dart:io` imports in UI screens or the banner.
- Web delivery regression test: run `flutter run -d chrome`; confirm there is
  no red banner while online; accept an order, reach the customer, select a
  proof photo, enter the delivery OTP, and confirm. Verify earnings update and
  the history detail photo displays. Disable internet and confirm the banner
  appears; restore internet and confirm it disappears. Repeat on Android.
- Additional web safeguards: web delivery proof opens the gallery chooser and
  displays a camera-unavailable hint; failed/expired browser-session photos use
  a translated placeholder. External dialer, Maps and WhatsApp launch failures
  show a translated snackbar. Geolocator permission denial remains handled
  without throwing out of location startup.
- Validation: `flutter analyze`, `flutter test`, and `flutter build web` pass.
  `flutter run -d chrome` starts and hot reload succeeds. The full photo/OTP and
  network-toggle regression script above still needs manual completion; no
  Android device/emulator is connected in this environment.

## New-order alert system
- Incoming offers use `AppConfig.offerSeconds = 40`; the audible alert is capped at
  `AppConfig.alertMaxSeconds = 40`. An optional ISO-8601 `expiresAt` from the server
  shortens both the popup countdown and alert window. The mock orders provide the
  same deadline.
- `AlertService`, owned by `RiderController`, loops `assets/sounds/new_order.mp3` at
  full volume, uses the system alert sound as a fallback, and vibrates/keeps the
  screen awake on supported mobile platforms. The web skips vibration and wakelock;
  audio is unlocked when the rider first interacts with the Online switch.
- The Android `new_orders` notification channel uses maximum importance, alarm audio
  attributes, vibration, a public full-screen alert and a 40-second timeout. If the
  app is minimized, it posts a local notification; notification taps return to the
  pending order popup. A backend FCM data push and app-side handler are still needed
  to receive offers after the app has been closed.
- Add the rider-provided MP3 at `assets/sounds/new_order.mp3`. Also place a copy at
  `android/app/src/main/res/raw/new_order.mp3` for Android notification sound and add
  `new_order.mp3` to the iOS Runner target's bundled resources in Xcode. These binary
  audio files are intentionally not generated or downloaded by this change.
- Home includes a test alert button, alarm-volume and Do-not-disturb guidance, and a
  browser hint to keep the tab open and allow sound. The first mobile online attempt
  shows a translated explanation before requesting notification permission.
- Added alert labels and instructions in English, Telugu, and Hindi. No extra volume
  controller package was added.
- Alert verification script:
  1. On Chrome, tap Online (and allow browser sound), confirm the tab hint, then wait
     for a valid mock order. Confirm sound and the pulsing border start with the popup.
  2. Mute the alert and verify the popup/countdown stays open. Accept another order,
     reject it, then let one expire; sound stops on each action and at 40 seconds.
  3. Trigger back-to-back offers and confirm only the visible order rings; the queued
     order starts a fresh alert when it becomes visible. Use the test-alert button.
  4. Minimize an Android/iOS app during an offer; verify the notification sound and
     vibration, tap it to return to the popup, then accept/reject and verify it stops.
  5. Temporarily remove the asset MP3 and confirm the system alert fallback. Repeat on
     a real Android phone to check alarm-stream loudness and vibration, and in dark
     theme. Test Android notification permission on Android 13+.
- Validation: `flutter pub get`, `flutter analyze`, `flutter test`, and
  `flutter build web` pass. `flutter run -d chrome` hot-restarted and hot-reloaded
  successfully, and the runtime error check reported no errors.
- Android build attempt: `flutter build apk --debug` stopped during Gradle
  configuration because the local Android NDK at
  `C:\Users\DELL\AppData\Local\Android\sdk\ndk\28.2.13676358` is missing
  `source.properties`. No environment SDK files were deleted or replaced.
- Manual alert scenarios are not verified on hardware. The requested MP3 has not
  been supplied, and no Android device/emulator is connected; add the asset files
  above before testing loop playback and native notification sound.

## All project files
```
myshopzy_rider/
  pubspec.yaml
  STATUS.md
  API_CONTRACT.md       (what the backend must provide)
  lib/
    main.dart
    constants/
      app_strings.dart      (English-only strings for login/splash - legacy)
      translations.dart     (T.t() - English/Telugu/Hindi for everything else)
      app_config.dart       (support phone/WhatsApp placeholders)
    models/
      rider.dart
      order.dart             (Order, DeliveryStep, PaymentType, DeliveryRecord,
                               PayoutRecord, AppNotification)
    services/
      auth_service.dart      (mock OTP login)
      order_repository.dart  (abstract - the backend boundary)
      mock_order_service.dart (fake orders via Stream/Timer)
      api_order_repository.dart (SKELETON for the backend dev, not wired in)
      rider_controller.dart  (all live app state - the big one)
    widgets/
      primary_button.dart
      incoming_order_card.dart
      incoming_order_overlay.dart (popup above every screen)
      no_internet_banner.dart
    utils/
      format.dart            (money, dates, callNumber, openMaps, openRoute)
      nav.dart               (navigatorKey for the global popup)
      theme_colors.dart      (tint/tintBorder - dark-mode-safe colours)
    screens/
      splash_screen.dart
      login_screen.dart
      otp_screen.dart
      home_screen.dart
      active_delivery_screen.dart
      delivery_proof_screen.dart
      earnings_screen.dart
      history_detail_screen.dart
      wallet_screen.dart
      profile_screen.dart
      notifications_screen.dart
      help_screen.dart
      edit_profile_screen.dart
```

## Scope rules (do not break these)
- Frontend only. No backend/server code, no real database.
- Mock data only, behind the abstract `OrderRepository`.
- shared_preferences for small saved data, url_launcher for calls/maps,
  image_picker for proof photo. No packages that need paid API keys.
- Folders: lib/models, lib/services, lib/screens, lib/widgets, lib/utils, lib/constants.
  State management: Provider.
- Screens added in Features 2-9 use `T.t('key')` from `translations.dart`.
- One change at a time; update this STATUS.md after every change.
