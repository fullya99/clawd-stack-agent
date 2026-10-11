#!/usr/bin/env bash
#
# ctx-commun.sh : bibliotheque sourcee par les scripts ctx-*.sh. Ne s'execute pas seule.
#
# Usage : . "$(dirname "$0")/ctx-commun.sh"
# Les fonctions lisent depuis le repertoire courant, ou depuis $CTX_RACINE si elle est posee.
# Le bloc lu est celui de <!-- contexte:convention ... -->, une ligne `cle: valeur` a la fois.
#
#   conv_trouver              chemin du premier .md racine qui porte le bloc, ou rien
#   conv_lire <cle>           valeur brute de la ligne `cle: valeur`, ou rien
#   conv_version              0 sans bloc, 4 pour un bloc sans version:, sinon la valeur
#   conv_seuil <fic> <def>    seuil de `seuils: A=600, B=250` pour <fic>, sinon <def>
#   conv_exception <t> <chem> code 0 si `exceptions: t=motif, ...` couvre <chem> (glob shell)
#   conv_journal_format       valeur de `journal:`, ou rien
#   journal_motif <format>    motif ERE d'un titre d'entree : date-titre, keep-a-changelog, crochets
#   journal_detecter <fic>    format declare par `journal:`, sinon celui trouve dans <fic>, ou rien
#   exclusions_find           repertoires ignores, sous forme d'arguments pour find
#   sous_modules              chemins des sous-modules, lus dans .gitmodules
#   version_scripts           code 1 et message si le bloc est plus recent que CTX_VERSION
#   conv_charger              lit le bloc une fois et le garde en memoire pour les appels suivants
#   ctx_aujourdhui            date du jour AAAA-MM-JJ, ou $CTX_AUJOURDHUI si elle est posee (tests)
#   ctx_epoch <AAAA-MM-JJ>    secondes depuis 1970, BSD d'abord puis GNU, rien si illisible
#   ctx_jours_depuis <date>   jours entre <date> et ctx_aujourdhui, rien si illisible
#
# Les fonctions rendent toujours 0 sauf conv_exception et version_scripts, pour ne pas
# tuer un appelant sous set -e.

CTX_VERSION=5

_ctx_racine() {
  printf '%s\n' "${CTX_RACINE:-.}"
}

# Bloc de convention : les lignes entre l'ouverture et la fermeture. Apres conv_charger,
# le bloc vient de la memoire : un audit qui interroge le bloc par fiche ne relit plus le
# fichier a chaque appel. La variable traverse les sous-shells $(...), c'est voulu.
_conv_bloc() {
  if [ "${CTX_BLOC_CHARGE:-0}" = 1 ]; then
    if [ -n "${CTX_BLOC_CACHE:-}" ]; then printf '%s\n' "$CTX_BLOC_CACHE"; fi
    return 0
  fi
  _conv_bloc_lire
}

conv_charger() {
  CTX_BLOC_CHARGE=0
  CTX_BLOC_CACHE="$(_conv_bloc_lire)"
  CTX_BLOC_CHARGE=1
  return 0
}

_conv_bloc_lire() {
  local f
  f="$(conv_trouver)"
  if [ -n "$f" ]; then
    # Un bloc ouvert et ferme sur la meme ligne est vide, on ne lit pas la suite du fichier.
    awk '/<!-- contexte:convention/ { if ($0 ~ /contexte:convention.*-->/) exit; dedans=1; next }
         dedans && /-->/ {exit}
         dedans {print}' "$f"
  fi
  return 0
}

# Liste `a=b, c=d` en une entree par ligne.
_conv_entrees() { # <cle>
  conv_lire "$1" | tr ',' '\n'
  return 0
}

_conv_trim() {
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

conv_trouver() {
  local r f
  r="$(_ctx_racine)"
  for f in CODEMAP.md CLAUDE.md AGENTS.md; do
    if [ -f "$r/$f" ] && grep -q '<!-- contexte:convention' "$r/$f" 2>/dev/null; then
      if [ "$r" = "." ]; then printf '%s\n' "$f"; else printf '%s\n' "$r/$f"; fi
      return 0
    fi
  done
  # find et non un glob : les appelants tournent sous set -f, ou ./*.md resterait litteral.
  for f in $(find "$r" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sed 's|.*/||' | LC_ALL=C sort); do
    case "$f" in CODEMAP.md|CLAUDE.md|AGENTS.md) continue ;; esac
    if grep -q '<!-- contexte:convention' "$r/$f" 2>/dev/null; then
      if [ "$r" = "." ]; then printf '%s\n' "$f"; else printf '%s\n' "$r/$f"; fi
      return 0
    fi
  done
  return 0
}

conv_lire() { # <cle>
  local cle="$1"
  _conv_bloc | awk -v k="$cle" '
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
      print v; exit
    }'
  return 0
}

conv_version() {
  local f v
  f="$(conv_trouver)"
  if [ -z "$f" ]; then echo 0; return 0; fi
  v="$(conv_lire version)"
  if [ -z "$v" ]; then echo 4; else echo "$v"; fi
  return 0
}

