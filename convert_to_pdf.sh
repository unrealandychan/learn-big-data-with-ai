#!/bin/bash
WORKSPACE="/Users/228448/big-data-learn"
MD2PDF="$HOME/.npm-global/bin/md-to-pdf"

while IFS= read -r f; do
  rel="${f#$WORKSPACE/}"
  dir=$(dirname "$rel")
  base=$(basename "$rel" .md)

  if [ "$dir" = "." ]; then
    outdir="$WORKSPACE/pdf"
  else
    outdir="$WORKSPACE/pdf/$dir"
  fi

  mkdir -p "$outdir"
  cp "$f" "$outdir/$base.md"
  "$MD2PDF" "$outdir/$base.md" < /dev/null > "$outdir/$base.pdf"
  rm "$outdir/$base.md"
  echo "  ✔ $outdir/$base.pdf"
done < <(find "$WORKSPACE" -name "*.md" | grep -v "$WORKSPACE/pdf/" | sort)
