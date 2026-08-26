#!/bin/bash # Shared helpers for Android-only development workflows.

has_android_device() {
  flutter devices --machine 2>/dev/null | grep -q '"targetPlatform": "android'
}

print_no_android_device_help() {
  echo "No Android device or emulator detected."
  echo ""
  echo "Google Sign-In only works on Android in this app. Choose one option:"
  echo "  1. Connect a phone via USB and enable USB debugging"
  echo "  2. Create and start an emulator in Android Studio (Device Manager)"
  echo "  3. Install a release APK on a connected phone:"
  echo "       ./install_android_release.sh"
  echo ""
  echo "Then verify with: flutter devices"
}

require_android_device() {
  if has_android_device; then
    return 0
  fi

  print_no_android_device_help
  return 1
}

# Pick the LAN IP your phone is most likely to reach over Wi-Fi/Ethernet.
# USB/RNDIS addresses are only returned when no standard LAN interface exists.
detect_local_api_host() {
  local lan_ip

  # Wi-Fi and common wired interface names
  lan_ip="$(
    ip -4 -o addr show scope global 2>/dev/null |
      awk '$2 ~ /^(wlan|wlp|eth|eno)/ {print $4}' |
      cut -d/ -f1 |
      head -1
  )"
  if [[ -n "${lan_ip}" ]]; then
    echo "${lan_ip}"
    return
  fi

  # Wired enp* excluding USB-tethering names (e.g. enp0s20f0u4u1c2)
  lan_ip="$(
    ip -4 -o addr show scope global 2>/dev/null |
      awk '$2 ~ /^enp/ && $2 !~ /u[0-9]/ {print $4}' |
      cut -d/ -f1 |
      head -1
  )"
  if [[ -n "${lan_ip}" ]]; then
    echo "${lan_ip}"
    return
  fi

  # Last resort: USB tethering / RNDIS (phone must share that link)
  ip -4 -o addr show scope global 2>/dev/null |
    awk '$2 ~ /^(enp|enx|usb|rndis)/ {print $4}' |
    cut -d/ -f1 |
    head -1
}
