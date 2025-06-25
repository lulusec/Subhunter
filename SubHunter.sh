#!/bin/bash

# --- Farby pre výstup ---
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Funkcia na zobrazenie bannera ---
print_banner() {
cat << "EOF"
  ____  _   _ ____  _   _ _   _ _   _ _____ _____ ____  
 / ___|| | | | __ )| | | | | | | \ | |_   _| ____|  _ \ 
 \___ \| | | |  _ \| |_| | | | |  \| | | | |  _| | |_) |
  ___) | |_| | |_) |  _  | |_| | |\  | | | | |___|  _ < 
 |____/ \___/|____/|_| |_|\___/|_| \_| |_| |_____|_| \_\                                                        
           Passive Subdomain Enumeration Tool
EOF
echo ""
}

# --- Funkcia na zobrazenie nápovedy ---
print_help() {
    echo -e "${YELLOW}Usage:${NC} $0 -d <domain> [options]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -d <domain>   Target domain to enumerate subdomains"
    echo "  -g            Use Google Dorking with auto-generated cookies (optional)"
    echo "  -j            Perform JS subdomain discovery on live hosts (optional, requires httprobe & jsubfinder)"
    echo "  -h            Show this help message"
}


USE_GOOGLE_DORKING=false
USE_JS_DISCOVERY=false

if [[ $# -eq 0 ]]; then print_help; exit 1; fi
while getopts ":d:gjh" opt; do
    case ${opt} in
        d ) DOMAIN=$OPTARG ;;
        g ) USE_GOOGLE_DORKING=true ;;
        j ) USE_JS_DISCOVERY=true ;;
        h ) print_help; exit 0 ;;
        \? ) echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2; print_help; exit 1 ;;
        : ) echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2; print_help; exit 1 ;;
    esac
done
if [[ -z "$DOMAIN" ]]; then echo -e "${RED}Error: No domain provided.${NC}"; print_help; exit 1; fi

print_banner
echo -e "${CYAN}[*] Starting subdomain enumeration for: ${YELLOW}$DOMAIN${NC}"
mkdir -p results
OUTFILE="results/subdomains_$DOMAIN.txt"
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TMP_DIR"' EXIT

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SGOO_SCRIPT_PATH="$SCRIPT_DIR/tools/sd-goo/sd-goo.sh"
PYTHON_BOT_PATH="$SCRIPT_DIR/GoogleBot.py"

run_and_count() {
    local cmd="$1"
    local label="$2"
    local outfile="$3"
    echo -e "${BLUE}[+] Running $label...${NC}"
    eval "$cmd" > "$outfile" 2>/dev/null
    local count=$(wc -l < "$outfile" 2>/dev/null || echo 0)
    printf "${GREEN}[*] %-18s:${NC} %s\n" "$label" "$count"
}

if [ "$USE_GOOGLE_DORKING" = true ]; then
    VENV_DIR="$SCRIPT_DIR/venv"
    VENV_PYTHON="$VENV_DIR/bin/python3"
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR" > /dev/null 2>&1
        "$VENV_DIR/bin/pip" install selenium > /dev/null 2>&1
    fi
    if [[ -f "$SGOO_SCRIPT_PATH" && -x "$SGOO_SCRIPT_PATH" && -f "$PYTHON_BOT_PATH" ]]; then
        GENERATED_COOKIES=$("$VENV_PYTHON" "$PYTHON_BOT_PATH" 2> /dev/null)
        if [ -n "$GENERATED_COOKIES" ]; then
            SGOO_CMD="$SGOO_SCRIPT_PATH -d \"$DOMAIN\" -c \"$GENERATED_COOKIES\""
            run_and_count "$SGOO_CMD" "Google Dorking" "$TMP_DIR/sgoo.tmp"
        fi
    fi
fi

run_and_count "assetfinder -subs-only \"$DOMAIN\"" "Assetfinder" "$TMP_DIR/assetfinder.tmp"
run_and_count "amass enum -passive -d \"$DOMAIN\"" "Amass" "$TMP_DIR/amass.tmp"
run_and_count "subfinder -d \"$DOMAIN\" -silent" "Subfinder" "$TMP_DIR/subfinder.tmp"
run_and_count "findomain -t \"$DOMAIN\" -q" "Findomain" "$TMP_DIR/findomain.tmp"
run_and_count "(curl -s \"https://crt.sh/?q=%25.$DOMAIN&output=json\" | jq -r '.[].name_value' | sed 's/\\n/\n/g'; curl -s \"https://api.certspotter.com/v1/issuances?domain=$DOMAIN&include_subdomains=true&expand=dns_names\" | jq -r '.[].dns_names[]' | grep -iE \"\\.$DOMAIN$\")" "Cert Sources" "$TMP_DIR/certs.tmp"

