#!/usr/bin/env bash
#
# ctx-verite.sh : verifie, sans modele, les affirmations de la doc qui se controlent
# contre le depot. Il signale, il ne corrige rien.
#
# Usage :
#   bash ctx-verite.sh [--root <chemin>] [--strict] [--json] [--info]
#
# --strict : sortie en code 1 s'il reste une affirmation fausse (utile en CI).
# --json   : une liste d'objets {"section":"verite","niveau","fichier","message"}, la ligne
#            en tete du message.
# --info   : liste aussi les affirmations a relire (niveau info), cites au fil de la
#            phrase ou en nom seul, qui ne comptent pas pour --strict. --json les garde.
#
# Fichiers lus : CLAUDE.md, AGENTS.md, les piliers, docs/**/*.md. Jamais archives/.
# Hors blocs de code et hors commentaires HTML, sauf les arbres de repertoires, dont
# seuls les comptages en commentaire sont relus.
#
# Ce qui est verifie :
#   chemins entre backticks, scripts cites, options --x d'un script du depot,
#   commandes npm run, bun run, pnpm, yarn, make contre package.json et Makefile,
#   comptages « N fichiers » placés devant ou apres un repertoire, recomptes.
#
# Ce qui est ignore : une ligne qui dit « n'existe pas encore », « supprime », « a creer »,
# « exemple », les URL, les motifs avec <...>, * ou {...}, les chemins ignores par git,
# les chemins sous un sous-module non initialise, et ce que couvre
# `exceptions: verite=<motif>` (ou `lien=<motif>`) dans le bloc contexte:convention.
#
# Sortie : fichier:ligne  affirmation  raison, puis un total.
set -euf

# Bibliotheque commune, chargee avant le cd vers la racine.
. "$(dirname "$0")/ctx-commun.sh"

ROOT=""
STRICT=0
JSON=0
INFO=0

# Niveau de chaque famille. Une famille trop bavarde sur le terrain passe en `info`
# ici, sans toucher au reste du script. Seul `alerte` compte pour --strict.
NIVEAU_chemin=alerte
NIVEAU_script=alerte
NIVEAU_option=alerte
NIVEAU_commande=alerte
NIVEAU_comptage=alerte

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      # Une option a valeur sans valeur : message clair et code 2, pas une sortie muette.
      if [ $# -lt 2 ]; then echo "--root attend une valeur" >&2; exit 2; fi
      ROOT="$2"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    --json)    JSON=1; shift ;;
    --info)    INFO=1; shift ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
[ -d "$ROOT" ] || { echo "Racine introuvable : $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"
cd "$ROOT"

version_scripts || exit 2

SEP="$(printf '\037')"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ctx-verite.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
ALERTES="$TMP/alertes"
LISTE="$TMP/liste"
: > "$ALERTES"

EN_GIT=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then EN_GIT=1; fi

# Tous les fichiers et repertoires du depot, hors exclusions et archives, pour les
# recherches par suffixe ou par nom seul.
# shellcheck disable=SC2046
find . $(exclusions_find) \( -type f -o -type d \) 2>/dev/null | sed 's|^\./||' > "$LISTE" || true

SOUS_MODULES="$(sous_modules)"
DIR_ARCHIVES="$(conv_lire archives)"
[ -n "$DIR_ARCHIVES" ] || DIR_ARCHIVES="archives/"
DIR_ARCHIVES="${DIR_ARCHIVES%/}"
DIR_DOCS="$(conv_lire docs)"
[ -n "$DIR_DOCS" ] || DIR_DOCS="docs/"
DIR_DOCS="${DIR_DOCS%/}"
PILIERS="$(conv_lire piliers)"
[ -n "$PILIERS" ] || PILIERS="CODEMAP.md, TODOS.md, CHANGELOG.md"

# --- sorties -------------------------------------------------------------------

# Les exceptions du bloc ne se lisent qu'ici, au moment de signaler : les relire a chaque
# jeton rendrait le script lent, et la plupart des jetons ne donnent rien.
alerter() { # <famille> <fichier> <ligne> <affirmation> <raison> <cle d'exception>...
  local fam="$1" fic="$2" lig="$3" aff="$4" rai="$5" cle
  shift 5
  for cle in "$@"; do
    if conv_exception verite "$cle" || conv_exception lien "$cle"; then return 0; fi
  done
  printf '%s%s%s%s%s%s%s%s%s\n' "$fam" "$SEP" "$fic" "$SEP" "$lig" "$SEP" "$aff" "$SEP" "$rai" >> "$ALERTES"
  return 0
}

# --- aides de resolution -------------------------------------------------------

ext_connue() { # <nom> : code 0 si l'extension est de celles qu'on suit
  case "$1" in
    *.sh|*.bash|*.zsh|*.py|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.jsx|*.md|*.mdx|*.json|*.yaml|*.yml|*.toml) return 0 ;;
    *.sql|*.css|*.scss|*.html|*.txt|*.cfg|*.ini|*.csv|*.lock|*.xml|*.ps1|*.rb|*.go|*.rs|*.svg) return 0 ;;
    *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.tgz|*.pl) return 0 ;;
  esac
  return 1
}

ext_script() { # <nom> : code 0 si c'est un script executable par un interpreteur
  case "$1" in
    *.sh|*.bash|*.zsh|*.py|*.js|*.mjs|*.cjs|*.ts|*.rb|*.pl) return 0 ;;
  esac
  return 1
}

