#!/usr/bin/env bash
#
# 

if (( $# < 1 )); then
cat <<EOF >&2
USAGE: $0 [--field <fieldname>] <value>* [--vals-from <filename>]
  --field: <fieldname> causes delete queries to be generated against
      the specified field name for all values specified in --vals-from,
      and for all <value>s specified on command line *after* a given
      --field declaration. Default if no --field specified is to 
      delete by solr schema uniqueKey field.
  <value>s may be specified directly on command line, and are evaluated
      against the closest preceding <fieldname> declared with the
      --field flag on the command line (solr uniqueKey by default)
  --vals-from <filename> contains the newline-separated values to
      be deleted. Last --field specified on command line determines
      which fieldname values are evaluated against. If no --field is 
      defined on command line, values are used to delete by uniqueKey
      <filename> of "-" reads values from stdin.

  SOLR_URL environment variable must be specified, e.g.:
      SOLR_URL="http://solr:8983/solr/collection_name" ./delete_by_id.sh <some_id>
EOF
exit 1
fi

delete_ids_xml="<delete>"

field="" # defaults to uniqueKey id
delete_q_string=""
boolean_or=""

append_delete_q() {
  if [ -n "$delete_q_string" ]; then
    if [ -n "$field" ]; then
      delete_ids_xml+="<query>$field:($delete_q_string)</query>"
    else
      delete_ids_xml+="<id>$delete_q_string</id>"
    fi
    delete_q_string=""
  fi
}

delete_from() {
  if [ -n "$vals_from" ]; then
    if [ -n "$field" ]; then
      delete_from_f "<query>$field:(" " OR " ")</query>"
    else
      delete_from_f "<id>" "</id><id>" "</id>"
    fi
  fi
}

delete_from_f() {
  prefix="$1"
  infix="$2"
  postfix="$3"
  while read i; do
    echo -n "$prefix$i"
    prefix="$infix"
  done < <(cat "$vals_from")
  if [ "$prefix" = "$infix" ]; then
    echo -n "$postfix"
  fi
}

while (( $# > 0 )); do
  case "$1" in
    --vals-from)
      vals_from="$2"
      shift 2
      ;;
    --field)
      append_delete_q
      boolean_or=""
      field="$2"
      shift 2
      ;;
    --id)
      append_delete_q
      boolean_or=""
      field=""
      shift
      ;;
    *)
      delete_q_string+="$boolean_or$1"
      if [ -z "$boolean_or" ]; then
        if [ -z "$field" ]; then
          boolean_or="</id><id>"
        else
          boolean_or=" OR "
        fi
      fi
      shift
      ;;
  esac
done

append_delete_q

cat <(echo -n "$delete_ids_xml") <(delete_from) <(echo "</delete>") | \
curl "$SOLR_URL/update?commit=true" --data-binary '@-' -H 'Content-type:text/xml; charset=utf-8'
