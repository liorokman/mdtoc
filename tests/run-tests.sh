#!/usr/bin/env bash
#
# Tests for the toc script. Run from anywhere:  tests/run-tests.sh
# Exits non-zero if any test fails.

TOC="$(cd "$(dirname "$0")/.." && pwd)/toc"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/toc-tests.XXXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "ok   - $1"; }
fail() { FAILED=$((FAILED + 1)); echo "FAIL - $1"; [ -n "$2" ] && printf '%s\n' "$2" | sed 's/^/       /'; }

# assertEq NAME EXPECTED ACTUAL
assertEq() {
   if [ "$2" = "$3" ]; then
      pass "$1"
   else
      fail "$1" "$(diff <(printf '%s\n' "$2") <(printf '%s\n' "$3"))"
   fi
}

# assertTrue NAME COMMAND...
assertTrue() {
   local name="$1"; shift
   if "$@"; then pass "$name"; else fail "$name"; fi
}

fileMode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
markerCount() { grep -c "^<!-- TOC $2 -->$" "$1"; }

# --- Heading detection and anchors ------------------------------------------

cat > headings.md <<'EOF'
# Intro

## snake_case_name

## What is *

## Path C:\new\dir

#hashtag is not a heading

    # indented code is not a heading

```
# backtick fence
```

~~~
# tilde fence
~~~

````
```
# nested fence
```
````

## Closing hashes ##

## 100% done

## Intro

Setext One
==========

Setext Two
----------

## A [link](http://example.com) and ![image](x.png)

## `code` span

####### seven hashes is not a heading
EOF
# Files whose names an unquoted '*' would expand to
touch glob-bait-1.md glob-bait-2.md