# Nom d'un dossier que les exclusions ecartent ou qu'un depot ne versionne pas.
dossier_exclu() { # <chemin>
  case "/$1/" in
    */node_modules/*|*/dist/*|*/build/*|*/target/*|*/vendor/*|*/.venv/*|*/venv/*) return 0 ;;
    */.next/*|*/.next-*|*/.cache/*|*/__pycache__/*|*/.git/*|*/coverage/*|*/.tmp/*) return 0 ;;
  esac
  return 1
}

ignore_par_git() { # <chemin>
  [ "$EN_GIT" -eq 1 ] || return 1
  # `.venv/` n'ignore un chemin absent que si on le donne avec son slash final
  git check-ignore -q -- "$1" 2>/dev/null && return 0
  git check-ignore -q -- "$1/" 2>/dev/null
}

sous_module_vide() { # <chemin> : code 0 s'il est sous un sous-module absent ou vide
  local sm
  [ -n "$SOUS_MODULES" ] || return 1
  while IFS= read -r sm; do
    [ -n "$sm" ] || continue
    case "$1" in
      "$sm"|"$sm"/*)
        if [ ! -d "$sm" ] || [ -z "$(ls -A "$sm" 2>/dev/null)" ]; then return 0; fi
        ;;
    esac
  done <<FIN
$SOUS_MODULES
FIN
  return 1
}

# Chemin du premier fichier du depot qui porte exactement ce nom, ou rien.
trouver_ailleurs() { # <nom>
  awk -v n="/$1" '
    { c = "/" $0; l = length(c); k = length(n)
      if (l >= k && substr(c, l - k + 1) == n) { print; exit } }' "$LISTE"
}

premier_connu() { # <dossier du doc> <chemin ou segment>
  local cur="$1" seg="$2"
  [ -e "$seg" ] && return 0
  while [ -n "$cur" ] && [ "$cur" != "." ] && [ "$cur" != "/" ]; do
    [ -e "$cur/$seg" ] && return 0
    case "$cur" in */*) cur="${cur%/*}" ;; *) cur="." ;; esac
  done
  case "$seg" in
    scripts|src|docs|tests|lib|bin|app|apps|packages|.claude|.github) return 0 ;;
  esac
  return 1
}

# Un chemin se termine-t-il par ce suffixe dans la liste des fichiers du depot ?
existe_par_suffixe() { # <suffixe>
  awk -v n="$(printf '/%s' "$1" | tr 'A-Z' 'a-z')" '
    { c = "/" $0; l = length(c); k = length(n)
      if (l >= k && tolower(substr(c, l - k + 1)) == n) { trouve = 1; exit } }
    END { exit trouve ? 0 : 1 }' "$LISTE"
}

# Resout <chemin> depuis le dossier du document, puis ses parents, puis la racine.
# Rend 0 si le chemin existe, et pose RES.
RES=""
resoudre() { # <dossier du doc> <chemin>
  local d="$1" p="${2%/}" cur
  RES=""
  [ -n "$p" ] || return 1
  if [ -e "$p" ]; then RES="$p"; return 0; fi
  cur="$d"
  while [ -n "$cur" ] && [ "$cur" != "." ] && [ "$cur" != "/" ]; do
    if [ -e "$cur/$p" ]; then RES="$cur/$p"; return 0; fi
    case "$cur" in */*) cur="${cur%/*}" ;; *) cur="." ;; esac
  done
  case "$p" in
    ../*) return 1 ;;
    */*)  if existe_par_suffixe "$p"; then RES="$p"; return 0; fi ;;
    *)    if existe_par_suffixe "$p"; then RES="$(trouver_ailleurs "$p")"; return 0; fi ;;
  esac
  return 1
}

# --- verification d'un chemin --------------------------------------------------

# Nettoie un jeton de backticks et pose le chemin candidat dans NORM, ou rien si ce n'en
# est pas un. Pas de sous-shell : cette fonction tourne a chaque jeton du depot.
NORM=""
normaliser_chemin() { # <jeton>
  local t="$1"
  NORM=""
  t="${t#\"}"; t="${t%\"}"; t="${t#\'}"; t="${t%\'}"
  t="${t#./}"
  case "$t" in
    ''|-*|/*|'~'*|http:*|https:*|mailto:*|git@*|'#'*) return 0 ;;
    .env*|*/.env*) return 0 ;;
    *YYYY*|*AAAA*|*MM-DD*|*MM-JJ*|*JJ-*|*XXXX*|*NNNN*|*xxxx*) return 0 ;;
    *'<'*|*'>'*|*'*'*|*'{'*|*'}'*|*'$'*|*'...'*|*'…'*|*'|'*|*'='*|*'@'*|*'('*|*')'*|*'['*|*']'*|*'\'*) return 0 ;;
    *' '*|*'	'*) return 0 ;;
  esac
  # numero de ligne, ancre ou symbole derriere le chemin : src/a.py:42, src/a.py#L3
  t="${t%%#*}"
  case "$t" in
    *:*) t="${t%%:*}" ;;
  esac
  t="${t%[.,;]}"
  [ -n "$t" ] || return 0
  [ "${#t}" -le 200 ] || return 0
  # un domaine n'est pas un chemin du depot
  case "$t" in
    *.com/*|*.fr/*|*.io/*|*.org/*|*.net/*|*.dev/*|*.app/*|*.ai/*|*.co/*) return 0 ;;
  esac
  NORM="$t"
  return 0
}

# Un jeton est-il de ceux qu'on sait verifier, et sous quelle forme ?
# Pose FORME : "fichier" (nom avec extension suivie), "dossier" (slash final), "chemin"
# (sans extension, a verifier si son premier segment existe), ou rien.
forme_chemin() { # <chemin normalise>
  local t="$1" base
  FORME=""
  base="${t##*/}"
  case "$t" in
    */)
      FORME=dossier; return 0 ;;
  esac
  # `.py`, `.md` : une extension seule, pas un fichier
  case "$base" in
    .*.*) : ;;
    .*) if ext_connue "x$base"; then return 0; fi ;;
  esac
  if ext_connue "$base"; then
    case "$base" in
      .env*|*.example) return 0 ;;
    esac
    case "$t" in
      */*) FORME=fichier ;;
      *)
        # Next.js, Node.js : un nom de technologie, pas un fichier
        case "$base" in
          [A-Z]*.js) return 0 ;;
        esac
        FORME=nu
        ;;
    esac
    return 0
  fi
  case "$t" in
    */*) FORME=chemin ;;
  esac
  return 0
}

