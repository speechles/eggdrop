# lastspoke_evolved.tcl v0.2
#
# An eggdrop script to keep track of when people last spoke;
# Tracks users who have left or parted channel as well as
# those currently in channel.
#
# USE: "-totals" to check usage of memory consumption and size
# of array used to track spoke data
#
# Master/Owner: Use !spokeclean or !cleanspoke to prune your
# spoke data down to just active users presently in channels.
#
# ----
# Originally by Pistos
# irc.freenode.net #geoshell
#
# SPECIAL NOTE, DONT MISS THIS OR YOU MAY GET PISSED OFF
# TO KEEP YOUR CHANNEL SECRET:
# .chanset #yourchan +spokesecret
#
# Otherwise, everything said by everyone will be logged. With
# the channel set SECRET only the last time said is kept, what
# was said is replaced with a message indicating it's a secret.
# ----
# Evolved by speechles
# irc.efnet.net #roms-isos

setudef flag spokesecret
 
bind pubm - * spoke_pubm
bind pub - !spoke spoke_query
bind pub - !last spoke_query
bind pub - !lastspoke spoke_query
bind pub mn|mn !spokeclean spoke_invoke_cleanup
bind pub mn|mn !cleanspoke spoke_invoke_cleanup

if {![info exists spoke_start]} {
    set spoke_start [clock seconds]
}

proc spoke_pubm {nick uhost handle channel arg} {
    global spoke_time spoke_text
    set spoke_time($nick) [clock seconds]
    if {[channel get $channel spokesecret]} {
      set spoke_text($nick) "SECRET $channel $arg"
    } else {
      set spoke_text($nick) $arg
    }
}

proc spoke_timestr {seconds_since} {
    set minutes_since 0
    set hours_since 0
    set days_since 0
    if {$seconds_since > 59} {
	set minutes_since [expr $seconds_since / 60]
	set seconds_since [expr $seconds_since % 60]
	if {$minutes_since > 59} {
	    set hours_since [expr $minutes_since / 60]
	    set minutes_since [expr $minutes_since % 60]
	    if {$hours_since > 23} {
		set days_since [expr $hours_since / 24]
		set hours_since [expr $hours_since % 24]
	    }
	}
    }
    
    set msg ""
    if {$days_since > 0} {
	set plural ""
	if {$days_since != 1} { set plural "s" }
	append msg "$days_since day$plural, "
    }
    if {$hours_since > 0} {
	set plural ""
	if {$hours_since != 1} { set plural "s" }
	append msg "$hours_since hour$plural, "
    }
    if {$minutes_since > 0} {
	set plural ""
	if {$minutes_since != 1} { set plural "s" }
	append msg "$minutes_since minute$plural, "
    }
    set plural ""
    if {$seconds_since != 1} { set plural "s" }
    append msg "$seconds_since second$plural"

    return $msg
}

