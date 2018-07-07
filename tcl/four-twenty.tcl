

# use of the commands are 1 in how many seconds?
set antiflood "15"

# default time to wait if someone just types !pack
set packwait "60"

# what is the maximum time to wait for sync
set toplimit "121"

bind time - "20 04*" syncupman
bind time - "20 16*" syncupman

setudef flag fourtwenty

proc syncupman {args} { putserv "PRIVMSG #maryjane :\002\00309\\|/\\|/\\|/ \00310\002IT'S \00304\0374:20!\037\00310 Hit that shit, pass that shit\002!\002" }

bind pub - .zork dozork
proc dozork {n u h c t} {
	putserv "privmsg $c :\026West of House[string repeat " " 20] 0/0\026"
	putserv "privmsg $c :You are standing in an open field west of a white house, with a boarded front door. There is a small mailbox here."
	set ::zorkn $n
	set ::zorkhost $h
	unbind pub - .zork dozork
	bind pubm - * checkzork
	set ::zorktime [utimer 30 [list checkzork $n $u $h $c $t]]
}

proc checkzork {n u h c t} {
	if {[string equal -nocase $::zorkn $n] && [string equal -nocase $::zorkhost $h]} {
		putserv "privmsg $c :You were eaten by a grue."
	}
  	foreach t [utimers] {
  		if [string match *checkzork* [lindex $t 1]] {
  			killutimer [lindex $t end]
		}
  	}
	unbind pubm - * checkzork
	bind pub - .zork dozork
}
	
bind pub - .sex suckadick
proc suckadick {n u h c t} {
	if {![channel get $c fourtwenty]} { return }
	switch -- [rand 5] {
		1 { putserv "privmsg $c :\001ACTION watches $n wrap their lips around [lindex [chanlist $c] [rand [llength [chanlist $c]]]]'s cock and suck and slurp and lick...\001" }
		2 { putserv "privmsg $c :\002BREAKING NEWS\002: [lindex [chanlist $c] [rand [llength [chanlist $c]]]] needs to /msg $n (the cocksucker) in the next 15 minutes for virtual cock suck!" }
		3 { putserv "privmsg $c :$n, NO COCK FOR YOU! Try eating pussy instead. MEOW! Here kitty kitty." }
		4 {
			bind pub - .gag_$n suckevent
			set ::suckee $n
			putserv "privmsg $c :\001ACTION shoves his cock down $n's throat! Who is next? Type .gag_$n. (you have 2 minutes!)\001"
			utimer 120 [list unbind pub - .gag_$n suckevent]
			
		}
		default { putserv "privmsg $c :$n, there is fucking nobody wants their cock anywhere near the vicinity of you or your lips. Try again." }
	}
}

proc suckevent {n u h c t} {
	putserv "privmsg $c :\001ACTION watches $n saunter over to $::suckee and dropping his cock literally balls deep up to ${::suckee}'s nostrils. \002Well done!\002\001"
}

bind pub - .pizza pub_pizza
proc pub_pizza {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - .pizza pub_pizza
	putserv "PRIVMSG $c :\001ACTION \00309gives \00310$n\00309 a \00304\037hot\037\00309 slice of cheese pizza. \00310\002YUM!";
	utimer $::antiflood "bind pub - .pizza pub_pizza"
}

bind pub - .redbull pub_redbull
proc pub_redbull {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - .redbull pub_redbull
	putserv "PRIVMSG $c :\001ACTION \00309looks @ \00310$n \0039I'm sure you need some energy be ready here it comes. by grabs *grabs a can of REDBULL and tosses it to \00310$n\00309 slides down to $n some ice in a glass enjoy!!! :)\001";
	utimer $::antiflood "bind pub - .redbull pub_redbull"
}

bind pub - .bong pub_burger
proc pub_burger {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - .bong pub_burger;
	if {![string length [set v [lindex $a 0]]]} { set v $n ; set n $::botnick }
	putserv "PRIVMSG $c :\00310$n\00309 passes the bong to \00310$v\00309, hit that shit an pass bitch!";
	utimer $::antiflood "bind pub - .bong pub_burger"
}

bind pub - .pack pub:sack
proc pub:sack {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
      set mins 0 ; set secs 0
	regexp -- {([0-9]+)m} $a - mins
	regexp -- {([0-9]+)s} $a - secs
	if {$mins == 0 && $secs == 0} { set secs $::packwait }
	if {($mins > 0 || $secs > 0 ) && [expr {$mins*60+$secs}] < $::toplimit} {
		unbind pub - .pack pub:sack
		bind pub - .pack pub:sack:wait
		putserv "PRIVMSG $c :\00309\\|/\\|/ \00310\002listen up\00309... public announcement\002: Grind your weed, get your weed, pack your weed, just be ready for a chan wide toke-out in \00310[duration [expr {$mins*60+$secs}]]\00309. \\|/\\|/"
		set ::vpack [utimer [expr {$mins*60+$secs}] [list pub:sync $n $u $h $c $a]]
		set ::vpackn $n
	} else {
		putserv "PRIVMSG $c :\00310listen up\00309... pack correctly.. don't \00304\037abuse\037\00309 the command.. or else.. haw"
	}
}

