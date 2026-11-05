# Padding audit: `lib/screens/`

Phase 1 baseline audit. Phase 2 implementation updates are recorded at the end.

## Summary

The original brief assumed hard-coded values (8, 12, 16, 20, 32) scattered across screens and some lists with no padding. The code is in better shape than that, but there is one real inconsistency:

- **Tokens are already used everywhere.** Screens use `AppSpace.*` tokens from [tokens.dart](/D:/urban/urban_tanker_app/lib/core/design_system/tokens.dart), not raw numbers. The only raw numeric padding values are listed in section 4.
- **`AppPageInsets` is not where the brief says.** It lives in [app_state_view.dart](/D:/urban/urban_tanker_app/lib/core/design_system/widgets/app_state_view.dart), not `lib/app/page_components.dart`, which does not exist. At audit time, `AppPageInsets.standard` was defined but **no screen used it**. Only `AppPageInsets.status` was used, by `AppStateView`.
- **The real inconsistency is vertical.** Most full-page scrollables use `fromLTRB(gutter, lg, gutter, xxxl)` (20, 16, 20, 32). `AppPageInsets.standard` is (20, 16, 20, 24). Switching screens to `standard` would shrink the bottom gap by 8px on about 17 screens. That is a visible change, so it needs your decision (section 6).
- **Horizontal gutter is already consistent.** Page bodies use `AppSpace.gutter` (20) on both sides. The exceptions are in section 3.
- **Almost every scroll view already has padding,** either on itself or on a parent wrapper. The truly unpadded case is one horizontal list (section 5).

Counts from the grep: about 153 `EdgeInsets` references across 43 files in `lib/screens/`. This includes `EdgeInsets.zero` resets and `EdgeInsets.only(bottom: md)` spacers between list items. Those spacers stay as they are.

## 1. Full-page scrollables (page body)

Proposed fix: move to `AppPageInsets.standard` **only after you choose a value** (section 6). "Current" is the value in the file.

| File | Line | Current value | Proposed |
|---|---|---|---|
| [invoice_detail_screen.dart](/D:/urban/urban_tanker_app/lib/screens/invoice_detail_screen.dart) | 76 | (gutter, lg, gutter, xxxl) | page body token |
| [notification_inbox.dart](/D:/urban/urban_tanker_app/lib/screens/notification_inbox.dart) | 78 | (gutter, lg, gutter, xxxl) | page body token |
| [support_request_detail_screen.dart](/D:/urban/urban_tanker_app/lib/screens/support_request_detail_screen.dart) | 44 | (gutter, lg, gutter, xxxl) | page body token |
| [customer_account_screen.dart](/D:/urban/urban_tanker_app/lib/screens/customer_account_screen.dart) | 26 | (gutter, lg, gutter, xxxl) | page body token |
| [home/customer/customer_overview.dart](/D:/urban/urban_tanker_app/lib/screens/home/customer/customer_overview.dart) | 58 | (gutter, lg, gutter, xxxl) | page body token |
| [home/shell/menu_screen.dart](/D:/urban/urban_tanker_app/lib/screens/home/shell/menu_screen.dart) | 33 | (gutter, lg, gutter, xxxl) | page body token |
| [dispatcher/dispatch_screen.dart](/D:/urban/urban_tanker_app/lib/screens/dispatcher/dispatch_screen.dart) | 226 | (gutter, lg, gutter, xxxl) | page body token |
| [dispatcher/alerts_screen.dart](/D:/urban/urban_tanker_app/lib/screens/dispatcher/alerts_screen.dart) | 82 | (gutter, lg, gutter, xxxl) | page body token |
| [dispatcher/live_screen.dart](/D:/urban/urban_tanker_app/lib/screens/dispatcher/live_screen.dart) | 281 | (gutter, **md**, gutter, xxxl) | page body token (top 12 to 16) |
| [vendor/vendor_earnings_screen.dart](/D:/urban/urban_tanker_app/lib/screens/vendor/vendor_earnings_screen.dart) | 123 | (gutter, lg, gutter, xxxl) | page body token |
| [vendor/operations/vendor_operations_screen.dart](/D:/urban/urban_tanker_app/lib/screens/vendor/operations/vendor_operations_screen.dart) | 153 | (gutter, lg, gutter, xxxl) | page body token |
| [vendor/fleet/vendor_fleet_screen.dart](/D:/urban/urban_tanker_app/lib/screens/vendor/fleet/vendor_fleet_screen.dart) | 97 | (gutter, lg, gutter, xxxl) | page body token |
| [public_tracking_screen.dart](/D:/urban/urban_tanker_app/lib/screens/public_tracking_screen.dart) | 419 | (gutter, **md**, gutter, xxxl) | page body token (top 12 to 16) |
| [booking_details_screen.dart](/D:/urban/urban_tanker_app/lib/screens/booking_details_screen.dart) | 193 | (gutter, lg, gutter, xxxl), inside `SliverPadding` | page body token |
| [bookings_screen.dart](/D:/urban/urban_tanker_app/lib/screens/bookings_screen.dart) | 100 | (gutter, **sm**, gutter, xxxl) | page body token (top 8 to 16) |
| [bookings_screen.dart](/D:/urban/urban_tanker_app/lib/screens/bookings_screen.dart) | 73 | (gutter, md, gutter, sm), filter header | leave (it is a header, not a scroll body) |

