# noter v1.1 - april 14, 2015
# by speechles
#
# This extends the regular eggdrop notes module and lets you use it in your channels
# on irc. It will announce new notes to users known by the bot on join. It will
# intelligently know if you have notes given by which channel and sort them
# accordingly as well as know them from notes sent via partyline.
#
# egghelp version
# (c)opyleft 2015


bind pub - .notes notes::total
bind pub - .list notes::list
bind pub - .erase notes::erase
bind pub - .note notes::store
bind join - * notes::joins

setudef flag usenotes

namespace eval notes {
	proc total {n u h c t} {
		if {![channel get $c usenotes]} { return }
		set total [listnotes $h -]
		switch -- $total {
			-1 { putserv "privmsg $c :$n, you are not yet known by the bot. Therefore you have no notes. Simple as that." }
			-2 { putserv "privmsg $c :$n, fatal NoteFile Error.. Please report to $::owner immediately!" }
			0  { putserv "privmsg $c :$n, you have no notes." }
			default  { putserv "privmsg $c :[totalmessage $n $c $h $total]" }
		}
	}
	
	proc totalmessage {n c h total} {
		set out "$n, you have [llength $total] notes total"
		if {[set in [getcount $c $h $total]] > 0} { append out ". $in of them in $c" }
		if {[llength $total]} { append out ". Use .list to view them" }
            if {$total != $in && $in != 0} {
			append out ", or .list * to see all [llength $total]"
		}
		return "$out."
	}


      proc joins {n u h c} {
		set total [listnotes $h -]
		set in [getcount $c $h $total]
		if {[llength $total] && $in > 0 } {
			putserv "notice $n :[totalmessage $n $c $h $total]"
		}
	}

      proc getcount {c h total} {
            set count 0
		foreach row $total {
			foreach {from timestamp text} [lindex [notes $h $row] 0] { break }
			if {[string match $c* $text]} { incr count }
		}
            return $count
	}
			
	proc list {n u h c t} {
		if {![channel get $c usenotes]} { return }
		if {![string length [string trim $t]]} { set t "-" }
            if {[string equal $t *]} { set all 1 ; set t "-" }
		set total [listnotes $h $t]
		switch -- $total {
			-1 { putserv "privmsg $c :$n, you are not yet known by the bot. Therefore you have no notes. Simple as that." }
			-2 { putserv "privmsg $c :$n, fatal NoteFile Error.. Please report to $::owner immediately!" }
			0  { putserv "privmsg $c :$n, you have no notes. ( $t )" }
			default {
				if {[llength $total] < 1} {
					putserv "privmsg $c :$n, You have no notes to list."
					return
				}
				foreach row $total {
					foreach {from timestamp text} [lindex [notes $h $row] 0] { break }
                              switch -- [info exists all] {
						1 { show $c $n $row $from $text $timestamp }
                                    default {
							if {[string equal -nocase $c [lindex [split $text] 0]] || ![string equal $t -]} {
							   show $c $n $row $from $text $timestamp
							} 
                                    }
                              }
				}
			}
		}
	}

      proc show {c n row from text timestamp} {
		if {[string match #* $text]} {
			putserv "privmsg $c :$n, ($row) via [lindex [split $text] 0] <$from> [join [lrange [split $text] 1 end]] -- [duration [expr {[clock seconds] - $timestamp }]] ago"
		} else {
			putserv "privmsg $c :$n, ($row) via partyline <$from> $text -- [duration [expr {[clock seconds] - $timestamp }]] ago"
		}
	}

	proc store {n u h c t} {
		if {![channel get $c usenotes]} { return }
		set target [lindex [split $t] 0]
		set note [join [lrange [split $t] 1 end]]
		if {![string length $target]} {
			putserv "privmsg $c :$n, you must give a nickname and note to send. Correct usage: $::lastbind <nickname> <note to send here>"
			return
		}
		if {![string length $note]} {
			putserv "privmsg $c :$n, you must give the note to send, not just the nickname. Correct usage: $::lastbind <nickname> <note to send here>"
			return
		}
		set total [sendnote $h $target "$c $note"]
		switch -- [string trim $total] {
			0  { putserv "privmsg $c :$n, the note to $target has failed." }
			1  { putserv "privmsg $c :$n, the note to $target was delivered locally or sent to another bot." }
			2  { putserv "privmsg $c :$n, the note to $target was stored locally." }
			3  { putserv "privmsg $c :$n, ${target}'s notebox is too full to store a note." }
			4  { putserv "privmsg $c :$n, a Tcl binding caught the note to $target." }
			5  { putserv "privmsg $c :$n, the note to $target was stored because the user is away." }
			default { putserv "privmsg $c :$n, strange error sending note to $target, note failed." }
		}
	}

	proc erase {n u h c t} {
		if {![channel get $c usenotes]} { return }
		if {![string length [string trim $t]]} { set t "-" }
		set total [erasenotes $h $t]
		switch -- $total {
			-1 { putserv "privmsg $c :$n, you are not yet known by the bot. Therefore you have no notes to erase. Simple as that." }
			-2 { putserv "privmsg $c :$n, fatal NoteFile Error.. Please report to $::owner immediately!" }
			0  { putserv "privmsg $c :$n, you have no notes to erase. ( $t )" }
			default { putserv "privmsg $c :$n, erased $total notes. ( $t )" }
		}
	}
}
#eof