echo -e "${BLUE}[+] Running Internet Archives ${NC}"
ARCHIVE_OUTFILE="$TMP_DIR/archives.tmp"
ARCHIVE_CMD="(gau --threads 5 --subs \"$DOMAIN\"; waybackurls \"$DOMAIN\") | cut -d/ -f3 | sed 's/:.*//' | grep -iE \"\\.?$DOMAIN\$\" | sort -u"
timeout 250s bash -c "$ARCHIVE_CMD" > "$ARCHIVE_OUTFILE" 2>/dev/null
if [[ -s "$ARCHIVE_OUTFILE" ]]; then
    count=$(wc -l < "$ARCHIVE_OUTFILE")
else
    count=0
fi
printf "${GREEN}[*] %-18s:${NC} %s\n" "Internet Archives" "$count"

# --- Zjednotenie, filtrovanie a uloženie počiatočných výsledkov ---
cat "$TMP_DIR"/*.tmp 2>/dev/null | grep -E "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$" | sort -u > "$OUTFILE"

# =================================================================================
# --- NOVÁ SEKCIA: Spustenie JS Subdomain Discovery, ak je zadaný prepínač -j ---
# =================================================================================
if [ "$USE_JS_DISCOVERY" = true ]; then
    # Pridá prázdny riadok pre lepšiu čitateľnosť

    # Kontrola, či sú potrebné nástroje nainštalované
    if ! command -v httprobe &> /dev/null || ! command -v jsubfinder &> /dev/null; then
        echo -e "${RED}[!] Chyba: 'httprobe' alebo 'jsubfinder' nie je nainštalovaný. Preskakujem JS discovery.${NC}"
        echo -e "${YELLOW}[!] Spustite install.sh pre inštaláciu všetkých potrebných nástrojov.${NC}"
    else
        # Nový, stručnejší výstup
        echo -e "${BLUE}[+] Subdomains from JavaScript files on live hosts ${NC}"
        
        # 1. Zistíme, ktoré subdomény sú "živé" (beží na nich web server)
        HTTP_PROBED_FILE="$TMP_DIR/probed_hosts.tmp"
        cat "$OUTFILE" | httprobe -c 50 > "$HTTP_PROBED_FILE" 2>/dev/null
        
        NEW_JS_COUNT=0
        # Pokračujeme, len ak sme našli nejaké živé hosty
        if [[ -s "$HTTP_PROBED_FILE" ]]; then
            # 2. Spustíme jsubfinder na živých hostoch
            JS_FOUND_FILE="$TMP_DIR/js_found.tmp"
            jsubfinder search --silent -f "$HTTP_PROBED_FILE" -o "$JS_FOUND_FILE" 2>/dev/null
            
            # 3. Ak sa našli nové subdomény, pridáme ich a spočítame
            if [[ -s "$JS_FOUND_FILE" ]]; then
                NEW_JS_COUNT=$(wc -l < "$JS_FOUND_FILE")
                # Pridáme nové subdomény k existujúcim a znova prefiltrujeme
                cat "$OUTFILE" "$JS_FOUND_FILE" | sort -u > "$TMP_DIR/final_combined.tmp"
                mv "$TMP_DIR/final_combined.tmp" "$OUTFILE"
            fi
        fi
        
        # Zobrazíme finálny počet nájdených subdomén v požadovanom formáte
        printf "${GREEN}[*] %-18s:${NC} %s\n" "Subdomains from JS" "$NEW_JS_COUNT"
    fi
fi

echo -e "${BLUE}[+] Combining and filtering initial results...${NC}"
# --- Finálne spracovanie ---
FINALCOUNT=$(wc -l < "$OUTFILE")
rm -rf -- "$TMP_DIR"

echo ""
echo -e "${GREEN}[*] Total unique and valid subdomains found:${NC} $FINALCOUNT"
echo -e "${CYAN}[+] Subdomain enumeration completed. Results saved in ${YELLOW}$OUTFILE${NC}"