proc pub:sack:wait {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	if {[set pos [lsearch -glob [utimers] "*$::vpack"]] != -1} {
		foreach {time proc name} [lindex [utimers] $pos] { break } 
		putserv "privmsg $c :\00309\002.pack\002 in use\00310 by \00309$::vpackn\00310. Why don't you just smoke with \00309$::vpackn\00310 in \00309[duration $time]\00310?"
	}
}

bind pub - .roll pub:roll
proc pub:roll {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
      set mins 0 ; set secs 0
	regexp -- {([0-9]+)m} $a - mins
	regexp -- {([0-9]+)s} $a - secs
	if {$mins == 0 && $secs == 0} { set secs $::packwait }
	if {($mins > 0 || $secs > 0 ) && [expr {$mins*60+$secs}] < $::toplimit} {
		unbind pub - .roll pub:roll
		bind pub - .metoo pub:metoo
		#putserv "PRIVMSG $c :\00309\\|/\\|/ \00310\002listen up\00309... public announcement\002: Grind your weed, get your weed, pack your weed, just be ready for a chan wide toke-out in \00310[duration [expr {$mins*60+$secs}]]\00309. \\|/\\|/"
		putserv "PRIVMSG $c :\00309\\|/\\|/ \00310\002listen up\00309... public announcement\002: $n wants to smoke a fat joint! Anybody else want to, type .metoo in the next \00310[duration [expr {$mins*60+$secs}]]\00309. \\|/\\|/"
		set ::vpacks [utimer [expr {$mins*60+$secs}] [list pub:blaze $n $u $h $c $a]]
		set ::vpackj [list $n]
	} else {
		putserv "PRIVMSG $c :\00310listen up\00309... pack correctly.. don't \00304\037abuse\037\00309 the command.. or else.. haw"
	}
}

proc pub:metoo {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	if {[set pos [lsearch $::vpackj $n]] != -1} {
		putserv "privmsg $c :\00309$n, too stoned? You are already in on the joint bro, in spot #[incr pos]." ; return
	}
	if {[set pos [lsearch -glob [utimers] "*$::vpacks"]] != -1} {
		foreach {time proc name} [lindex [utimers] $pos] { break } 
		putserv "privmsg $c :\00309\002$n, welcome to the session along with \00309[join $::vpackj ", "]\00310. Anyone else? There is \00309[duration $time]\00310 left til we light up."
		lappend ::vpackj $n
	}
}

proc pub:sync {n u h c a} {
	if {![channel get $c fourtwenty]} { return }
	unbind pub - .pack pub:sack:wait
	bind pub - .pack pub:sack
	utimer 1 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/ \00310Ladies & Gents, get your \00309\037bowls\037\00304 \002READY\002! \00309\\|/\\|/\\|/"]
	utimer 2 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\\|/\\|/ \002\003105\002\00309 \\|/\\|/\\|/\\|/\\|/"]
	utimer 3 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\\|/\002\003104\002\00309 \\|/\\|/\\|/\\|/"]
	utimer 4 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\002\003103\002\00309 \\|/\\|/\\|/"]
	utimer 5 [list putserv "PRIVMSG $c :\00309\\|/\\|/\002\003102\002\00309 \\|/\\|/"]
	utimer 6 [list putserv "PRIVMSG $c :\00309\\|/\002\003101\002\00309 \\|/"]
	utimer 8 [list putserv "PRIVMSG $c :\002\00309\037SYNCHRONIZED!\037 \\|/\\|/\\|/ \00310FIRE UP YOUR \037BOWLS\037!! \00309\\|/\\|/\\|/"]
	#utimer $::antiflood "bind pub - !sync pub:sync"
}

proc pub:blaze {n u h c a} {
      unbind pub - .metoo pub:metoo
	bind pub - .roll pub:roll
	if {![channel get $c fourtwenty]} { return }
	utimer 1 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/ \00310[join $::vpackj ", "]\00309\\|/\\|/\\|/"]
	utimer 2 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\\|/\\|/ I am lighting the joint \\|/\\|/\\|/\\|/\\|/"]
	utimer 3 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/\\|/ \002\00310Enjoy your flight\002\00309 \\|/\\|/\\|/\\|/"]
	#utimer 4 [list putserv "PRIVMSG $c :\00309\\|/\\|/\\|/ \002\003103\002\00309 \\|/\\|/\\|/"]
	#utimer 5 [list putserv "PRIVMSG $c :\00309\\|/\\|/ \002\003102\002\00309 \\|/\\|/"]
	#utimer 6 [list putserv "PRIVMSG $c :\00309\\|/ \002\003101\002\00309 \\|/"]
	#utimer 8 [list putserv "PRIVMSG $c :\002\00309\037SYNCHRONIZED!\037 \\|/\\|/\\|/ \00310FIRE UP YOUR \037BOWLS\037!! \00309\\|/\\|/\\|/"]
	#utimer $::antiflood "bind pub - !sync pub:sync"
}


putlog "maryjane-v2.0 black@blackmajic: loaded."




