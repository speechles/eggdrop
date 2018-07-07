bind pub - !hex hexIdented
bind join - * hexIdentJoin

setudef flag hex

proc hexIdentJoin {nick uhost hand chan} {
	hexIdented $nick $uhost $hand $chan $nick 1
}

proc hexIdented {nick uhost hand chan text {join 0}} {
	if {![channel get $chan hex]} { return }
	set wnick [lindex [split [getchanhost [lindex [split $text] 0] $chan] @] 0]
	if {[string length $wnick]} { set text $wnick } { set wnick $text }
      set a $text
	if {[string length $a] == 8} {
		while {[string length $a]} {
			set piece [string range $a 0 1]
			set a [string range $a 2 end]
			if {[regexp {^[a-fA-F0-9]+$} $piece]} {
				lappend ip [scan $piece %x]
				if {[llength $ip] == 4} { break }
			} else {
				set flag 1 ; break
			}
		}
		if {![info exists flag]} {
			set ip [join $ip "."]
			putserv "privmsg $chan :\002$nick\002 > Ident:\002$text\002; IP:\002$ip\002"
		} else {
			if {$join < 1} {
				putserv "privmsg $chan :\002$wnick\002 > \"$text\" is not hex based."
			}
		}
	} else {
		if {$join < 1} {
			putserv "privmsg $chan :\002$wnick\002 isn't the amount of characters (8) required to convert to hex ip."
		}
	}
}
