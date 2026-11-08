# MyShopzy Rider app - what the backend must provide

For the backend developer. The Flutter app is finished on its own with fake data.
It only talks to the server through repository/service boundaries, so screens
do not make network calls directly:

- `lib/services/order_repository.dart` (orders, wallet) - start from `lib/services/api_order_repository.dart`
- `lib/services/auth_service.dart` (login / OTP / profile) - replace the fake OTP inside `requestOtp()`, `verifyOtp()`, `updateProfile()`
- `lib/services/kyc_repository.dart` (rider document verification)

Rule for every call: if it fails, THROW. The app shows an error and the rider can retry.
All money is in rupees (number). All times are ISO-8601 strings (UTC).

## 1. Login
| App call | Server | Notes |
|---|---|---|
| `AuthService.requestOtp(name, phone)` | `POST /auth/send-otp` `{name, phone}` | Send a real SMS. Set `AppConfig.showDemoOtp` to false for real SMS so the OTP screen no longer shows the local mock code. |
| `AuthService.verifyOtp(code)` | `POST /auth/register` `{name, phone, password, otp}` -> `{token, rider}` | Finish registration and return the login token. |
| `AuthService.signIn(phone, password)` | `POST /auth/login` `{phone, password}` -> `{token, rider}` | Return 401 for wrong credentials and 429 while locked. The app deliberately uses the same message for an unknown phone and a wrong password. |
| `AuthService.requestPasswordReset(phone)` | `POST /auth/forgot-password` `{phone}` | Send a password-reset OTP. |
| `AuthService.resetPassword(phone, otp, newPassword)` | `POST /auth/reset-password` `{phone, otp, newPassword}` | Verify the OTP and replace the password. |
| `AuthService.updateProfile(...)` | `PATCH /rider/profile` `{name, vehicleType, vehicleNumber}` | vehicleType: `bike` / `scooter` / `cycle`. |

Rider JSON: `{name, phone, vehicleType, vehicleNumber}`

Security requirements: hash passwords with bcrypt or Argon2 and never store
plain-text passwords. Send credentials and OTPs over HTTPS only, rate-limit
authentication and password-reset attempts, and do not reveal whether a phone
number exists during sign-in or in password-reset API responses. The local demo
stores salted SHA-256 hashes only; this is demonstration storage, not a
production password hashing scheme.

## 2. Live orders (real time: WebSocket, FCM or Firebase)
| Event to the app | App stream | Payload |
|---|---|---|
| New order offered to this rider | `incomingOrders` | Order JSON (below) |
| Customer or shop cancelled | `cancelledOrders` | the order id (string) |

The app shows an offer popup for up to 40 seconds (`AppConfig.offerSeconds`). Include an
optional ISO-8601 UTC `expiresAt` in the order to shorten that deadline. The app always
caps the popup and audible alert at `AppConfig.alertMaxSeconds` (40 seconds). If the rider
does not answer before the deadline, the app calls reject itself.
Offer an order to ONE rider at a time, or make `accept` fail for everyone but the first.

### Order JSON (`Order.fromJson` in `lib/models/order.dart`)
```
{ "id": "MS1001",
  "shopName": "", "shopPhone": "", "shopAddress": "", "shopLat": 0.0, "shopLng": 0.0,
  "customerName": "", "customerPhone": "", "customerAddress": "", "customerLat": 0.0, "customerLng": 0.0,
  "items": "2 x Biryani, 1 x Raita",     // comma separated - the pickup checklist splits on commas
  "orderTotal": 450.0,                    // what the customer pays (cash to collect when payment = cod)
  "earning": 70.0,                        // what the rider earns, INCLUDING the tip
  "tip": 10.0,                            // optional, already inside "earning"
  "note": "Ring the bell twice",          // optional customer instruction
  "distanceKm": 3.4,
  "type": "food" | "parcel",
  "payment": "cod" | "online",
  "deliveryOtp": "4821",                   // customer tells this to the rider; app compares it locally
  "expiresAt": "2026-03-01T10:00:40Z" }   // optional offer deadline; the app never extends it
```
Security note: sending `deliveryOtp` to the rider's phone lets a dishonest rider read it. Better: the
server checks the code (change `RiderController.otpMatches` to a server call). Same for the photo proof.