# Verifie un chemin cite. Famille : script si l'extension est celle d'un script.
# Pose SCRIPT_RESOLU quand le chemin cite existe et que c'est un script.
SCRIPT_RESOLU=""
POS_SPAN="m"
verifier_chemin() { # <doc> <ligne> <jeton brut>
  local doc="$1" ligne="$2" brut="$3" t forme docdir parent base famille tilde="" deplace=""
  SCRIPT_RESOLU=""
  normaliser_chemin "$brut"
  t="$NORM"
  [ -n "$t" ] || return 0
  forme_chemin "$t"
  forme="$FORME"
  [ -n "$forme" ] || return 0
  case "$doc" in */*) docdir="${doc%/*}" ;; *) docdir="." ;; esac
  if dossier_exclu "${t%/}"; then return 0; fi
  if sous_module_vide "${t%/}"; then return 0; fi

  if resoudre "$docdir" "$t"; then
    if [ -f "$RES" ] && ext_script "${RES##*/}"; then SCRIPT_RESOLU="$RES"; fi
    return 0
  fi
  if ignore_par_git "${t%/}"; then return 0; fi

  # Un chemin dont le dossier parent n'existe pas et dont le nom ne se trouve nulle part
  # designe presque toujours une bibliotheque tierce, un autre depot ou un dossier
  # d'execution (httpx/_models.py, worker/data/x), pas un trou dans le depot. Si le
  # nom existe ailleurs, c'est un fichier deplace : on signale.
  case "$forme" in
    nu) : ;;
    *)
      parent="${t%/}"
      case "$parent" in */*) parent="${parent%/*}" ;; *) parent="." ;; esac
      if [ "$parent" != "." ] && ! premier_connu "$docdir" "$parent" && ! existe_par_suffixe "${t%/}"; then
        base="${t%/}"; base="${base##*/}"
        existe_par_suffixe "$base" || return 0
      fi
      if [ "$parent" = "." ]; then
        # un dossier cite seul : on ne le suit que sous un nom de dossier conventionnel
        premier_connu "$docdir" "${t%/}" || return 0
      fi
      ;;
  esac
  case "$forme" in
    chemin)
      # sans extension et sans slash final : "and/or", "client/serveur"
      [ -d "${t%%/*}" ] || return 0
      ;;
    nu)
      # un nom seul ne se suit que pour un script shell ou un document : un fichier
      # de donnees, de configuration ou une source citee en nom court vient d'ailleurs
      case "${t##*/}" in
        *.sh|*.bash|*.md) : ;;
        *) return 0 ;;
      esac
      ;;
  esac
  # Un span cite au fil de la phrase, ou un nom seul, se relit : on le signale en info,
  # sauf si le fichier existe ailleurs sous le meme nom, preuve qu'il a ete deplace.
  if [ "$POS_SPAN" != "s" ] || [ "$forme" = nu ]; then tilde="~"; fi
  deplace=""
  if [ "$forme" = fichier ]; then
    base="${t##*/}"
    case "$base" in
      README.md|readme.md|index.*|__init__.py|main.*|Makefile|LICENSE*) : ;;
      # un nom de configuration est porte par trop d outils pour prouver un deplacement
      *.json|*.yaml|*.yml|*.toml|*.ini|*.cfg) : ;;
      *) deplace="$(trouver_ailleurs "$base")" ;;
    esac
    if [ -n "$deplace" ]; then
      famille=chemin
      if ext_script "$base"; then famille=script; fi
      case "$deplace" in
        */*) deplace="en $deplace" ;;
        *)   deplace="à la racine" ;;
      esac
      alerter "$famille" "$doc" "$ligne" "\`$brut\`" "absent, mais $base existe $deplace" "$t"
      return 0
    fi
  fi
  famille=chemin
  if ext_script "${t##*/}"; then famille=script; fi
  if [ "$famille" = script ]; then
    case "$forme" in
      nu) alerter "script$tilde" "$doc" "$ligne" "\`$brut\`" "aucun script de ce nom dans le dépôt" "$t" ;;
      *)  alerter "script$tilde" "$doc" "$ligne" "\`$brut\`" "ce script n'existe pas" "$t" ;;
    esac
  else
    case "$forme" in
      dossier) alerter "chemin$tilde" "$doc" "$ligne" "\`$brut\`" "ce répertoire n'existe pas" "$t" "${t%/}" ;;
      nu)      alerter "chemin$tilde" "$doc" "$ligne" "\`$brut\`" "aucun fichier de ce nom dans le dépôt" "$t" ;;
      *)       alerter "chemin$tilde" "$doc" "$ligne" "\`$brut\`" "ce chemin n'existe pas" "$t" ;;
    esac
  fi
  return 0
}

