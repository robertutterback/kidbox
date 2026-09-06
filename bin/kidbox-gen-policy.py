#!/usr/bin/env python3
"""Generate the Chromium managed-policy file from /etc/kidbox/sites.conf.

Run as root, either directly or via install.sh, after editing sites.conf.

The policy is deny-by-default: everything is blocked, and only the domains
listed in sites.conf (plus file:// URLs, which the clock and the book need)
are allowed. It applies to every Chromium launch on the machine, not just to
website menu items -- that is deliberate, since it means there is no browser
state in which the allowlist is off.
"""

import json
import os
import stat
import sys
from urllib.parse import urlsplit

SITES_CONF = os.environ.get("KIDBOX_SITES_CONF", "/etc/kidbox/sites.conf")

# The product directory in the policy path follows the browser build's name,
# and Raspberry Pi OS and Debian disagree about it. Writing both is cheaper
# than detecting which one this build reads.
POLICY_DIRS = [
    "/etc/chromium/policies/managed",
    "/etc/chromium-browser/policies/managed",
]
POLICY_NAME = "kidbox.json"

# The clock and the instruction book are file:// URLs, so a bare deny-all
# would break two menu items that have nothing to do with the internet.
BASE_ALLOW = ["file://*"]


def parse_sites(path):
  """Return (allowed_domains, site_count) from a sites.conf."""
  domains = []
  sites = 0

  with open(path, encoding="utf-8") as f:
    for lineno, raw in enumerate(f, 1):
      line = raw.strip()
      if not line or line.startswith("#"):
        continue

      fields = [p.strip() for p in line.split("|")]
      kind = fields[0].upper()

      if kind == "ALLOW":
        if len(fields) < 2:
          sys.exit(f"{path}:{lineno}: ALLOW line has no domains")
        domains += [d for d in fields[1].split(",") if d]

      elif kind == "SITE":
        if len(fields) < 4:
          sys.exit(f"{path}:{lineno}: SITE line needs Name|URL|domains")
        _, name, url, domain_list = fields[:4]
        if not name or not url:
          sys.exit(f"{path}:{lineno}: SITE line needs both a name and a URL")
        domains += [d for d in domain_list.split(",") if d]
        # Allow the entry URL's own host even if it was left out of the domain
        # list -- forgetting it would produce a menu item that opens a block
        # page, which is a confusing way to find out about a typo.
        host = urlsplit(url).hostname
        if host:
          domains.append(host)
        sites += 1

      else:
        sys.exit(f"{path}:{lineno}: unknown line type {fields[0]!r}")

  # Preserve file order so the generated policy reads like the config.
  return list(dict.fromkeys(domains)), sites


def build_policy(domains):
  return {
      # Deny everything, then allow back the listed domains.
      "URLBlocklist": ["*"],
      "URLAllowlist": BASE_ALLOW + domains,

      # Remove the ways out of a kiosk window that do not need an address bar.
      "DeveloperToolsAvailability": 2,   # disallowed everywhere
      "DownloadRestrictions": 3,         # block all downloads
      "PrintingEnabled": False,
      "IncognitoModeAvailability": 1,    # incognito disabled
      "DefaultPopupsSetting": 2,         # block popups (no origin-bar windows)
      "BrowserSignin": 0,                # no sign-in, so no sync escape hatch
      "SyncDisabled": True,
      "BookmarkBarEnabled": False,
      "EditBookmarksEnabled": False,
      "PasswordManagerEnabled": False,
      "AutofillAddressEnabled": False,
      "AutofillCreditCardEnabled": False,
      "TranslateEnabled": False,
      "PromotionalTabsEnabled": False,
      "MetricsReportingEnabled": False,

      # Nothing here needs the camera, the mic, or the kids' location.
      "VideoCaptureAllowed": False,
      "AudioCaptureAllowed": False,
      "DefaultGeolocationSetting": 2,
      "DefaultNotificationsSetting": 2,

      # Chromium can do its own DNS over HTTPS, which resolves names without
      # going near the system resolver -- and so straight past the filtering
      # DNS that install.sh configures. Force it back onto the system one.
      "DnsOverHttpsMode": "off",

      # Belt and braces on the search sites that are not in the allowlist.
      "ForceGoogleSafeSearch": True,
      "ForceYouTubeRestrict": 2,
      "SafeBrowsingProtectionLevel": 1,
  }


def main():
  if os.geteuid() != 0:
    sys.exit("Please run as root.")

  if not os.path.exists(SITES_CONF):
    sys.exit(f"{SITES_CONF} not found. Run install.sh first.")

  domains, sites = parse_sites(SITES_CONF)
  policy = build_policy(domains)
  blob = json.dumps(policy, indent=2, sort_keys=True) + "\n"

  for directory in POLICY_DIRS:
    os.makedirs(directory, mode=0o755, exist_ok=True)
    path = os.path.join(directory, POLICY_NAME)
    with open(path, "w", encoding="utf-8") as f:
      f.write(blob)
    os.chmod(path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
    print(f"[kidbox] Wrote {path}")

  print(f"[kidbox] {sites} website menu item(s), {len(domains)} allowed domain(s):")
  for d in domains:
    print(f"[kidbox]   {d}")
  print("[kidbox] Chromium reads policy at startup; already-open windows keep the old one.")


if __name__ == "__main__":
  main()
