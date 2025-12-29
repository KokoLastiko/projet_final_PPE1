export LC_ALL=C.UTF-8

if [ $# -ne 2 ]; then
    echo "Ce programme demande deux arguments (le fichier contenant les URLs et le fichier HTML de sortie)"
    exit 1
fi

OCC=0
FICHIER_URLS=$1
HTML_FILE=$2

cat > "$HTML_FILE" << EOF
<html>
<head>
<meta charset="UTF-8">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@1.0.4/css/bulma.min.css">
    <title>Résultats d’analyse des URLs</title>
    <style>
        body {font-family: Arial, sans-serif; margin: 15px; }
        table {border-collapse: collapse; width: 100%;}
        th, td { border : 1px solid #ddd; padding: 8px; text-align: left;}
        th {background-color: #f8f8f8;}
        tr:nth-child(even) {background-color: #fafafa;}
    </style>
  </head>
  <body>
   <h1>Résultats d’analyse des URLs</h1>
    <table>
     <tr><th>#</th><th>URL</th><th>Code HTTP</th><th>Encodage</th><th>Nombre d'oni total</th><th>HTML brut</th><th>Dump textuel</th><th>Concordancier</th></tr>
EOF

mkdir -p html_brut
mkdir -p dump_textuel
mkdir -p concordance

while read -r line; do
    if [ -z "$line" ]; then
        continue
    fi

    if ! echo "$line" | grep -q -E "^https://|^http://"; then
       target=\"_blank\"  echo "URL ignorée (invalide) : $line"
        continue
    fi

    OCC=$((OCC + 1))

    CODE=$(curl -s -o tmp.txt -w "%{http_code}" "$line")

    if [ "$CODE" -eq 200 ]; then
        RAW_HTML="html_brut/raw_${OCC}.html"
        VIEW_HTML="html_brut/view_${OCC}.html"

        curl -s -A "Mozilla/5.0" "$line" -o "$RAW_HTML"

        {
            echo "<html><head><meta charset='UTF-8'>"
            echo "<title>HTML brut</title>"
            echo "<style>pre{white-space:pre-wrap;font-size:12px;}</style>"
            echo "</head><body>"
            echo "<h2>HTML brut de :</h2><p>$line</p><pre>"
            sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$RAW_HTML"
            echo "</pre></body></html>"
        } > "$VIEW_HTML"

        HTML_CELL="<a href=\"$VIEW_HTML\">Aperçu</a>"
    else
        HTML_CELL="vide"
    fi

    if [ "$CODE" -eq 200 ]; then
        DUMP_FILE="dump_textuel/dump_${OCC}.txt"
        DUMP_CELL="<a href=\"$DUMP_FILE\">Dump</a>"

        lynx -dump -nolist "$RAW_HTML" > "$DUMP_FILE"

        CONC_FILE="concordance/conc_${OCC}.html"
        CONC_CELL="<a href=\"$CONC_FILE\">Concordance</a>"
       {
    echo "<html><head><meta charset='UTF-8'>"
    echo "<title>Concordance de $line</title>"
    echo "<style>table {border-collapse: collapse; width: 100%;} th, td { border: 1px solid #ddd; padding: 8px; text-align: left;} th {background-color: #f8f8f8;} tr:nth-child(even) {background-color: #fafafa;}</style>"
    echo "</head><body>"
    echo "<h2>Concordance de : $line</h2>"
    echo "<p>Voici les occurrences du mot cible :</p>"
    echo "<table>"
    echo "<tr><th>Contexte</th></tr>"

    # Recherche des occurrences et ajout du surlignage
    grep -o -P ".{0,15}(鬼|oni|おに).{0,15}" "$DUMP_FILE" | while read context; do
        # Mettre en rouge le mot "鬼" ou "oni" dans le contexte
        SURLIGNER=$(echo "$context" | sed -E 's/(鬼|oni|おに)/<span style="color:red;font-weight:bold;">\1<\/span>/g')

        echo "<tr><td>$SURLIGNER</td></tr>"
    done

    echo "</table></body></html>"
    } > "$CONC_FILE"
    else
        DUMP_CELL="vide"
        CONC_CELL="vide"

    fi

    ENCODAGE=$(grep -oiE '<meta[^>]+charset=[^ ]+' tmp.txt | head -n1 | sed -E 's/.*charset=["'\'']?([^"'\'' >]+).*/\1/i')
    ENCODAGE=$(echo "$ENCODAGE" | tr '[:lower:]' '[:upper:]')

    if iconv -l | tr '[:lower:]' '[:upper:]' | grep -qw "$ENCODAGE"; then
        if [ "$ENCODAGE" != "UTF-8" ]; then
            iconv -f "$ENCODAGE" -t UTF-8 tmp.txt -o tmp_utf8.txt 2>/dev/null \
                && mv tmp_utf8.txt tmp.txt \
                && ENCODAGE="UTF-8 (converti depuis $ENCODAGE)"
        fi
    else
        ENCODAGE="UTF-8"
    fi

    lynx -dump -stdin -nolist < tmp.txt > aspiration.txt

    NB_KANJI=$(grep -o "鬼" aspiration.txt | wc -l)
    NB_HIRAGANA=$(grep -Po '(?<![ぁ-ゖ])おに(?![ぁ-ゖ])' aspiration.txt | wc -l)
    NB_ROMAJI=$(grep -Poi '(?<![a-z])oni(?![a-z])' aspiration.txt | wc -l)
    NB_TOTAL=$((NB_KANJI + NB_HIRAGANA + NB_ROMAJI))

    if [ "$CODE" -ne 200 ]; then
        CODE="403 : site web inaccessible"
        ENCODAGE="vide"
        NB_TOTAL="vide"
        HTML_RAW="vide"
    fi

    rm -f tmp.txt aspiration.txt
    printf "%d\t%s\t%s\t%s\t%s\n" "$OCC" "$line" "$CODE" "$ENCODAGE"
    cat >> "$HTML_FILE" << EOF
    <tr>
    <td>$OCC</td>
    <td><a href="$line">$line</a></td>
    <td>$CODE</td>
    <td>$ENCODAGE</td>
    <td>$NB_TOTAL</td>
    <td>$HTML_CELL</td>
    <td>$DUMP_CELL</td>
    <td>$CONC_CELL</td>
    </tr>
EOF

done < "$FICHIER_URLS"

cat >> "$HTML_FILE" << EOF
  </table>
 </body>
</html>
EOF

