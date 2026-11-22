# Puts back everything quiethome-setup.sh changed. Runs ON the Fire TV, from your PC:
#   adb push quiethome-undo.sh /data/local/tmp/
#   adb shell sh /data/local/tmp/quiethome-undo.sh
# Quiet Home stays installed; remove it afterwards with:  adb uninstall quiet.home

PKG=quiet.home

sdk=$(getprop ro.build.version.sdk)
case "$sdk" in ''|*[!0-9]*) sdk=28 ;; esac

# 3. Home-button helper off, keeping any other accessibility services
cur=$(settings get secure enabled_accessibility_services)
[ "$cur" = "null" ] && cur=""
others=$(echo "$cur" | tr ':' '\n' | grep -v "^$PKG/" | grep -v '^$' | tr '\n' ':' | sed 's/:$//')
if [ -n "$others" ]; then
  settings put secure enabled_accessibility_services "$others"
else
  settings delete secure enabled_accessibility_services >/dev/null 2>&1
  settings put secure accessibility_enabled 0
fi
echo "[1/3] Home-button helper: off"

# 2. Timers back to normal (or to the min_futurity you had before)
saved=$(settings get global quiethome_saved_min_futurity)
[ "$saved" = "null" ] && saved=""
if [ "$sdk" -ge 31 ]; then
  if [ -n "$saved" ]; then
    device_config put alarm_manager min_futurity "$saved"
  else
    device_config delete alarm_manager min_futurity >/dev/null 2>&1
  fi
else
  cur=$(settings get global alarm_manager_constants)
  [ "$cur" = "null" ] && cur=""
  rest=$(echo "$cur" | tr ',' '\n' | grep -v '^min_futurity=' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
  if [ -n "$saved" ]; then rest="${rest:+$rest,}min_futurity=$saved"; fi
  if [ -n "$rest" ]; then
    settings put global alarm_manager_constants "$rest"
  else
    settings delete global alarm_manager_constants >/dev/null 2>&1
  fi
fi
settings delete global quiethome_saved_min_futurity >/dev/null 2>&1
echo "[2/3] App timers: back to normal"

# 1. Power-saving exemption off
dumpsys deviceidle whitelist -"$PKG" >/dev/null 2>&1
echo "[3/3] Power-saving exemption: off"

am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
echo ""
echo "Done. The Home button opens Amazon's home screen again."
echo "To remove Quiet Home too:  adb uninstall $PKG"
