#!/usr/bin/env zsh

() {
  source "${${(%):-%x}:a:h:h}/source/up.zsh"

  local -ra input_strs=(
    '14:42  up 9 days,  2:59, 2 users, load averages: 3.63 3.48 3.25'
    '12:53  up  1:10, 3 users, load averages: 4.79 4.48 4.23'
    '15:03  up 8 mins, 3 users, load averages: 3.51 12.43 10.72'
    '16:44  up 10 days, 19:01, 3 users, load averages: 5.93 4.87 4.42'
    ' 3:13  up 11 days, 15:30, 7 users, load averages: 3.34 3.99 4.39'
    ' 3:13  up 6 days, 44 mins, 7 users, load averages: 3.34 3.99 4.39'
    "$( uptime )"
  )

  local input
  for input in "${(@)input_strs}"; {
    echo "$input"$'\e[31m'

    up --test "$input"

    echo $'\e[0;2m'"${(r:COLUMNS/2::─:)}"$'\e[m'
  }
}
