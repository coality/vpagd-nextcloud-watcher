#!/bin/bash

ARCHIVES_DIR="/var/www/nextcloud/public_html/data/jerome/files/VideoPsalm/SlidesMesse/Archives"

if [[ ! -d "$ARCHIVES_DIR" ]]; then
    echo "Archives directory not found: $ARCHIVES_DIR"
    exit 1
fi

cd "$ARCHIVES_DIR" || exit 1

for file in *.odt; do
    [[ -f "$file" ]] || continue
    
    base_name=$(echo "$file" | sed 's/ ([0-9-]*_[0-9-]*)\.odt$//')
    
    mkdir -p "$base_name"
    mv "$file" "$base_name/"
    echo "Moved: $file -> $base_name/"
done

echo "Done."
