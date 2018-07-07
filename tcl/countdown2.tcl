setudef flag countdown2

bind pubm - "% !*" proc:countdown2

set countdowns {
"!420|Apr 20 16:20:00 EST 2016|You can experience 4/20 @ 4:20 in exactly %until!"
"!tomorrow|tomorrow|Tomorrow is in %until!"
"!mrrobot|Jul 1 10:00:00 EST 2015|Episode 2 of Mr. Robot can be watched in %until!"
"!rickmorty|Jul 26 10:30:00 EST 2015|Rick and Morty Season 2 is only %until away!"
}

proc proc:countdown2 {n u h c t} {
  global countdowns
  if {![channel get $c countdown2] || $t == "!" } { return 1 }
  if {[set pos [lsearch -glob $countdowns [string tolower $t]*]] != -1} {
    foreach {trigger time} [split [lindex $countdowns $pos] |] { set display [join [lrange [split [lindex $countdowns $pos] |] 2 end]] ; break}
    set myzone [clock format [clock seconds] -format %Z] 
    set zone [lindex [split $time] 3]
    set diff [expr {[clock scan "Apr 20 00:00:00 $zone 2015"] - [clock scan "Apr 20 00:00:00 $myzone 2015"]}]
    set ago [duration [string map [list - ""] [expr {[clock scan $time] - [clock seconds] + $diff}]]]
    putserv "privmsg $c :[string map [list %until "$ago"] $display]"
  }
}