proc spoke_query {nick uhost handle channel arg {re 0}} {
    global spoke_time spoke_text spoke_start
    if {![string length [set arg [string trim $arg]]]} { set arg [lindex [lsort -decreasing [array names spoke_time]] 0] }
    if {$re == 0 } { spoke_pubm $nick $uhost $handle $channel "${::lastbind} $arg" }

    if {[string match "$arg" "-totals"]} {
      set sz 0 ; set on_sz 0 ; set nicks_on 0
      foreach s [array names spoke_time] {
         set found 0
         foreach c [channels] {
           if {[lsearch -exact [chanlist $c] $s] != -1} {
             incr nicks_on
             incr on_sz [expr {[string bytelength $spoke_text($s)] + [string bytelength $spoke_time($s)]}]
             set found 1
             break
           }
         }
         if {$found == 0} {
           incr sz [expr {[string bytelength $spoke_text($s)] + [string bytelength $spoke_time($s)]}]
         }
      }
      putserv "privmsg $channel :I am presently tracking \002[array size spoke_text]\002 nicknames (\002$nicks_on\002 of them active) using approximately \002[format_1024_units [expr {$sz + $on_sz}]]\002 (\002[format_1024_units $on_sz]\002 is active) of memory for \002[spoke_timestr [expr [clock seconds] - $spoke_start]]\002."
      return
    }
    set speaker $arg
    if {[string equal "$arg" "$::botnick"]} {
      putserv "privmsg $channel :0 seconds ago, I said: '$nick, give it a rest... I'm sleeping :P'."
      return
    }
    
    if { ![info exists spoke_time($speaker)]} {
	set msg "As far as I know, $speaker hasn't said anything"
      if {$re == 1} { append msg " either." } { append msg "." }

	# Search for possible case-insensitive matches in channel.

	set intended ""
	set members [chanlist $channel]
	foreach member $members {
	    if {[string equal -nocase $member $speaker] && ![string equal $member $speaker]} {
		set intended $member
		set speaker $member
		append msg "  But if you meant $speaker, then:"
		break
	    }
	}

      # Search for leeted up (31337) matches in channel.

      if {$intended == ""} {
	  foreach member $members {
	    if {([string equal -nocase $member [string map {1 l 2 z 3 e 4 a 5 s 6 g 7 t 9 g 0 o} $speaker]] || [string equal -nocase [string map {1 l 2 z 3 e 4 a 5 s 6 g 7 t 9 g 0 o} $member] $speaker]) && ![string equal $member $speaker]} {
		set intended $member
		set speaker $member
		append msg "  But if you meant $speaker, then:"
		break
	    }
        }
	}

      # Search for possible case-insensitive matches who have part/quit 

      if {$intended == ""} {
        foreach s [array names spoke_time] {
            if {[string equal -nocase $s $speaker] && ![string equal $s $speaker]} {
 		  set intended $s
		  set speaker $s
		  append msg "  But if you meant $speaker, who by the way isn't present on $channel, then:"
		  break
	      }
         }
      }

      # Search for leeted up (31337) matches who have part or quit.

      if {$intended == ""} {
        foreach s [array names spoke_time] {
	    if {([string equal -nocase $s [string map {1 l 2 z 3 e 4 a 5 s 6 g 7 t 9 g 0 o} $speaker]] || [string equal -nocase [string map {1 l 2 z 3 e 4 a 5 s 6 g 7 t 9 g 0 o} $s] $speaker]) && ![string equal $s $speaker]} {
		set intended $s
		set speaker $s
		append msg "  But if you meant $speaker, who by the way isn't present on $channel, then:"
		break
	    }
        }
	}

	putserv "PRIVMSG $channel :$msg"

	if {$intended == ""} {
            set msg [spoke_timestr [expr [clock seconds] - $spoke_start]]
            putserv "PRIVMSG $channel :I've been watching for $msg."
	    return
	}

	spoke_query $nick $uhost $handle $channel $speaker 1
	return
    }
    
    set seconds_since [expr [clock seconds] - $spoke_time($speaker)]
    set msg [spoke_timestr $seconds_since]
    if {[string equal "SECRET" [lindex [split $spoke_text($speaker)] 0]]} {
      if {[string equal -nocase $channel [lindex [split $spoke_text($speaker)] 1]]} {
        if {[string equal -nocase $nick $speaker]} {
          set m "PRIVMSG $channel :$msg ago, you said '[join [lrange [split $spoke_text($speaker)] 2 end]]\017'."
        } else {
          set m "PRIVMSG $channel :$msg ago, $speaker said '[join [lrange [split $spoke_text($speaker)] 2 end]]\017'."
        }
      } else {
        set m "PRIVMSG $channel :$msg ago, $speaker said a secret. I can't tell you here. :P"
      }
    } else {
      if {[string equal -nocase $nick $speaker]} {
        set m "PRIVMSG $channel :$msg ago, you said '$spoke_text($speaker)\017'."
      } else {
        set m "PRIVMSG $channel :$msg ago, $speaker said '$spoke_text($speaker)\017'."
      }
    }
    set flag 0
    foreach c [channels] {
      if {[lsearch -exact [chanlist $c] $speaker] != -1} { set flag 1 ; break }
    }
    if {$flag == 0} {
      append m " $speaker is not on any channels I monitor at this time."
    } elseif {$re == 0 && ![onchan $speaker $channel]} {
      append m " $speaker is not present on $channel."
    }
    putserv "$m"
}

proc spoke_invoke_cleanup {nick uhost handle channel arg} {
    spoke_cleanup
}

# Removes entries of people that are not present in the channel.
proc spoke_cleanup {} {
    global spoke_time spoke_text

    putlog "Cleaning up Last Spoke data..."

    set channel_list [channels]
    set nicks ""
    foreach channel $channel_list {
	set nicks [concat $nicks [chanlist $channel]]
    }

    set num_left 0 ; set num_purged 0
    foreach nick [array names spoke_time] {
	if {[lsearch $nicks $nick] == -1} {
	    unset spoke_time($nick)
	    unset spoke_text($nick)
	    putlog "Purged $nick."
          incr num_purged
	} else {
	    incr num_left
	}
    }

    putlog "$num_left nick(s) still in memory, purged $num_purged nicks no longer present."
}

proc format_1024_units {value} { 
	set test $value ; set unit 0
	while {[set test [expr {$test / 1024}]] > 0} {
		incr unit
	}
	return [format "%.1f %s" [expr {$value / pow(1024,$unit)}] [lindex [list B KB MB GB TB PB EB ZB YB] $unit]]
}


putlog "Last Spoke tracker by Pistos (evolved by speechles) -- loaded"