## 3. Order actions
| App call | Server | Failure means |
|---|---|---|
| `acceptOrder(id)` | `POST /orders/{id}/accept` | Throw if taken by someone else or cancelled. App shows "Could not accept". |
| `rejectOrder(id)` | `POST /orders/{id}/reject` | Also used when the rider reports a problem (shop closed, no answer, wrong address, vehicle). A reason is NOT sent yet - add a parameter if you need it. |
| `completeOrder(id)` | `POST /orders/{id}/complete` | Throw on error; the app stays on the proof screen so the rider can retry. Upload the proof photo (app has the local path in `DeliveryRecord.photoPath`) and cash collected here. |

Steps (accepted / reached shop / picked up / reached customer) are NOT sent to the server yet.
If the customer needs live tracking, add `POST /orders/{id}/step` and call it from `RiderController.advanceStep`.

## 4. Wallet
| App call | Server |
|---|---|
| `requestWithdraw(amount)` | `POST /wallet/withdraw` `{amount, payoutId}` -> true when accepted (payoutId = UPI ID / bank account the rider typed) |
| `depositCash(amount)` | `POST /wallet/cash-deposit` `{amount}` -> true when recorded |

Today earnings, cash in hand and balance are CALCULATED ON THE PHONE from the delivery history.
For production the server must be the source of truth: add `GET /rider/summary` and
`GET /rider/history` and read them in `RiderController.load()`.

## 5. Rules the server MUST enforce itself (the app only shows them)
- Cash limit: the app blocks going online above Rs 2000 cash in hand (`RiderController.codCashLimit`). Enforce on the server too.
- Daily bonus (8 deliveries = Rs 100) is display only - the server must calculate and pay it.
- Minimum withdrawal Rs 100 (`RiderController.minWithdraw`).
- Rating shown is a fake random 3-5 per delivery - replace with the real customer rating.
- Emergency button calls 112. Support numbers are in `lib/constants/app_config.dart`.

## 6. Rider document verification (KYC)
| App call / event | Server | Notes |
|---|---|---|
| `KycRepository.fetchKyc()` | `GET /rider/kyc` | Returns the rider's document numbers, photo references, submission time, status, and optional rejection reason. |
| `KycRepository.submitKyc(data)` | `POST /rider/kyc` (multipart/form-data) | Fields: `aadhaarNumber`, `panNumber`, `aadhaarPhoto`, `panPhoto`, `passportPhoto`. Throw on failure so the app can offer retry. |
| `kycStatus` event | Real-time push to the app | `{ "status": "pending" | "approved" | "rejected", "rejectReason": "..." }`. Push approval/rejection decisions to update the app without a restart. |

Store document photos securely and restrict access to authorized reviewers.
The admin panel performs the approval or rejection and supplies a rejection
reason when applicable. The client-side mock approval is only for demonstration.

## 7. Distance rules

Order JSON includes `"type": "food" | "parcel"`. The app filters offers using
the configured distance limits, but the server is the source of truth and MUST
enforce them too:

- Offer food only to riders within 2 km of the shop, and only when the
  shop-to-customer distance is at most 10 km.
- Offer parcels only when the total pickup-to-drop distance is at most 25 km.

## 8. Background new-order push (needs backend)
The app plays a local looping alert while running and displays a high-priority local
notification while minimized. To wake the app and trigger the same order alert when it
is closed, the backend must send a high-priority FCM **data** push for each new offer.
Include the full order payload (including its `expiresAt`, when provided) and a stable
order ID. The mobile app's FCM background handler must pass that order through the same
repository/controller filtering and alert flow; do not use a notification-only push,
which cannot reliably deliver the order payload for the app to show the offer.

Live rider GPS to the customer, secure KYC photo storage and admin approval integration,
and real payouts are also not built yet.