# --- options d'un script -------------------------------------------------------

# L'option apparait-elle dans le script, ou dans un fichier voisin qu'il source ?
option_presente() { # <script> <option>
  local s="$1" o="${2%%=*}" dir f nom
  if grep -Fq -- "$o" "$s" 2>/dev/null; then return 0; fi
  case "$s" in */*) dir="${s%/*}" ;; *) dir="." ;; esac
  # set -f est actif : pas de glob, find fait la liste
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$f" != "$s" ] || continue
    nom="${f##*/}"
    if grep -Fq -- "$nom" "$s" 2>/dev/null && grep -Fq -- "$o" "$f" 2>/dev/null; then return 0; fi
  done <<FIN
$(find "$dir" -maxdepth 1 -type f 2>/dev/null)
FIN
  return 1
}

verifier_option() { # <doc> <ligne> <script> <option> <explicite>
  local doc="$1" ligne="$2" script="$3" opt="$4" explicite="${5:-0}" f dsc tilde=""
  if ! option_presente "$script" "$opt"; then
    if [ "$explicite" -eq 0 ]; then
      case "$script" in */*) dsc="${script%/*}" ;; *) dsc="." ;; esac
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        if grep -Fq -- "${opt%%=*}" "$f" 2>/dev/null; then return 0; fi
      done <<FIN
$(find "$dsc" -maxdepth 1 -type f 2>/dev/null)
FIN
    fi
    if [ "$explicite" -eq 0 ] && [ "$POS_SPAN" != "s" ]; then tilde="~"; fi
    alerter "option$tilde" "$doc" "$ligne" "\`${opt%%=*}\`" "l'option n'apparaît pas dans $script" "$opt" "$script"
  fi
  return 0
}

# --- commandes de manifeste ----------------------------------------------------

package_json_a() { # <script>
  local f trouve=1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -Eq "\"$1\"[[:space:]]*:" "$f" 2>/dev/null; then trouve=0; break; fi
  done <<FIN
$PACKAGES
FIN
  return "$trouve"
}

cible_make_a() { # <cible>
  local f trouve=1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -Eq "^$1[[:space:]]*:([^=]|\$)" "$f" 2>/dev/null; then trouve=0; break; fi
  done <<FIN
$MAKEFILES
FIN
  return "$trouve"
}

verifier_commande() { # <doc> <ligne> <outil> <cible> <texte>
  local doc="$1" ligne="$2" outil="$3" cible="$4" texte="$5"
  case "$cible" in ''|-*|*[!A-Za-z0-9_:.-]*) return 0 ;; esac
  case "$cible" in *.*) return 0 ;; esac
  case "$outil" in
    make)
      if [ -z "$MAKEFILES" ]; then
        alerter commande "$doc" "$ligne" "\`$texte\`" "aucun Makefile dans le dépôt" "$texte"
      elif ! cible_make_a "$cible"; then
        alerter commande "$doc" "$ligne" "\`$texte\`" "pas de cible « $cible » dans le Makefile" "$texte"
      fi
      ;;
    *)
      if [ -z "$PACKAGES" ]; then
        alerter commande "$doc" "$ligne" "\`$texte\`" "aucun package.json dans le dépôt" "$texte"
      elif ! package_json_a "$cible"; then
        alerter commande "$doc" "$ligne" "\`$texte\`" "pas de script « $cible » dans package.json" "$texte"
      fi
      ;;
  esac
  return 0
}

# Repere les commandes d'un span et les verifie. Rend 0 si le span en portait une.
examiner_commande() { # <doc> <ligne> <span>
  local doc="$1" ligne="$2" span="$3" outil m1 m2 cible
  case "$span" in
    npm\ *|bun\ *|pnpm\ *|yarn\ *|make\ *) : ;;
    *) return 1 ;;
  esac
  # shellcheck disable=SC2086
  set -- $span
  outil="$1"; m1="${2:-}"; m2="${3:-}"
  case "$outil" in
    make)
      case "$m1" in -*) return 0 ;; esac
      verifier_commande "$doc" "$ligne" make "$m1" "make $m1"
      ;;
    npm)
      if [ "$m1" = run ] || [ "$m1" = run-script ]; then
        verifier_commande "$doc" "$ligne" npm "$m2" "npm run $m2"
      fi
      ;;
    bun|pnpm|yarn)
      if [ "$m1" = run ]; then
        cible="$m2"
        # bun run src/x.ts, pnpm run --filter ... : un fichier ou une option, pas un script
        case "$cible" in */*|-*) return 0 ;; esac
        verifier_commande "$doc" "$ligne" "$outil" "$cible" "$outil run $cible"
      else
        case "$m1" in
          ''|install|i|add|remove|rm|update|up|upgrade|test|t|start|publish|exec|dlx|x|create|init|audit|outdated|list|ls|why|link|unlink|prune|store|fetch|import|rebuild|patch|env|setup|deploy|pack|pm|repl|build|info|config|cache|help|workspace|workspaces|global|set|get|login|logout|whoami|version|view|search|-*) return 0 ;;
        esac
        verifier_commande "$doc" "$ligne" "$outil" "$m1" "$outil $m1"
      fi
      ;;
  esac
  return 0
}

