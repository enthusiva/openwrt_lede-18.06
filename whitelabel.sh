#!/bin/bash
# White-label rename: dragino -> enthutech across the firmware repo and the packages feed.
# Dry-run by default; pass --apply to modify the working trees (nothing is committed or pushed).
#
#   ./whitelabel.sh                 # report only
#   ./whitelabel.sh --apply         # rewrite content, rename paths, delete build junk
#   ./whitelabel.sh --apply --include-copyright   # also rewrite copyright/(c) lines (see GPL note in README)
#
# Env overrides: BRAND DOMAIN GH_ORG REPOS

set -euo pipefail

BRAND=${BRAND:-enthutech}
DOMAIN=${DOMAIN:-enthutechaiot.com}      # replaces dragino.com (URLs, e-mail addresses, opkg repo host)
GH_ORG=${GH_ORG:-enthusiva}              # replaces github.com/dragino
REPOS=${REPOS:-"/home/sivakumar/github/openwrt_lede-18.06 /home/sivakumar/github/enthutech-packages"}
JUNK="openwrt/make.log openwrt/build.log openwrt/nohup.out openwrt/feeds.conf.default.bak openwrt/.config.orig
      openwrt/.config.save openwrt/.config.save.1 openwrt/.config.save.2 openwrt/.config.save.3
      general_files/etc/opkg/distfeeds.conf.bak"

APPLY=0; COPYRIGHT=0
for a in "$@"; do
	case $a in
	--apply) APPLY=1 ;;
	--include-copyright) COPYRIGHT=1 ;;
	*) echo "unknown option $a"; exit 1 ;;
	esac
done

Cap="$(tr '[:lower:]' '[:upper:]' <<<"${BRAND:0:1}")${BRAND:1}"
UP="$(tr '[:lower:]' '[:upper:]' <<<"$BRAND")"
export BRAND Cap UP DOMAIN GH_ORG COPYRIGHT

rewrite() {	# stdin lines -> stdout lines; same rules as the perl below
	perl -pe '
		unless (!$ENV{COPYRIGHT} && /copyright|\(c\)/i) {
			s{github\.com/dragino/dragino-packages}{github.com/$ENV{GH_ORG}/$ENV{BRAND}-packages}gi;
			s{github\.com/dragino/}{github.com/$ENV{GH_ORG}/}gi;
			s{Dragino Dragino}{$ENV{Cap}}g;
			s{dragino\.com}{$ENV{DOMAIN}}gi;
			s{dragino}{$ENV{BRAND}}g;
			s{Dragino}{$ENV{Cap}}g;
			s{DRAGINO}{$ENV{UP}}g;
		}'
}

for repo in $REPOS; do
	echo "=================== $repo"
	cd "$repo"

	echo "--- build junk to delete:"
	for j in $JUNK; do git ls-files --error-unmatch "$j" >/dev/null 2>&1 && echo "  $j"; done

	echo "--- text files to rewrite:"
	mapfile -d '' files < <(git grep -Iliz dragino -- . || true)
	echo "  ${#files[@]} files"

	echo "--- tracked paths to rename:"
	mapfile -t paths < <(git ls-files | grep -i dragino || true)
	echo "  ${#paths[@]} paths"

	echo "--- binary files containing the name (cannot be auto-rewritten):"
	git grep -il dragino -- . | while read -r f; do git grep -Iiq dragino -- "$f" || echo "  $f"; done

	if [ "$COPYRIGHT" = 0 ]; then
		echo "--- copyright lines left untouched (review for GPL before removing):"
		git grep -Iin dragino -- . | grep -iE 'copyright|\(c\)' | cut -c1-160 | sed 's/^/  /' | head -40
	fi

	[ "$APPLY" = 1 ] || continue

	for j in $JUNK; do git ls-files --error-unmatch "$j" >/dev/null 2>&1 && git rm -q "$j"; done

	# re-list after junk removal
	mapfile -d '' files < <(git grep -Iliz dragino -- . || true)
	for f in "${files[@]}"; do
		[ -L "$f" ] && continue
		rewrite <"$f" >"$f.wl.tmp" && cat "$f.wl.tmp" >"$f" && rm -f "$f.wl.tmp"   # cat keeps mode
	done

	mapfile -t paths < <(git ls-files | grep -i dragino || true)
	for p in "${paths[@]}"; do
		np=$(printf '%s\n' "$p" | perl -pe 's/dragino/$ENV{BRAND}/g; s/Dragino/$ENV{Cap}/g; s/DRAGINO/$ENV{UP}/g')
		mkdir -p "$(dirname "$np")"
		git mv -k "$p" "$np"
	done
	echo "  applied."
done

echo
echo "Remaining matches (should be copyright lines / binaries only):"
for repo in $REPOS; do (cd "$repo" && git grep -Iic dragino -- . | grep -v ':0$' | sed "s|^|$(basename "$repo"): |" | head -20); done
