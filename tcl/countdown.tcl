setudef flag countdown

bind pubm - !*

set countdowns {
"!got5|Apr 12 21:00:00 EST 2015|Season Five of Games of Thrones is in %until!"
"!420|Apr 12 16:20:00 EST 2015|You can experience 4/20 @ 4:20 in exactly %until!"
}

proc proc:countdown {n u h c t} {
  global countdowns
  if {![channel get $c countdown]} { return 1 }
  if {[set pos [lsearch -glob $countdowns $t*]] != -1} {
    foreach {trigger time display} [split [lindex $countdowns $pos]] { break }
    set ago [expr {[clock scan $time] - [clock scan [clock format [clock seconds]]] - ($t*3600)}]] 
    putserv "privmsg $c :[string map [list %until "$ago"] $display]"
  }
}

