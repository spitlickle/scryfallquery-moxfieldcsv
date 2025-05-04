#!/usr/bin/env bash

# Simple CLI: fetch a Scryfall CSV and output a minimal 13-column Moxfield import via curl + gawk
set -euo pipefail

# ensure gawk is available for FPAT support
if ! command -v gawk &>/dev/null; then
  echo "❌ This script requires gawk (GNU awk) for proper CSV parsing. Please install gawk and retry." >&2
  exit 1
fi

# Example queries
declare -A EXAMPLES=(
  [a]="Import a list of collector numbers from a draft|s:MID and (cn:279 or cn:231 or cn:203 or cn:187 or cn:298 or cn:169)"
  [b]="Search for all green cards in P3K|s:p3k and color:green"
  [c]="Find all cards with 'draw' in oracle text|o:draw"
  [d]="Cards with converted mana cost <= 2|cmc<=2"
  [e]="Fetch all English foils from Ravnica Allegiance|e:rav and foil and lang:en"
)

# Parse -q flag
QUERY=""
while getopts ":q:" opt; do
  case "$opt" in
    q) QUERY="$OPTARG" ;;
    *) echo "Usage: $0 [-q QUERY]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

# Function to show examples and let user pick one
show_examples() {
  echo -e "\nExamples:"
  # Sort keys alphabetically
  for key in $(printf "%s\n" "${!EXAMPLES[@]}" | sort); do
    printf "  [%s]=\"%s\"\n" "$key" "${EXAMPLES[$key]%%|*}"
  done

  read -rp "Select example (or q to cancel): " sel
  if [[ "$sel" =~ ^[Qq]$ ]]; then
    return 1
  fi

  if [[ -n "${EXAMPLES[$sel]}" ]]; then
    example_query="${EXAMPLES[$sel]#*|}"
    echo -e "\nExample query:\n$example_query"
    read -rp $'\nEnter your Scryfall search (or press Enter to use the example): ' input
    QUERY="${input:-$example_query}"
    return 0
  else
    echo "Invalid selection." >&2
    return 1
  fi
}


# Prompt if no QUERY provided via -q
if [[ -z "$QUERY" ]]; then
  while true; do
    read -rp "Enter your Scryfall search (or ex for examples): " input
    if [[ "$input" =~ ^(ex|EX)$ ]]; then
      if show_examples; then
        break
      fi
    elif [[ -n "$input" ]]; then
      QUERY="$input"
      break
    fi
  done
fi

# Prompt for output file path
read -rp "Output CSV file: " OUTPUT
# Ensure .csv extension
if [[ ! "$OUTPUT" =~ \.csv$ ]]; then
  OUTPUT="${OUTPUT}.csv"
fi

# Temp file
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

# Fetch raw CSV (exclude Alchemy printings)
curl -sG "https://api.scryfall.com/cards/search" \
  --data-urlencode "q=${QUERY} -set:alchemy" \
  --data-urlencode "format=csv" \
  -o "$tmpfile"

# Clean CSV: keep only requested columns (name, edition, language, collector_number)
gawk -v FPAT='"[^"]*"|[^,]+' -v OFS=',' '
  BEGIN {
    moxfield_header = "Count Tradelist,Count,Name,Edition,Condition,Language,Foil,Tags,Last Modified,Collector Number,Alter,Proxy,Purchase Price"
    print moxfield_header
  }
  NR==1 {
    for (i=1; i<=NF; i++) {
      h = $i
      gsub(/^"|"$/, "", h)
      idx[h] = i
    }
    next
  }
  {
    name = $idx["name"]
    setn = $idx["set"]
    lang = $idx["lang"]
    cn   = $idx["collector_number"]

    # remove quotes
    gsub(/^"|"$/, "", name)
    gsub(/^"|"$/, "", setn)
    gsub(/^"|"$/, "", lang)
    gsub(/^"|"$/, "", cn)

    # Skip garbage entries (empty, pure number, or mana cost)
    if (name == "" || name ~ /^[0-9.]+$/ || name ~ /^\{.*\}$/) next

    # Normalize:
    # Remove "A-" arena prefixes
    sub(/^A-/, "", name)

    # If split card, just keep the first half
    split(name, parts, " // ")
    name = parts[1]

    # Protect names with commas
    if (name ~ /,/) name = "\"" name "\""

    print "", "", name, setn, "", lang, "", "", "", cn, "", "", ""
  }
' "$tmpfile" > "$OUTPUT"


echo "✅ CSV written to $OUTPUT"
