#!/usr/bin/env zsh

# —— up() ——————————————————————————————————————————————————————————————————— #

up() {
  local -r _default_cmd='pretty'
  local -r command="${1:-$_default_cmd}"
  local -r error=$'up: \e[31mUnknown command:\e[0m '"'$command'"
  if (( $# )) shift

  typeset -g _UPTIME_OUTPUT
  _UPTIME_OUTPUT="$( uptime )" || return 2

  up::parse || { echo "$_UPTIME_OUTPUT"; return 1; }

  case "$command" {
    -o | print )
      local -r arg1="$1"
      if (( $# )) shift
      case "$arg1" {
        -p | pretty         ) up::print_pretty              ;;
        -v | verbose        ) up::print_pretty --do-verbose ;;
        -l | long           ) up::print_pretty --do-long    ;;
        -r | raw            ) up::print_raw                 ;;
        -a | absolute       ) up::print_absolute "$@"       ;;
        -m | mins | minutes ) up::print_absolute --minutes  ;;
        -s | secs | seconds ) up::print_absolute --seconds  ;;
        *                   ) up::print_pretty "$arg1" "$@" ;;
      }
    ;;

    -p | pretty         ) up::print_pretty   "$@"     ;;
    -v | verbose        ) up::print_pretty   -v       ;;
    -l | long           ) up::print_pretty   -l       ;;
    -r | raw            ) up::print_raw      "$@"     ;;
    -a | absolute       ) up::print_absolute "$@"     ;;
    -m | mins | minutes ) up::print_absolute -m       ;;
    -s | secs | seconds ) up::print_absolute -s       ;;
    -x | parse          ) up::parse                   ;;
    -t | time           ) echo "$_UPTIME_OUTPUT"      ;;
    *                   ) echo "$error" >&2; return 1 ;;
  }

}

# —— up::parse() ———————————————————————————————————————————————————————————— #

up::parse() {

  local _parser_regex="
    # start
    ^

    #  (     1       ) current time
    \s?(\d{1,2}:\d{2})

    \s+  up  \s+

    #  ( 2 ) days up
    (?:(\d+)\s+days?,\s+)?
    (?:
      #(  3   ) mins up [1]
      (\d{1,2})\s+mins?
      |
      #(  4   ) hours up
      (\d{1,2})
      (?:
        #(  5  ) mins up [2]
        :(\d{2})
        |
        \s+hrs?
      )?

    )?
    ,\s+

    #(6 ) active users
    (\d+)\s+users?
    ,\s+

    #¬   ( 7, 8, 9 )  1, 5, & 15 min load averages
    load\saverages:
      \s+(\d+.\d{2})
      \s+(\d+.\d{2})
      \s+(\d+.\d{2})

    # end
    \s*$
  "

  local -r NL=$'\n'

  # compile raw regex
  _parser_regex="${_parser_regex// }"             # remove all spaces
  _parser_regex="${(S)_parser_regex//$NL\#*$NL}"  # remove all comments
  _parser_regex="${_parser_regex//[[:space:]]}"   # remove all newlines

  local -ri 2 do_long=0
  if [[ "$1" == (-(-do-long|l)) ]] do_long=1 && shift

  # just try and match the uptime string
  # we don't care about what the result of the [[ ... ]] is,
  #  we just care about the content of the capturing groups
  setopt rematch_pcre
  if ! [[ "$_UPTIME_OUTPUT" =~ "$_parser_regex" ]] return 1

  local -A output=(
    [time]="$match[1]"                    # current time
    [days]="${match[2]:-0}"               # days  up
   [hours]="${match[4]:-0}"               # hours up
    [mins]="${match[5]:-${match[3]:-0}}"  # mins  up
   [users]="$match[6]"                    # users on system
    [1mla]="$match[7]"                    # 1  min load average
    [5mla]="$match[8]"                    # 5  min load average
   [15mla]="$match[9]"                    # 15 min load average
  )

  # strip the leading 0 from the days, hours and mins
  local key; for key (days hours mins) output[$key]="${output[$key]/#0#}"

  typeset -gA _PARSED_UP=( "${(@kv)output}" )
}

# —— up::print_pretty() ————————————————————————————————————————————————————— #

up::print_pretty() {

  local -r  _long_time_format='%H:%M, %a %d %b %Y'
  local -r _short_time_format='%H:%M, %a %-d'

  if [[ -z "$_PARSED_UP" ]] up::parse

  local -r  days="${_PARSED_UP[days]}"
  local -r hours="${_PARSED_UP[hours]}"
  local -r  mins="${_PARSED_UP[mins]}"

  local  days_suffix='day'
  local hours_suffix='hour'
  local  mins_suffix='minute'

  if ((  days != 1 ))  days_suffix+='s'
  if (( hours != 1 )) hours_suffix+='s'
  if ((  mins != 1 ))  mins_suffix+='s'

  local -a output_arr=()

  if ((  days != 0 )) output_arr+="$days $days_suffix"
  if (( hours != 0 )) output_arr+="$hours $hours_suffix"
  if ((  mins != 0 )) output_arr+="$mins $mins_suffix"

  local -r output="${(j:, :)output_arr}"

  local -ri 10 secs_up="$( up::print_absolute --secs )"
  local -ri 10 up_since=$(( EPOCHSECONDS - secs_up ))

  if ! [[ "$1" =~ '^(-l|--do-long)$' ]] {
    echo "$output ( since ~$( date -r "$up_since" "+$_short_time_format" ) )"
    return 0
  }

  echo "total uptime    : $output\n"

  echo "current time    : $( date "+$_long_time_format" )"
  echo "up since        : $( date -r "$up_since" "+$_long_time_format" )\n"

  echo "active users    : ${_PARSED_UP[users]}\n"

  echo "1  min load avg : ${_PARSED_UP[1mla]}"
  echo "5  min load avg : ${_PARSED_UP[5mla]}"
  echo "15 min load avg : ${_PARSED_UP[15mla]}"

}

# —— up::print_raw() ———————————————————————————————————————————————————————— #

up::print_raw() {
  if [[ -z "$_PARSED_UP" ]] up::parse

  local -r  days="${(l:2::0:)_PARSED_UP[days]}"
  local -r hours="${(l:2::0:)_PARSED_UP[hours]}"
  local -r  mins="${(l:2::0:)_PARSED_UP[mins]}"

  echo "$days:$hours:$mins"
}

# —— up::print_absolute() ——————————————————————————————————————————————————— #

up::print_absolute() {
  if [[ -z "$_PARSED_UP" ]] up::parse

  local -r  days="${_PARSED_UP[days]}"
  local -r hours="${_PARSED_UP[hours]}"
  local -r  mins="${_PARSED_UP[mins]}"

  local -ri 10 mins_abs=$(( 60 * ( 24 * days + hours ) + mins ))
  local -ri 10 secs_abs=$(( 60 * mins_abs ))

  if [[ "$1" =~ '^(-m|--min(ute)?s)$' ]] { echo $mins_abs; return 0; }
  if [[ "$1" =~ '^(-s|--sec(ond)?s)$' ]] { echo $secs_abs; return 0; }

  echo "$mins_abs minutes = $secs_abs seconds"
}

# ——————————————————————————————————————————————————————————————————————————— #
