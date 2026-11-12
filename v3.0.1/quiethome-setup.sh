# Quiet Home setup. Runs ON the Fire TV, started from your PC with:
#   adb push quiethome-setup.sh /data/local/tmp/
#   adb shell sh /data/local/tmp/quiethome-setup.sh
#
# It changes three settings, all undone by quiethome-undo.sh:
#   1. Power-saving exemption for Quiet Home, so its Home-button timer is never delayed.
#   2. alarm_manager_constants min_futurity=0, so that timer can fire at once. Otherwise Android
#      makes every app timer wait at least 5 seconds, and you'd see Amazon's home for 5 seconds.
#   3. Switches on Quiet Home's Home-button helper (an accessibility service; Fire TV has no menu
#      for this), keeping any other accessibility services you already use.
# Safe to run again at any time, e.g. after updating Quiet Home or Fire OS.

PKG=quiet.home
SVC=quiet.home/quiet.home.HomeRedirectService

if ! pm path "$PKG" 2>/dev/null | grep -q '^package:'; then
  echo "Quiet Home isn't installed yet. On your PC run:  adb install -r QuietHome.apk"
  exit 1
fi

sdk=$(getprop ro.build.version.sdk)
case "$sdk" in ''|*[!0-9]*) sdk=28 ;; esac
echo "Quiet Home setup on $(getprop ro.product.model) (Android API $sdk)"
if [ "$sdk" -lt 28 ]; then
  echo "Note: this Fire OS is older than Fire OS 7. The Home-button helper may be refused here."
fi

# 1. Power-saving exemption
dumpsys deviceidle whitelist +"$PKG" >/dev/null 2>&1
echo "[1/3] Power-saving exemption: on"

# 2. Let Quiet Home's timer fire immediately. A min_futurity you had set before is saved for undo.
if [ "$sdk" -ge 31 ]; then
  old=$(device_config get alarm_manager min_futurity 2>/dev/null)
  case "$old" in null|''|0) ;; *) settings put global quiethome_saved_min_futurity "$old" ;; esac
  device_config put alarm_manager min_futurity 0
else
  cur=$(settings get global alarm_manager_constants)
  [ "$cur" = "null" ] && cur=""
  old=$(echo "$cur" | tr ',' '\n' | sed -n 's/^min_futurity=//p' | head -n 1)
  case "$old" in ''|0) ;; *) settings put global quiethome_saved_min_futurity "$old" ;; esac
  rest=$(echo "$cur" | tr ',' '\n' | grep -v '^min_futurity=' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
  if [ -n "$rest" ]; then new="$rest,min_futurity=0"; else new="min_futurity=0"; fi
  settings put global alarm_manager_constants "$new"
fi
echo "[2/3] Instant Home switching: on"

# 3. The Home-button helper, keeping any other accessibility services
cur=$(settings get secure enabled_accessibility_services)
[ "$cur" = "null" ] && cur=""
others=$(echo "$cur" | tr ':' '\n' | grep -v "^$PKG/" | grep -v '^$' | tr '\n' ':' | sed 's/:$//')
if [ -n "$others" ]; then new="$others:$SVC"; else new="$SVC"; fi
case ":$cur" in
  *":$PKG/"*)
    # Already listed: take it out for a moment so Android starts it afresh.
    if [ -n "$others" ]; then
      settings put secure enabled_accessibility_services "$others"
    else
      settings delete secure enabled_accessibility_services >/dev/null 2>&1
    fi
    sleep 1
    ;;
esac
settings put secure enabled_accessibility_services "$new"
settings put secure accessibility_enabled 1
echo "[3/3] Home-button helper: switched on"

# Check that Fire OS actually started it.
i=0
bound=no
while [ "$i" -lt 15 ]; do
  if dumpsys accessibility 2>/dev/null | grep -qE 'label=(Quiet Home|quiet\.home)'; then
    bound=yes
    break
  fi
  sleep 1
  i=$((i + 1))
done

if [ "$bound" = no ]; then
  if logcat -d -b all 2>/dev/null | grep A11yAuthorizer | grep -q "$PKG"; then
    echo ""
    echo "Fire OS refused the helper: this build only runs accessibility services Amazon approves."
    echo "Quiet Home still works as a normal app (open it from Your Apps & Channels)."
    echo "To put the settings back: adb push quiethome-undo.sh /data/local/tmp/ then"
    echo "adb shell sh /data/local/tmp/quiethome-undo.sh"
    exit 2
  fi
  echo ""
  echo "The helper is switched on but Fire OS hasn't started it yet."
  echo "Restart the stick (adb reboot), reconnect, and run this script once more."
  exit 3
fi

input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
am start -n "$PKG/.LauncherActivity" >/dev/null 2>&1
echo ""
echo "All set. Press Home on your remote: Quiet Home should appear straight away."
