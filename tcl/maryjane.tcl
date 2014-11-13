bind time - "20 04*" syncupman
bind time - "20 16*" syncupman

set antiflood "15"
set packwait "60"
set toplimit "121"

setudef flag fourtwenty

proc syncupman {args} { putserv "PRIVMSG #maryjane :\002\00309\\|/\\|/\\|/ \00310\002IT'S \00304\0374:20!\037\00310 Hit that shit, pass that shit\002!\002" }

bind pub - !menu pub_menu
proc pub_menu {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	putserv "PRIVMSG $c :\00309\002!redbull\002, \002!pizza\002, \002!bong\002, \002!sex\002, \002!pack"; return 0
}

bind pub - !sex suckadick
proc suckadick {n u h c t} {
	switch -- [rand 5] {
		1 { putserv "privmsg $c :\001ACTION watches $n wrap their lips around [lindex [chanlist $c] [rand [llength [chanlist $c]]]]'s cock and suck and slurp and lick...\001" }
		2 { putserv "privmsg $c :\002BREAKING NEWS\002: [lindex [chanlist $c] [rand [llength [chanlist $c]]]] needs to /msg $n (the cocksucker) in the next 15 minutes for virtual cock suck!" }
		3 { putserv "privmsg $c :$n, NO COCK FOR YOU! Try eating pussy instead. MEOW! Here kitty kitty." }
		4 { putserv "privmsg $c :\001ACTION shoves his cock down $n's throat! Who is next? Type !gag_$n.\001" }
		default { putserv "privmsg $c :$n, there is fucking nobody wants their cock anywhere near the vicinity of you or your lips. Try again." }
	}
}

bind pub - !pizza pub_pizza
proc pub_pizza {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - !pizza pub_pizza
	putserv "PRIVMSG $c :\001ACTION \00309gives \00310$n\00309 a \00304\037hot\037\00309 slice of cheese pizza. \00310\002YUM!";
	utimer $::antiflood "bind pub - !pizza pub_pizza"
}

bind pub - !redbull pub_redbull
proc pub_redbull {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - !redbull pub_redbull
	putserv "PRIVMSG $c :\001ACTION \00309looks @ \00310$n \0039I'm sure you need some energy be ready here it comes. by grabs *grabs a can of REDBULL and tosses it to \00310$n\00309 slides down to $n some ice in a glass enjoy!!! :)\001";
	utimer $::antiflood "bind pub - !redbull pub_redbull"
}

bind pub - !bong pub_burger
proc pub_burger {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - !bong pub_burger;
	if {![string length [set v [lindex $a 0]]]} { set v $n ; set n $::botnick }
	putserv "PRIVMSG $c :\00310$n\00309 passes the bong to \00310$v\00309, hit that shit an pass bitch!";
	utimer $::antiflood "bind pub - !bong pub_burger"
}

bind pub - !pack pub:sack
proc pub:sack {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
      set mins 0 ; set secs 0
	regexp -- {([0-9]+)m} $a - mins
	regexp -- {([0-9]+)s} $a - secs
	if {$mins == 0 && $secs == 0} { set secs $::packwait }
	if {($mins > 0 || $secs > 0 ) && [expr {$mins*60+$secs}] < $::toplimit} {
		unbind pub - !pack pub:sack
		putserv "PRIVMSG $c :\00309\\|/\\|/ \00310\002listen up\00309... public announcement\002: Grind your weed, get your weed, pack your weed, just be ready for a chan wide toke-out in \00310[duration [expr {$mins*60+$secs}]]\00309. \\|/\\|/"
		utimer [expr {$mins*60+$secs}] [list pub:sync $n $u $h $c $a]
	} else {
		putserv "PRIVMSG $c :\00310listen up\00309... pack correctly.. don't \00304\037abuse\037\00309 the command.. or else.. haw"
	}
}

#bind pub - !sync pub:sync
proc pub:sync {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	bind pub - !pack pub:sack
	utimer 1 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/ \00310Ladies & Gents, get your \00309\037BOWLS\037\00310 \002READY\002! \00309\\|/\\|/\\|/"]
	utimer 2 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\\|/\\|/ \002\003105\002\00309 \\|/\\|/\\|/\\|/\\|/"]
	utimer 3 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\\|/\002\003104\002\00309 \\|/\\|/\\|/\\|/"]
	utimer 4 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\002\003103\002\00309 \\|/\\|/\\|/"]
	utimer 5 [list putserv "PRIVMSG $c :\00309\\|/\\|/\002\003102\002\00309 \\|/\\|/"]
	utimer 6 [list putserv "PRIVMSG $c :\00309\\|/\002\003101\002\00309 \\|/"]
	utimer 8 [list putserv "PRIVMSG $c :\002\00309\037SYNCHRONIZED!\037 \\|/\\|/\\|/ \00310FIRE UP YOUR \037BOWLS\037!! \00309\\|/\\|/\\|/"]
	#utimer $::antiflood "bind pub - !sync pub:sync"
}


putlog "maryjane-v2.0 black@blackmajic: loaded."