conv_seuil() { # <fichier> <defaut>
  local fic="$1" defaut="$2" e nom val
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    nom="$(printf '%s' "${e%%=*}" | _conv_trim)"
    val="$(printf '%s' "${e#*=}" | _conv_trim)"
    case "$val" in ''|*[!0-9]*) continue ;; esac
    if [ "$nom" = "$fic" ]; then echo "$val"; return 0; fi
  done <<FIN
$(_conv_entrees seuils)
FIN
  echo "$defaut"
  return 0
}

conv_exception() { # <type> <chemin>
  local type="$1" chemin="${2#./}" e t motif
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    t="$(printf '%s' "${e%%=*}" | _conv_trim)"
    motif="$(printf '%s' "${e#*=}" | _conv_trim)"
    [ "$t" = "$type" ] || continue
    [ -n "$motif" ] || continue
    # dans un case, * couvre aussi les /, donc ** et * se valent ici
    # shellcheck disable=SC2254
    case "$chemin" in $motif) return 0 ;; esac
  done <<FIN
$(_conv_entrees exceptions)
FIN
  return 1
}

conv_journal_format() {
  conv_lire journal
  return 0
}

# Les trois formats de journal reconnus. date-titre est le plus large, il couvre aussi
# un titre keep-a-changelog, c'est voulu : un journal mixte se lit comme date-titre.
# Ni antislash ni intervalle {n} : le meme motif sert a grep -E, a awk -v, a gawk qui
# mange les \[, et aux awk anciens sans intervalles. [[] et []] valent un crochet.
journal_motif() { # <format>
  local d='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
  case "${1:-}" in
    date-titre)       printf '%s\n' "^## .*${d}" ;;
    keep-a-changelog) printf '%s\n' "^## [[][^]]*[]] - ${d}" ;;
    crochets)         printf '%s\n' "^[[]${d}[]] " ;;
  esac
  return 0
}

# Le bloc decide s'il declare `journal:`. Sinon on compte les titres de chaque format hors
# blocs de code, et le plus specifique gagne quand il couvre tout le journal.
journal_detecter() { # <fichier>
  local f="${1:-}" decl dt kac cr
  decl="$(conv_journal_format)"
  if [ -n "$decl" ]; then
    printf '%s\n' "$decl"
    return 0
  fi
  [ -f "$f" ] || return 0
  _journal_compter() {
    M="$1" awk '/^```/ {code = !code; next} !code && $0 ~ ENVIRON["M"] {n++} END {print n + 0}' "$f"
  }
  dt="$(_journal_compter "$(journal_motif date-titre)")"
  kac="$(_journal_compter "$(journal_motif keep-a-changelog)")"
  cr="$(_journal_compter "$(journal_motif crochets)")"
  if [ "$cr" -gt "$dt" ]; then
    printf '%s\n' crochets
  elif [ "$kac" -gt 0 ] && [ "$kac" -eq "$dt" ]; then
    printf '%s\n' keep-a-changelog
  elif [ "$dt" -gt 0 ]; then
    printf '%s\n' date-titre
  fi
  return 0
}

# Une seule liste, a donner a find SANS guillemets, dans un contexte ou le shell ne
# developpe pas les motifs (set -f) : find . $(exclusions_find)
exclusions_find() {
  printf '%s\n' '-not -path ./.git/* -not -path ./archives/* -not -path */node_modules/* -not -path */vendor/* -not -path */.venv/* -not -path */venv/* -not -path */dist/* -not -path */build/* -not -path */target/* -not -path */.next/* -not -path */__pycache__/* -not -path */.cache/*'
  return 0
}

sous_modules() {
  local r
  r="$(_ctx_racine)"
  if [ -f "$r/.gitmodules" ]; then
    sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' "$r/.gitmodules" | sed 's/[[:space:]]*$//'
  fi
  return 0
}

version_scripts() {
  local v
  v="$(conv_version)"
  case "$v" in ''|*[!0-9]*) return 0 ;; esac
  if [ "$v" -gt "$CTX_VERSION" ]; then
    printf 'Le bloc contexte:convention est en version %s, ces scripts ne connaissent que la %s.\n' \
      "$v" "$CTX_VERSION" >&2
    printf 'Mets a jour le plugin clawd-stack avant de relancer.\n' >&2
    return 1
  fi
  return 0
}

ctx_aujourdhui() {
  printf '%s\n' "${CTX_AUJOURDHUI:-$(date +%Y-%m-%d)}"
  return 0
}

# date -j -f d'abord : le date BSD de macOS prend -d pour autre chose et peut rendre
# l'heure courante avec un code 0. Sur GNU, -j echoue proprement et -d prend le relais.
ctx_epoch() { # <AAAA-MM-JJ>
  date -j -f '%Y-%m-%d' "${1:-}" +%s 2>/dev/null || date -d "${1:-}" +%s 2>/dev/null || true
  return 0
}

ctx_jours_depuis() { # <AAAA-MM-JJ>
  local a b
  a="$(ctx_epoch "$(ctx_aujourdhui)")"
  b="$(ctx_epoch "${1:-}")"
  if [ -n "$a" ] && [ -n "$b" ]; then
    printf '%s\n' $(( (a - b + 43200) / 86400 ))
  fi
  return 0
}
