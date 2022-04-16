#! /bin/sh

psql -h 127.0.0.1 -U bbs ctf -c "COPY (SELECT team_id, key, key_type FROM ssh_keys) TO stdout;" |  \
    awk '{print "command=\"/unctfd -f /conn-file.txt -p " $1 "\" " $3 " "  $2 " imported"}' >    \
    $HOME/.ssh/authorized_keys