# --- une ligne de prose --------------------------------------------------------

# Les spans d'une ligne arrivent un par un. On les garde pour associer une option
# seule au script qu'une autre span de la meme ligne cite.
LIGNE_COURANTE=""
DOC_COURANT=""
SPANS_LIGNE=""

vider_ligne() {
  local entree span opt script_unique nb s ligne="$LIGNE_COURANTE" doc="$DOC_COURANT"
  local scripts_ligne="" options_seules="" pos_script="m"
  [ -n "$ligne" ] || return 0
  while IFS= read -r entree; do
    [ -n "$entree" ] || continue
    POS_SPAN="${entree%"${entree#?}"}"
    span="${entree#?}"
    [ -n "$span" ] || continue
    if examiner_commande "$doc" "$ligne" "$span"; then continue; fi
    # une option seule : --force, --racine=<x>
    case "$span" in
      --[a-z]*)
        case "$span" in
          *[!A-Za-z0-9=\ \<\>._/-]*) : ;;
          *) options_seules="$options_seules
${span%% *}" ;;
        esac
        continue
        ;;
    esac
    # une forme "interprete script option..." ou "script option..."
    case "$span" in
      *' '*)
        # shellcheck disable=SC2086
        set -- $span
        while [ $# -gt 0 ]; do
          case "$1" in
            bash|sh|zsh|python|python3|node|bun|deno|tsx|uv|run|npx|'$') shift ;;
            *) break ;;
          esac
        done
        [ $# -gt 0 ] || continue
        s="$1"; shift
        normaliser_chemin "$s"
        s="$NORM"
        [ -n "$s" ] || continue
        if ext_script "${s##*/}"; then
          verifier_chemin "$doc" "$ligne" "$s"
          if [ -n "$SCRIPT_RESOLU" ]; then
            for opt in "$@"; do
              case "$opt" in
                --[a-z]*) verifier_option "$doc" "$ligne" "$SCRIPT_RESOLU" "$opt" 1 ;;
              esac
            done
          fi
        fi
        ;;
      *)
        verifier_chemin "$doc" "$ligne" "$span"
        if [ -n "$SCRIPT_RESOLU" ]; then
          scripts_ligne="$scripts_ligne
$SCRIPT_RESOLU"
          pos_script="$POS_SPAN"
        fi
        ;;
    esac
  done <<FIN
$SPANS_LIGNE
FIN
  if [ -n "$options_seules" ]; then
    script_unique="$(printf '%s\n' "$scripts_ligne" | sed '/^$/d' | sort -u)"
    nb="$(printf '%s\n' "$script_unique" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "$nb" -eq 1 ]; then
      while IFS= read -r opt; do
        [ -n "$opt" ] || continue
        POS_SPAN="$pos_script"
        verifier_option "$doc" "$ligne" "$script_unique" "$opt"
      done <<FIN
$options_seules
FIN
    fi
  fi
  return 0
}

# --- comptages -----------------------------------------------------------------

compter_fichiers() { # <dossier> <nom>
  local d="$1" nom="$2" liste
  if [ "$EN_GIT" -eq 1 ]; then
    liste="$(git ls-files -co --exclude-standard -- "$d" 2>/dev/null || true)"
  else
    # shellcheck disable=SC2046
    liste="$(find "$d" $(exclusions_find) -type f 2>/dev/null || true)"
  fi
  case "$nom" in
    scripts)
      printf '%s\n' "$liste" | awk '/\.(sh|bash|py|js|mjs|cjs|ts|rb|pl|ps1)$/ {n++} END {print n + 0}'
      ;;
    fiches)
      printf '%s\n' "$liste" | awk '/\.md$/ {n++} END {print n + 0}'
      ;;
    *)
      printf '%s\n' "$liste" | awk 'NF {n++} END {print n + 0}'
      ;;
  esac
  return 0
}