assertEq "print mode: headings and GitHub anchors" \
"Table of Contents
=================

  * [Intro](#intro)
    * [snake_case_name](#snake_case_name)
    * [What is *](#what-is-)
    * [Path C:\\new\\dir](#path-cnewdir)
    * [Closing hashes](#closing-hashes)
    * [100% done](#100-done)
    * [Intro](#intro-1)
  * [Setext One](#setext-one)
    * [Setext Two](#setext-two)
    * [A link and image](#a-link-and-image)
    * [\`code\` span](#code-span)" \
"$("$TOC" -p headings.md)"

printf '# Duplicate\n# Duplicate\n# Duplicate\n' > dups.md
assertEq "duplicate headings get -1, -2 suffixes" \
"$(printf '  * [Duplicate](#duplicate)\n  * [Duplicate](#duplicate-1)\n  * [Duplicate](#duplicate-2)')" \
"$("$TOC" -p dups.md | grep '^ ')"

printf '# Windows\r\n\r\n## Line endings\r\n' > crlf.md
assertEq "CRLF line endings" \
"$(printf '  * [Windows](#windows)\n    * [Line endings](#line-endings)')" \
"$("$TOC" -p crlf.md | grep '^ ')"

printf -- '---\ntitle: Front matter\n---\n\n# Real heading\n' > fm.md
assertEq "front matter is not read as a setext heading" \
"  * [Real heading](#real-heading)" \
"$("$TOC" -p fm.md | grep '^ ')"

printf 'Paragraph\n\n---\n\n# Heading\n' > hr.md
assertEq "a thematic break after a blank line is not a heading" \
"  * [Heading](#heading)" \
"$("$TOC" -p hr.md | grep '^ ')"

# --- Updating files ----------------------------------------------------------

printf '# One\n\n## Two\n' > add.md
out=$("$TOC" add.md)
assertEq "without -a, a file with no markers is refused" \
"Updating add.md...failed - no TOC delimiters found. Maybe use -a ?" "$out"

"$TOC" -a add.md > /dev/null
assertTrue "-a adds the markers at the top" [ "$(head -1 add.md)" = "<!-- TOC START -->" ]
assertTrue "-a adds exactly one pair of markers" \
   [ "$(markerCount add.md START)$(markerCount add.md END)" = "11" ]
assertTrue "the ToC is written between the markers" grep -q '^    \* \[Two\](#two)$' add.md
assertTrue "content after the markers is kept" grep -q '^## Two$' add.md

"$TOC" -p add.md > printed.txt
assertTrue "the generated ToC is not itself read as a heading" \
   [ "$(grep -c 'Table of Contents' printed.txt)" = "1" ]

before=$(cat add.md)
assertEq "an unchanged file is reported up to date" \
"Updating add.md...already up to date" "$("$TOC" add.md)"
assertEq "an unchanged file is not modified" "$before" "$(cat add.md)"

echo '## Three' >> add.md
"$TOC" add.md > /dev/null
assertTrue "a new heading updates the ToC" grep -q '^    \* \[Three\](#three)$' add.md

"$TOC" -c add.md > /dev/null
assertTrue "switching to -c regenerates without -f" grep -q '^<details>$' add.md
"$TOC" add.md > /dev/null
assertTrue "switching back from -c regenerates without -f" grep -q '^=================$' add.md

assertEq "-f forces an update" "Updating add.md...done" "$("$TOC" -f add.md)"

printf -- '---\ntitle: x\n---\n# Heading\n' > fm-add.md
"$TOC" -a fm-add.md > /dev/null
assertEq "-a keeps front matter on the first lines" \
"$(printf -- '---\ntitle: x\n---\n\n<!-- TOC START -->')" "$(head -5 fm-add.md)"

printf '# Mode\n' > mode.md
chmod 644 mode.md
"$TOC" -a mode.md > /dev/null
assertEq "file permissions are preserved" "644" "$(fileMode mode.md)"

printf '# Linked\n' > target.md
ln -s target.md link.md
"$TOC" -a link.md > /dev/null
assertTrue "a symlink stays a symlink" [ -L link.md ]
assertTrue "the symlink target is updated" grep -q 'TOC START' target.md

printf '# Spaces\n' > "with spaces.md"
"$TOC" -a "with spaces.md" > /dev/null 2>&1
assertTrue "file names with spaces work" grep -q '\[Spaces\](#spaces)' "with spaces.md"

# --- Malformed markers and bad input -----------------------------------------

printf '<!-- TOC START -->\n# A\n' > start-only.md
before=$(cat start-only.md)
"$TOC" start-only.md > /dev/null; status=$?
assertTrue "only a START marker is an error" [ "$status" -ne 0 ]
assertEq "only a START marker leaves the file unchanged" "$before" "$(cat start-only.md)"

printf '<!-- TOC END -->\n<!-- TOC START -->\n# A\n' > reversed.md
before=$(cat reversed.md)
"$TOC" reversed.md > /dev/null; status=$?
assertTrue "END before START is an error" [ "$status" -ne 0 ]
assertEq "END before START leaves the file unchanged" "$before" "$(cat reversed.md)"

printf '<!-- TOC START --><!-- TOC END -->\n# A\n# B\n' > oneline.md
before=$(cat oneline.md)
"$TOC" -a oneline.md > /dev/null 2>&1
assertEq "markers sharing a line are not treated as markers, and nothing is lost" \
"$before" "$(sed '1,/^<!-- TOC END -->$/d' oneline.md | sed '1d')"

# shellcheck disable=SC2016  # literal backticks
printf 'Mention `<!-- TOC START -->` inline.\n\n# A\n' > inline.md
"$TOC" -a inline.md > /dev/null
assertTrue "an inline mention of a marker is ignored" grep -q '^  \* \[A\](#a)$' inline.md

"$TOC" missing.md > /dev/null 2> err.txt; status=$?
assertTrue "a missing file is an error" [ "$status" -ne 0 ]
assertTrue "a missing file gets a clear message" grep -q 'no such file' err.txt

"$TOC" > /dev/null 2>&1; status=$?
assertTrue "no file argument is an error" [ "$status" -ne 0 ]

"$TOC" -z add.md > /dev/null 2>&1; status=$?
assertTrue "an unknown option is an error" [ "$status" -ne 0 ]

"$TOC" -h > /dev/null; status=$?
assertTrue "-h succeeds" [ "$status" -eq 0 ]

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
