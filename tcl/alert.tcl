bind pub n !alert pushNicks

proc pushNicks {n u h c t} {
   if {[info exists ::queuedNicks]} {
      putserv "notice $n :$n, there is still a queue of [llength $::queuedNicks] nicknames that need to see the previous message, please wait a bit and I will announce when I am completed." -next
   } else {
      # start at 1 to avoid sending a message to the botnick itself
      set ::queuedNicks [lrange [chanlist $c] 1 end]
      puthelp "privmsg $c :$n, pushing your message to everyone in channel. Please be patient."
      popNicks $t $n $c
   }
}

proc popNicks {t n c} {
   foreach nick [lrange $::queuedNicks 0 4] {
      puthelp "notice $nick :$t (via $n)"
   }
   if {![llength [set ::queuedNicks [lrange $::queuedNicks 5 end]]]} {
      puthelp "privmsg $c :$n, message push completed. Everyone in channel has seen it."
      unset ::queuedNicks
   } else { utimer 20 [list popNicks $t $n $c] }
}