verifier_comptage() { # <doc> <ligne> <nombre> <nom> <dossier>
  local doc="$1" ligne="$2" nombre="$3" nom="$4" d="${5%/}" reel docdir
  case "$doc" in */*) docdir="${doc%/*}" ;; *) docdir="." ;; esac
  case "$nom" in files) nom=fichiers ;; esac
  if [ ! -d "$d" ]; then
    if [ "$docdir" != "." ] && [ -d "$docdir/$d" ]; then d="$docdir/$d"; else return 0; fi
  fi
  if sous_module_vide "$d"; then return 0; fi
  reel="$(compter_fichiers "$d" "$nom")"
  if [ "$reel" -ne "$nombre" ]; then
    alerter comptage "$doc" "$ligne" "$nombre $nom (\`$d/\`)" "le répertoire en compte $reel" "$d" "$d/"
  fi
  return 0
}

# --- extraction ----------------------------------------------------------------

# Un fichier devient un flux d'enregistrements separes par \037 :
#   S ligne span                      un span entre backticks, hors bloc de code
#   N ligne nombre nom span-dossier   un comptage de prose a cote d'un repertoire
#   T ligne nombre nom chemin racine  un comptage dans le commentaire d'un arbre
extraire() { # <fichier>
  awk -v SEP="$SEP" '
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  function est_dossier_span(s) {
    if (s !~ /\/$/) return 0
    if (s ~ /[ \t*<>{}$|]/) return 0
    if (s ~ /^(\/|~|http)/) return 0
    return 1
  }
  # Les comptages d un texte : cherche "N fichiers" et ses voisins.
  function qualifie(avant) {
    avant = tolower(avant)
    if (avant ~ /(~|≈|environ|pres de|près de|plus de|moins de|au moins|au plus|jusqu.à|quelque|max|maximum|soit|>|<|\+|×|x|\/) ?$/) return 1
    if (avant ~ /[0-9.,]$/) return 1
    # un chiffre entre guillemets est cite, souvent pour le contredire
    if (avant ~ /(«|")[ \t]*(\*\*)?$/) return 1
    return 0
  }
  function suite_ok(apres) {
    apres = trim(apres)
    if (apres == "") return 1
    if (apres ~ /^(dont|dans|au |et |sous|hors|sur|en |à |a |ici|au total)/) return 1
    if (apres ~ /^[^A-Za-z]/) return 1
    return 0
  }
  function passe(l) {
    l = tolower(l)
    return (l ~ /(décrivait|annonçait|affirmait|disait|indiquait|comptait|portait|était|étaient|avait|au lieu de|contre [0-9]|passé de|passait)/)
  }
  function comptages(texte, mode, chemin, racine,    reste, off, deb, len, m, nombre, nom, avant, apres, i, best, dist, d, fin) {
    reste = texte; off = 0
    while (match(reste, /[0-9]+ (fichiers|files|scripts|fiches)/)) {
      deb = off + RSTART; len = RLENGTH
      m = substr(reste, RSTART, RLENGTH)
      split(m, mm, " ")
      nombre = mm[1]; nom = mm[2]
      avant = substr(texte, (deb > 25 ? deb - 25 : 1), (deb > 25 ? 25 : deb - 1))
      apres = substr(texte, deb + len, 30)
      if (!qualifie(avant) && suite_ok(apres) && !passe(texte)) {
        if (mode == "T") {
          printf "T%s%d%s%s%s%s%s%s%s%s\n", SEP, NR, SEP, nombre, SEP, nom, SEP, chemin, SEP, racine
        } else {
          best = ""; dist = 100000
          for (i = 1; i <= nsp; i++) {
            if (!est_dossier_span(sp[i])) continue
            # distance du bord du span au bord du nombre, a egalite le span d avant
            fin = spos[i] + length(sp[i]) + 2
            if (fin <= deb) d = deb - fin
            else d = spos[i] - (deb + len)
            if (d < 0) d = 0
            if (d < dist || (d == dist && spos[i] < deb)) { dist = d; best = sp[i] }
          }
          if (best != "" && dist <= 90 && !ext_line) {
            printf "N%s%d%s%s%s%s%s%s\n", SEP, NR, SEP, nombre, SEP, nom, SEP, best
          }
        }
      }
      off = deb + len - 1
      reste = substr(texte, off + 1)
    }
  }
  BEGIN { infence = 0; inhtml = 0; racine = "" }
  {
    ligne = $0
    sub(/\r$/, "", ligne)

    if (infence) {
      if (ligne ~ /^[ \t>]*(```|~~~)/) { infence = 0; next }
      t = ligne
      gsub(/\302\240/, " ", t)
      gsub(/│/, "|", t)
      gsub(/(├|└)(─|-)+/, "+--", t)
      gsub(/\|--/, "+--", t)
      gsub(/`--/, "+--", t)
      p = index(t, "+--")
      if (p == 0) {
        s = trim(t)
        if (first && s ~ /\/$/ && s !~ /[ \t]/) { racine = s; sub(/\/$/, "", racine); sub(/^~?\//, "", racine) }
        if (s != "") first = 0
        next
      }
      first = 0
      depth = int((p - 1) / 4)
      rest = trim(substr(t, p + 3))
      nm = rest; sub(/[ \t].*$/, "", nm)
      com = substr(rest, length(nm) + 1)
      pile[depth] = nm
      chemin = ""
      for (k = 0; k <= depth; k++) {
        e = pile[k]; sub(/\/$/, "", e)
        if (e == "") continue
        chemin = (chemin == "" ? e : chemin "/" e)
      }
      if (com != "") { nsp = 0; ext_line = 0; comptages(com, "T", chemin, racine) }
      next
    }

    if (inhtml) {
      p = index(ligne, "-->")
      if (p == 0) next
      ligne = substr(ligne, p + 3); inhtml = 0
    }
    if (ligne ~ /^[ \t>]*(```|~~~)/) {
      infence = 1; first = 1; racine = ""
      for (k in pile) delete pile[k]
      next
    }
    while ((s = index(ligne, "<!--")) > 0) {
      e = index(substr(ligne, s + 4), "-->")
      if (e == 0) { ligne = substr(ligne, 1, s - 1); inhtml = 1; break }
      ligne = substr(ligne, 1, s - 1) " " substr(ligne, s + 4 + e + 2)
    }

    # une tache cochee raconte ce qui a ete fait, pas ce qui est vrai maintenant
    # une ligne qui renvoie a un document date ou a un dossier d historique parle de lui
    if (ligne ~ /\]\([^)]*(sessions|plans|prompts|audits|superpowers|retros|journal|postmortems)\/[^)]*\)/) next
    if (ligne ~ /\]\([^)]*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][^)]*\)/) next
    # une tache ouverte decrit ce qui reste a faire, ses chemins sont souvent a creer
    if (ligne ~ /^[ \t>]*[-*+] \[[ xX]\]/) next
    # une phrase repliee sur deux lignes : le marqueur de la ligne d avant compte aussi
    suite = (ligne !~ /^[ \t>]*([-*+]|[0-9]+[.)]|#|\|)/ && ligne !~ /^[ \t]*$/)
    bas = tolower(ligne)
    if (suite) bas = tolower(precedente) " " bas
    precedente = ligne
    if (bas ~ /n(.|...)existe (pas|plus)|existe pas encore|supprim|à créer|a creer|à écrire|a ecrire|exemple|example|e\.g\.|par ex\.|hypoth|fictif|à venir|a venir|retiré|archiv|futur|prévu|à terme|deplac|déplac|renomm|remplacé|remplace par|obsol|ancien|gitignor|ignoré par git|n.est pas versionn|non versionn/) next

    # les spans de la ligne
    nsp = 0; ext_line = 0
    reste = ligne; off = 0
    while (match(reste, /`[^`]+`/)) {
      nsp++
      sp[nsp] = substr(reste, RSTART + 1, RLENGTH - 2)
      spos[nsp] = off + RSTART
      off += RSTART + RLENGTH - 1
      reste = substr(reste, RSTART + RLENGTH)
      sp[nsp] = trim(sp[nsp])
      if (sp[nsp] ~ /^\*?\.[A-Za-z0-9]+$/ || sp[nsp] ~ /^\*\.[A-Za-z0-9]+$/) ext_line = 1
      # on n envoie au shell que ce qu il sait verifier
      w1 = sp[nsp]; sub(/[ \t].*$/, "", w1)
      if (sp[nsp] ~ /[ \t]/) {
        if (w1 !~ /^(npm|bun|pnpm|yarn|make|bash|sh|zsh|python|python3|node|deno|tsx|uv|npx|\$)$/ && w1 !~ /\.(sh|bash|py|js|mjs|cjs|ts|rb|pl)$/) continue
      } else if (sp[nsp] !~ /[\/.]/ && sp[nsp] !~ /^--/) continue
      # Position : "s" si le span est le sujet de sa ligne (premier d une puce, cellule de
      # tableau seule), "m" s il est cite au fil de la phrase. Un debut de ligne ne suffit
      # pas : un paragraphe replie y met n importe quoi.
      pref = substr(ligne, 1, spos[nsp] - 1)
      suff = substr(ligne, spos[nsp] + length(sp[nsp]) + 2)
      pos = "m"
      if (pref ~ /^[ \t>]*([-*+]|[0-9]+[.)])[ \t]+(\*\*)?(\[[ xX]\] )?$/) pos = "s"
      else if (pref ~ /\|[ \t]*$/ && suff ~ /^[ \t]*\|/) pos = "s"
      printf "S%s%d%s%s%s%s\n", SEP, NR, SEP, pos, SEP, sp[nsp]
    }
    if (nsp > 0 || ligne ~ /[0-9]+ (fichiers|files|scripts|fiches)/) comptages(ligne, "N", "", "")
  }' "$1"
}

traiter_fichier() { # <fichier>
  local f="$1" k ligne a b c d
  LIGNE_COURANTE=""; DOC_COURANT="$f"; SPANS_LIGNE=""
  while IFS="$SEP" read -r k ligne a b c d || [ -n "${k:-}" ]; do
    case "$k" in
      S)
        if [ "$ligne" != "$LIGNE_COURANTE" ]; then
          vider_ligne
          LIGNE_COURANTE="$ligne"; SPANS_LIGNE=""
        fi
        SPANS_LIGNE="$SPANS_LIGNE
$a$b"
        ;;
      N)
        verifier_comptage "$f" "$ligne" "$a" "$b" "$c"
        ;;
      T)
        # a = nombre, b = nom, c = chemin de l'entree, d = racine de l'arbre
        if [ -n "$d" ] && [ -d "$d" ]; then c="$d/$c"; fi
        verifier_comptage "$f" "$ligne" "$a" "$b" "$c"
        ;;
    esac
  done < <(extraire "$f")
  vider_ligne
  return 0
}

# --- fichiers a lire -----------------------------------------------------------

LISTE_DOCS="$TMP/docs"
: > "$LISTE_DOCS"
ajouter_doc() { # <fichier>
  local f="$1" cible
  [ -f "$f" ] || return 0
  # le journal raconte le passe, ses chemins ont le droit d'avoir disparu
  case "${f##*/}" in CHANGELOG*|changelog*) return 0 ;; esac
  if [ -L "$f" ]; then
    cible="$(readlink "$f" 2>/dev/null || true)"
    case "$cible" in
      CLAUDE.md|AGENTS.md|./CLAUDE.md|./AGENTS.md) return 0 ;;
    esac
  fi
  printf '%s\n' "$f" >> "$LISTE_DOCS"
  return 0
}

