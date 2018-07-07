proc timediff {time newzone} {
	set localzone [lindex [split [clock format [unixtime]]] end-1]
	set diff [expr {[clock scan "19:00 $localzone"] - [clock scan "19:00 $newzone"]}]
	set result [string map [list $localzone $newzone] [clock format [expr {[clock scan "$time"] + $diff}]]]
	return $result
}