### Admin screens use a different pattern

These use `EdgeInsets.all(gutter)`, which is 20 on all four sides. The top is 20 instead of 16, and the bottom is 20 instead of 32.

| File | Line | Current value | Proposed |
|---|---|---|---|
| [admin/admin_pulse_screen.dart](/D:/urban/urban_tanker_app/lib/screens/admin/admin_pulse_screen.dart) | 39 | all(gutter) | page body token |
| [admin/admin_reports_screen.dart](/D:/urban/urban_tanker_app/lib/screens/admin/admin_reports_screen.dart) | 34 | all(gutter) | page body token |
| [admin/operations/setup_section.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/setup_section.dart) | 39 | all(gutter) | page body token |
| [admin/operations/people_section.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/people_section.dart) | 62 | all(gutter) | page body token |
| [admin/operations/finance_section.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/finance_section.dart) | 56 | all(gutter) | page body token |
| [admin/operations/orders_section.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/orders_section.dart) | 63 | all(gutter) | page body token |
| [security_settings_screen.dart](/D:/urban/urban_tanker_app/lib/screens/security_settings_screen.dart) | 68 | all(gutter) | page body token |
| [unlock_setup_screen.dart](/D:/urban/urban_tanker_app/lib/screens/unlock_setup_screen.dart) | 130 | all(gutter), centered `ConstrainedBox` | page body token |

### Deliberately different (leave as is)

| File | Line | Value | Why |
|---|---|---|---|
| [auth_screen.dart](/D:/urban/urban_tanker_app/lib/screens/auth_screen.dart) | 249 | (gutter, xxl, gutter, xxl) | Auth layout with more air. Matching it would change the look of sign-in. |
| [app_lock_screen.dart](/D:/urban/urban_tanker_app/lib/screens/app_lock_screen.dart) | 129 | all(xxl) | Lock screen, centered 360px column. Matches `AppPageInsets.status` intent. |

## 2. Sheets and dialogs (`SafeArea` plus padded `SingleChildScrollView`)

These already use the xl gutter (20) with a zero top and an xl bottom. They are consistent with each other, so **no change proposed**:

- [vendor/operations/order_actions_sheet.dart](/D:/urban/urban_tanker_app/lib/screens/vendor/operations/order_actions_sheet.dart) line 93
- [admin/operations/admin_common.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/admin_common.dart) lines 62, 214
- [admin/operations/orders_section.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/orders_section.dart) line 461
- [admin/operations/people_section.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/people_section.dart) line 518
- [admin/operations/setup_section.dart](/D:/urban/urban_tanker_app/lib/screens/admin/operations/setup_section.dart) line 247
- [vendor/fleet/fleet_forms.dart](/D:/urban/urban_tanker_app/lib/screens/vendor/fleet/fleet_forms.dart) line 83
- [vendor/fleet/documents_card.dart](/D:/urban/urban_tanker_app/lib/screens/vendor/fleet/documents_card.dart) line 227
- [dispatcher/dispatch_actions.dart](/D:/urban/urban_tanker_app/lib/screens/dispatcher/dispatch_actions.dart) lines 162, 324
- [home/booking/booking_form_sheet.dart](/D:/urban/urban_tanker_app/lib/screens/home/booking/booking_form_sheet.dart) line 1391
- [forgot_password_sheet.dart](/D:/urban/urban_tanker_app/lib/screens/auth/forgot_password_sheet.dart) line 50 (gutter, lg, gutter, xl). Uses `lg` top, so it's a 4px outlier from the sheets above. Low priority.

## 3. Horizontal gutter exceptions

Top-level screens already line up at 20. These do not:

| File | Line | Value | Proposed |
|---|---|---|---|
| [home/booking/booking_form_sheet.dart](/D:/urban/urban_tanker_app/lib/screens/home/booking/booking_form_sheet.dart) | 1240 | (lg, 0, lg, 0) around `LiveQuoteSummary` | xl (20), so it lines up with the step content |
| [home/booking/booking_form_sheet.dart](/D:/urban/urban_tanker_app/lib/screens/home/booking/booking_form_sheet.dart) | 1260 | (lg, md, lg, lg) footer | xl (20) |
| [home/booking/booking_form_sheet.dart](/D:/urban/urban_tanker_app/lib/screens/home/booking/booking_form_sheet.dart) | 1189 | (xl, 0, xl, 0) | already xl. Left as is. |

## 4. Raw numeric values (not tokens)

These are the only padding literals not built from `AppSpace`. Each one is positional, so I propose to **leave them** unless you say otherwise:

