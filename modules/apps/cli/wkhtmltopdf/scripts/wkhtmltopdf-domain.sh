#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: wkhtmltopdf-domain <domain-or-url> [output-dir]

Converts all pages in a domain to individual PDFs.

Behavior:
- Attempts to read URLs from /sitemap.xml (and nested sitemap indexes).
- Falls back to a full crawl of the domain if no sitemap URLs are found.

Environment:
- WKHTMLTOPDF_ARGS: extra arguments passed to wkhtmltopdf for each page.

Example:
  wkhtmltopdf-domain https://example.com ./pdfs
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit 1
fi

input="${1}"
output_dir="${2:-}"

if [[ -z "$output_dir" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  output_dir="./wkhtmltopdf-domain-$timestamp"
fi

mkdir -p "$output_dir"

normalize_base_url() {
  local raw="$1"
  if [[ "$raw" =~ ^https?:// ]]; then
    echo "$raw"
    return
  fi
  echo "https://$raw"
}

base_url="$(normalize_base_url "$input")"
base_url="${base_url%/}"

host="$(printf '%s' "$base_url" | awk -F/ '{print $3}')"

if [[ -z "$host" ]]; then
  echo "Error: unable to determine host from '$input'" >&2
  exit 1
fi

sitemap_urls=()
page_urls=()

add_unique() {
  local -n arr=$1
  local value="$2"
  local existing
  for existing in "${arr[@]}"; do
    if [[ "$existing" == "$value" ]]; then
      return
    fi
  done
  arr+=("$value")
}

is_same_host() {
  local url="$1"
  local url_host
  url_host="$(printf '%s' "$url" | awk -F/ '{print $3}')"
  [[ "$url_host" == "$host" ]]
}

extract_locs() {
  sed -n 's#.*<loc>\(.*\)</loc>.*#\1#p'
}

fetch_sitemap() {
  local url="$1"
  if ! curl -fsSL "$url" 2>/dev/null; then
    return 1
  fi
}

scheme="${base_url%%://*}"
sitemap_base="${scheme}://$host"

seed_sitemaps=("$sitemap_base/sitemap.xml")

declare -A seen_sitemaps

auto_add_sitemap() {
  local sitemap="$1"
  if [[ -n "${seen_sitemaps[$sitemap]:-}" ]]; then
    return
  fi
  seen_sitemaps["$sitemap"]=1
  add_unique sitemap_urls "$sitemap"
}

for sm in "${seed_sitemaps[@]}"; do
  auto_add_sitemap "$sm"
done

index=0
while [[ $index -lt ${#sitemap_urls[@]} ]]; do
  sitemap="${sitemap_urls[$index]}"
  index=$((index + 1))
  if ! content="$(fetch_sitemap "$sitemap")"; then
    continue
  fi

  while IFS= read -r loc; do
    if [[ -z "$loc" ]]; then
      continue
    fi

    if [[ "$loc" == *.xml || "$loc" == *"sitemap"* ]]; then
      if is_same_host "$loc"; then
        auto_add_sitemap "$loc"
      fi
      continue
    fi

    if is_same_host "$loc"; then
      add_unique page_urls "$loc"
    fi
  done < <(printf '%s' "$content" | extract_locs)
done

filter_asset_urls() {
  sed 's/#.*$//' |
    grep -Evi '\.(jpg|jpeg|png|gif|svg|css|js|pdf|zip|gz|tar|tgz|bz2|xz|mp4|mp3|wav|ogg|webm|woff2?|ttf|ico)(\?.*)?$'
}

if [[ ${#page_urls[@]} -eq 0 ]]; then
  echo "No sitemap URLs found, falling back to crawl..." >&2

  crawl_urls="$(
    wget --spider --recursive --no-verbose --level=inf --domains "$host" --no-parent "$base_url" 2>&1 |
      grep -Eo 'https?://[^ ]+' |
      sed 's/[),]$//' |
      filter_asset_urls |
      sort -u || true
  )"

  while IFS= read -r url; do
    if [[ -z "$url" ]]; then
      continue
    fi
    if is_same_host "$url"; then
      add_unique page_urls "$url"
    fi
  done < <(printf '%s\n' "$crawl_urls")
fi

if [[ ${#page_urls[@]} -eq 0 ]]; then
  echo "No pages discovered for host '$host'" >&2
  exit 1
fi

urls_file="$output_dir/urls.txt"
: > "$urls_file"

for url in "${page_urls[@]}"; do
  printf '%s\n' "$url" >> "$urls_file"

done

wkhtml_args=(--quiet --print-media-type)
if [[ -n "${WKHTMLTOPDF_ARGS:-}" ]]; then
  read -r -a extra_args <<<"$WKHTMLTOPDF_ARGS"
  wkhtml_args+=("${extra_args[@]}")
fi

count=0
failures=0

for url in "${page_urls[@]}"; do
  slug="$(printf '%s' "$url" | sed 's#^https\?://##; s#[^A-Za-z0-9._-]#_#g')"
  output_pdf="$output_dir/$slug.pdf"

  count=$((count + 1))
  echo "[$count/${#page_urls[@]}] $url -> $output_pdf" >&2

  if ! wkhtmltopdf "${wkhtml_args[@]}" "$url" "$output_pdf"; then
    echo "Failed: $url" >&2
    failures=$((failures + 1))
  fi

done

if [[ $failures -gt 0 ]]; then
  echo "Completed with $failures failures." >&2
  exit 1
fi

printf 'Done. PDFs in %s\n' "$output_dir"