ajouter_doc CLAUDE.md
ajouter_doc AGENTS.md
while IFS= read -r p; do
  p="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$p" ] || continue
  case "$p" in CLAUDE.md|AGENTS.md) continue ;; esac
  ajouter_doc "$p"
done <<FIN
$(printf '%s\n' "$PILIERS" | tr ',' '\n')
FIN
if [ -d "$DIR_DOCS" ]; then
  # Les dossiers qui racontent le passe : on n'y verifie rien. Un document date non
  # plus, ni un journal, qui decrivent un instant et pas l'etat du depot.
  set --
  for h in archives sessions plans superpowers retros journal postmortems prompts audits; do
    set -- "$@" -not -path "*/$h/*"
  done
  # shellcheck disable=SC2046
  find "$DIR_DOCS" $(exclusions_find) -name '*.md' -not -path "$DIR_ARCHIVES/*" "$@" \
    -not -name 'journal*' -not -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' 2>/dev/null \
    | LC_ALL=C sort >> "$LISTE_DOCS" || true
fi
sort -u "$LISTE_DOCS" -o "$LISTE_DOCS"

# Manifestes du depot, ecartes des dossiers exclus.
# shellcheck disable=SC2046
PACKAGES="$(find . -maxdepth 4 -name package.json $(exclusions_find) 2>/dev/null | sed 's|^\./||' || true)"
# shellcheck disable=SC2046
MAKEFILES="$(find . -maxdepth 4 \( -name Makefile -o -name makefile -o -name GNUmakefile -o -name '*.mk' \) $(exclusions_find) 2>/dev/null | sed 's|^\./||' || true)"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  f="${f#./}"
  traiter_fichier "$f"