| File | Line | Value | Why it's probably intentional |
|---|---|---|---|
| [booking_details_screen.dart](/D:/urban/urban_tanker_app/lib/screens/booking_details_screen.dart) | 549 | (xl, **88**, xl, **64**) | Clears the app bar or hero overlay. Converting to tokens would shift the layout. |
| [booking_details_screen.dart](/D:/urban/urban_tanker_app/lib/screens/booking_details_screen.dart) | 172 | titlePadding start/end 56, bottom 14 | Clears the back and action icons in the collapsing app bar. |
| [public_tracking_screen.dart](/D:/urban/urban_tanker_app/lib/screens/public_tracking_screen.dart) | 144 | top **96** | Clears the floating header over the map. |

## 5. Scroll views with no padding of their own

Most of the scroll views in the grep have padding either on themselves or on a parent. Only one has no padding on any ancestor:

| File | Line | Issue | Proposed |
|---|---|---|---|
| [home/customer/customer_overview.dart](/D:/urban/urban_tanker_app/lib/screens/home/customer/customer_overview.dart) | 406 | Horizontal `ListView.separated` with no padding. Cards are clipped at the parent gutter, so they look cut off at the edge of the section. | Add `padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter)` so the first and last cards align with the gutter and scroll out to the edge. |

These are padded by a parent wrapper and are not a problem. I checked them directly:
- [dispatcher/dispatch_actions.dart](/D:/urban/urban_tanker_app/lib/screens/dispatcher/dispatch_actions.dart) line 170: `shrinkWrap` `ListView` inside `Padding(xl)`
- [customer_account_screen.dart](/D:/urban/urban_tanker_app/lib/screens/customer_account_screen.dart) line 892: `shrinkWrap` `ListView.builder` inside a dialog
- [home/booking/booking_form_sheet.dart](/D:/urban/urban_tanker_app/lib/screens/home/booking/booking_form_sheet.dart) line 970: `shrinkWrap` picker inside a sheet
- `SingleChildScrollView` in sheets and dialogs (section 2) and [booking_details_screen.dart](/D:/urban/urban_tanker_app/lib/screens/booking_details_screen.dart) line 158 (`CustomScrollView`, which has a `SliverPadding` at line 192)

## 6. Safe area and bottom inset

- `SafeArea` is already used on auth, app lock, live, selfie capture, public tracking, sheets, and dialogs.
- Before Phase 2, the **full-page scrollables** in section 1 used a fixed 32px bottom padding, not the device inset. Phase 2 replaced those values with `AppPageInsets.standard` plus the device bottom inset. The home shell is [home_shell.dart](/D:/urban/urban_tanker_app/lib/screens/home/home_shell.dart); its bottom navigation already wraps itself in `SafeArea`.

## 7. Phase 2 implementation

The user approved the recommendations by replying “continue.” The following changes were made:

- Kept `AppPageInsets.standard` at its existing value `(20, 16, 20, 24)` as required. Full-page scrollables now use it, so pages that previously used a 32px bottom gap have an 8px smaller base gap.
- Added the requested `section`, `card`, `compact`, and `listBottom` constants to `AppPageInsets`.
- Added `AppPageInsets.withSafeAreaBottom` and used it for full-page scrollables so their bottom padding includes the device inset. `HomeShell`'s custom bottom navigation already wraps itself in `SafeArea`.
- Normalized the admin/settings screens' outer gutters to the page-body value.
- Normalized the 8px/12px top outliers on the dispatcher, tracking, and bookings pages to the standard top inset.
- Added horizontal gutter padding to the customer overview's recent-bookings list.
- Changed the booking quote and footer wrappers from 16px to the 20px gutter.
- Replaced repeated 16px card padding with `AppPageInsets.card`.
- Added widget assertions for the admin pulse and report page scroll padding in `test/admin_screens_test.dart`.

The small, component-specific `EdgeInsets.only(...)` and `EdgeInsets.symmetric(...)` values remain where none of the new page/card/compact tokens preserves their directional spacing. Intentional auth/lock-screen spacing, app-bar/hero clearances, sheet/dialog padding, list-item spacing, and zero-padding resets also remain unchanged. The page-bottom reduction from 32px to 24px is the deliberate visual adjustment; device safe-area padding is added on top.

## 8. Phase 1 recommendations and dispositions

1. **Page body value:** used the existing `AppPageInsets.standard` `(20, 16, 20, 24)`; kept unchanged per the original requirement.
2. **Admin `all(gutter)` screens:** normalized to the page body value.
3. **Dispatcher, public tracking, bookings top values:** normalized to 16.
4. **Customer overview horizontal list:** added the 20px horizontal gutter.
5. **Raw numeric values in section 4:** left unchanged because they clear app-bar/hero overlays.

## `AppPageInsets` scale

Existing `standard` and `status` remain unchanged. New constants in `app_state_view.dart`, built from `AppSpace` so they stay in sync:

- `section`: `symmetric(horizontal: gutter, vertical: md)`
- `card`: `all(lg)`
- `compact`: `all(sm)`
- `listBottom`: `only(bottom: xxxl)`

`withSafeAreaBottom(context, insets)` adds the current device bottom inset to a scrollable's base padding.
