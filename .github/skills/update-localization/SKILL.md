---
name: update-localization
description: Refresh the Celestia localization POT template and PO catalogs from the Apple, Android, and Windows app sources, translating new strings for previously complete locales. Use when asked to update localization, regenerate celestia_ui.pot, or sync PO files with the template.
---

# Update localization

Run this workflow from the `celestia-i18n` repository root. Build the Swift
localization tools, extract the shared template, then update every PO catalog.
Translate newly added strings for locales that were fully translated before
the refresh; do not add translations for previously incomplete locales.
This does not require building the Apple, Android, or Windows applications.

## Preparation

- Read applicable repository instructions in the source and localization
  repositories before working with them.
- Inspect the working-tree status of `celestia-i18n` and `CelestiaLocalization`.
  Preserve existing changes; do not reset, clean, commit, or push.
- By default, all repositories are siblings under the parent of `celestia-i18n`.
  In the usual checkout this is
  `/Users/linfel/Developer/Personal/Celestia`.
  Set `CELESTIA_ROOT` explicitly if the checkouts live elsewhere.
- The existing `CelestiaLocalization/common/celestia_ui.pot` is an input as well
  as the extraction destination. Do not delete it or create an empty replacement.

## Record translation completeness before updating

Before running extraction or updating any catalogs:

- Snapshot the current POT and PO catalogs in temporary session storage outside
  the repositories. Use the actual working-tree files, not `HEAD`, so existing
  local translations are included.
- Record the old template's active entry keys using `(msgctxt, msgid)`.
- Record which locales are fully translated: every active, non-header entry
  in the locale and every active entry required by the old template must have a
  nonempty, non-fuzzy translation. All required plural forms, if present, must
  be translated. Ignore obsolete entries and the metadata header; an empty
  catalog does not count as fully translated.
- Use PO-aware parsing that handles escaped strings and multiline values.
  Do not infer completeness by grepping for `msgstr ""`, since translated
  multiline entries also begin that way.
- Keep this pre-update eligibility list fixed throughout the workflow. Do not
  determine eligibility after new untranslated entries have been introduced.

## Build, extract, and update

Execute the following as a single Bash script from the repository root. Stop on
the first failure; never update PO catalogs after a failed extraction.

```bash
set -euo pipefail

celestia_root="${CELESTIA_ROOT:-$(dirname "$PWD")}"
apple_root="$celestia_root/MobileCelestia"
android_root="$celestia_root/AndroidCelestia"
windows_root="$celestia_root/CelestiaUWP"
common="$celestia_root/CelestiaLocalization/common"
template="$common/celestia_ui.pot"

for source_root in "$apple_root" "$android_root" "$windows_root"; do
    if [ ! -d "$source_root" ]; then
        printf 'Missing source repository: %s\n' "$source_root" >&2
        exit 1
    fi
done
if [ ! -f "$template" ]; then
    printf 'Missing localization template: %s\n' "$template" >&2
    exit 1
fi

shopt -s nullglob
po_files=("$common"/*.po)
if [ "${#po_files[@]}" -eq 0 ]; then
    printf 'No PO catalogs found in: %s\n' "$common" >&2
    exit 1
fi

swift build --product ExtractorApp
swift build --product UpdaterApp

.build/debug/ExtractorApp \
    "$apple_root" "$android_root" "$windows_root" "$template"

for po in "${po_files[@]}"; do
    .build/debug/UpdaterApp "$po" "$template"
done

printf 'Updated template and processed %s PO catalogs.\n' "${#po_files[@]}"
```

## Translate new strings for previously complete locales

After extraction and all PO updates succeed:

- Compare the new POT's active `(msgctxt, msgid)` keys with the snapshot to
  identify newly added strings, including changed source text or context.
- For each locale on the pre-update fully translated list, translate those new
  entries whose translations are empty or fuzzy. Preserve any valid translation
  already present, and leave all previously incomplete locales unchanged beyond
  the normal template update.
- Use the catalog's language/region, existing terminology, translator comments,
  source references, and surrounding UI to produce natural, consistent
  translations. Inspect the referenced app code when a string is ambiguous.
- Preserve format placeholders and their types, markup, escapes, significant
  whitespace, and newline structure. Supply every required plural form when
  applicable. Keep PO syntax valid and preserve existing metadata and unrelated
  translations.
- Do not use English copies or placeholder text merely to mark entries complete.
  An unchanged source string is appropriate only when correct for that locale,
  such as a proper name. If a translation cannot be determined confidently,
  report the locale and entry as blocked rather than claiming completion.
- Skip translation when there are no new strings or no eligible locales.

## Verification and reporting

- Inspect `git diff --stat` and the POT/PO diff in `CelestiaLocalization`,
  accounting for changes already present before the workflow.
- Run `git diff --check` in `CelestiaLocalization` and report any failures
  without silently reformatting unrelated translations.
- Confirm that extraction and every updater invocation succeeded. On failure,
  report the failing command/catalog and that earlier files may already have
  been modified; do not claim the refresh completed.
- Reparse the edited catalogs and validate translation placeholders against
  their source strings. Verify that every previously complete locale remains
  fully translated, with no missing, empty, or fuzzy active entries, and that
  translation edits are limited to new entries in eligible locales.
- Report the template path, number of PO catalogs processed, locales receiving
  translations, and any blocked entries, unexpected removals, or unrelated
  changes. An unchanged catalog is a valid result.
- Do not run `FormatterApp` as part of this workflow.