done < "$LISTE_DOCS"

# --- rendu ---------------------------------------------------------------------

# Une meme affirmation citee a plusieurs lignes d'un fichier ne fait qu'une alerte :
# la premiere ligne, avec le nombre des autres.
RESUME="$TMP/resume"
sort -t "$SEP" -k2,2 -k3,3n "$ALERTES" | awk -F "$SEP" -v SEP="$SEP" '
  { cle = $2 SEP $4
    if (!(cle in vu)) { vu[cle] = ++n; fam[n] = $1; fic[n] = $2; lig[n] = $3; aff[n] = $4; rai[n] = $5; reste[n] = 0 }
    else {
      i = vu[cle]; reste[i]++
      # une occurrence en position de sujet l emporte sur les mentions au fil de la phrase
      if (fam[i] ~ /~$/ && $1 !~ /~$/) { fam[i] = $1; lig[i] = $3; rai[i] = $5 }
    } }
  END { for (i = 1; i <= n; i++) {
          r = rai[i]
          if (reste[i] > 0) r = r " (cité aussi à " reste[i] " autre(s) ligne(s))"
          printf "%s%s%s%s%s%s%s%s%s\n", fam[i], SEP, fic[i], SEP, lig[i], SEP, aff[i], SEP, r } }' > "$RESUME"

niveau_de() { # <famille>, avec ~ au bout quand l'affirmation est cité au fil de la phrase
  case "$1" in
    *'~') printf 'info\n'; return 0 ;;
  esac
  case "$1" in
    chemin)    printf '%s\n' "$NIVEAU_chemin" ;;
    script)    printf '%s\n' "$NIVEAU_script" ;;
    option)    printf '%s\n' "$NIVEAU_option" ;;
    commande)  printf '%s\n' "$NIVEAU_commande" ;;
    comptage)  printf '%s\n' "$NIVEAU_comptage" ;;
    *)         printf 'alerte\n' ;;
  esac
  return 0
}

NB_ALERTES=0
NB_INFOS=0
PREMIER=1
if [ "$JSON" -eq 1 ]; then printf '['; fi
while IFS="$SEP" read -r fam fic lig aff rai; do
  [ -n "$fam" ] || continue
  niv="$(niveau_de "$fam")"
  if [ "$niv" = alerte ]; then NB_ALERTES=$((NB_ALERTES + 1)); else NB_INFOS=$((NB_INFOS + 1)); fi
  if [ "$JSON" -eq 1 ]; then
    msg="ligne $lig : $aff : $rai"
    msg="$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    fjs="$(printf '%s' "$fic" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    if [ "$PREMIER" -eq 1 ]; then printf '\n'; PREMIER=0; else printf ',\n'; fi
    printf '  {"section":"verite","niveau":"%s","fichier":"%s","message":"%s"}' "$niv" "$fjs" "$msg"
  else
    if [ "$niv" = alerte ]; then
      printf '%s:%s  %s  %s\n' "$fic" "$lig" "$aff" "$rai"
    elif [ "$INFO" -eq 1 ]; then
      printf '%s:%s  %s  %s (info)\n' "$fic" "$lig" "$aff" "$rai"
    fi
  fi
done < "$RESUME"
if [ "$JSON" -eq 1 ]; then
  if [ "$PREMIER" -eq 1 ]; then printf ']\n'; else printf '\n]\n'; fi
else
  if [ "$NB_INFOS" -gt 0 ]; then
    if [ "$INFO" -eq 1 ]; then
      printf 'Total : %s affirmation(s) fausse(s), %s à relire (info).\n' "$NB_ALERTES" "$NB_INFOS"
    else
      printf 'Total : %s affirmation(s) fausse(s), %s à relire avec --info.\n' "$NB_ALERTES" "$NB_INFOS"
    fi
  else
    printf 'Total : %s affirmation(s) fausse(s).\n' "$NB_ALERTES"
  fi
fi

if [ "$STRICT" -eq 1 ] && [ "$NB_ALERTES" -gt 0 ]; then exit 1; fi
exit 0
