bind time - "20 04*" syncupman
bind time - "20 16*" syncupman

set antiflood "15"
set packwait "15"
set toplimit "120"

setudef flag fourtwenty

proc syncupman {args} { putserv "PRIVMSG #maryjane :\002\0033\\|/\\|/\\|/ \0039\002ITS 4:20! Hit that shit, pass that shit" }

bind pub - !menu pub_menu
proc pub_menu {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	putserv "PRIVMSG $c :!redbull, !pizza, !bong, !sex, !pack"; return 0
}

bind pub - !pizza pub_pizza
proc pub_pizza {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - !pizza pub_pizza
	putserv "PRIVMSG $c :\00310Gives \0034$n \00310a \0034hot \00310slice of cheese pizza..";
	utimer $::antiflood "bind pub - !pizza pub_pizza"
}

bind pub - !redbull pub_redbull
proc pub_redbull {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - !redbull pub_redbull
	putserv "PRIVMSG $c :\0039looks @ \00310$n \0039I'm sure you need some energy be ready here it comes. by grabs *grabs a can of REDBULL and tosses it to \00310$n slides down to $n some ice in a glass enjoy!!! :)";
	utimer $::antiflood "bind pub - !redbull pub_redbull"
}

bind pub - !bong pub_burger
proc pub_burger {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - !bong pub_burger
	set v [lindex $a 0];
	putserv "PRIVMSG $c :$n passes the bong to $v, hit that shit an pass bitch!";
	utimer $::antiflood "bind pub - !bong pub_burger"
}

bind pub - !pack pub:sack
proc pub:sack {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	regexp -- {([0-9]+)m} $a - mins
	regexp -- {([0-9]+)s} $a - secs
	if {$mins == 0 && $secs == 0} { set secs $::packwait }
	if {($mins > 0 || $secs > 0 ) && [expr {$mins*60+$secs}] < $::toplimit} {
		unbind pub - !pack pub:sack ; set mins 0 ; set secs 0
		putserv "PRIVMSG $c :listen up... public announcement: Grind your weed, get your weed, pack your weed, just be ready for a chan wide toke-out in [duration [expr {$mins*60+$secs}]]."
		utimer [expr {$mins*60+$secs}] [list pub:sync $n $u $h $c $a ; bind pub - !pack pub:sack]
	} else {
		putserv "PRIVMSG $c :listen up... pack correctly.. don't abuse the command.. or else.. haw"
	}
}

#bind pub - !sync pub:sync
proc pub:sync {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	#unbind pub - !sync pub:sync
	utimer 1 "putserv \"PRIVMSG $c :Ladies and Gents, get your bowls ready!\"";
	utimer 2 "putserv \"PRIVMSG $c :5.....\"";
	utimer 3 "putserv \"PRIVMSG $c :4....\"";
	utimer 4 "putserv \"PRIVMSG $c :3...\"";
	utimer 5 "putserv \"PRIVMSG $c :2..\"";
	utimer 6 "putserv \"PRIVMSG $c :1.\"";
	utimer 8 "putserv \"PRIVMSG $c :SYNCHRONIZED! FIRE UP YOUR BOWLS!!\""
	#utimer $::antiflood "bind pub - !sync pub:sync"
}


putlog "maryjane-v2.0 black@blackmajic: loaded."

