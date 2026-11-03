Lottie animations used by LottieOrIcon (lib/core/design_system/widgets/lottie_or_icon.dart).
Each one falls back to an icon or spinner when the file is missing, so the app runs without them.

Files:
  success.json         check mark in a teal disc
  error.json           cross in a coral disc
  empty.json           tray that bobs gently (empty states)
  loading_water.json   water drop with a ripple (loading)
  delivery_truck.json  truck driving back and forth (in-transit and loading)
  location_pin.json    pin dropping onto its shadow (location)
  mail.json            envelope with a flap (check your inbox after email sign-up)

These are original animations in the brand colours. A scratch generator script made them and is not checked in.
They were generated rather than downloaded: the public Lottie samples do not include
matching animations and carry LottieFiles licences. To use a licensed animation instead,
replace the file with the same name. test/lottie_assets_test.dart checks that each file parses.

Keep each file under ~100 KB.
