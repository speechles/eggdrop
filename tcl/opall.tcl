bind dcc - opall opall

proc opall {handle idx text} {
	set opped_in [list]
	foreach chan [channels] {
		if {[matchattr $handle mno|mno $chan]} {
			if {[botisop $chan]} {
				if {[lsearch [chanlist $chan] [hand2nick $handle]] != -1} {
					if {![isop [hand2nick $handle] $chan]} {
						putserv "MODE $chan +o [hand2nick $handle]" -next
						lappend opped_in $chan
					}
				}
			}
		}
	}
	if {[string length $opped_in]} {
		putidx $idx "You have been opped in [join $opped_in ", "]"
	} else {
		putidx $idx "You have not been opped in any channels."
	}
}
