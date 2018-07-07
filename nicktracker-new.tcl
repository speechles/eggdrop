
# Nickname/Uhost tracker script
# Egghelp version, donations to slennox are welcomed. :P

# should duplicate nicknames be allowed?
# 0 = no, 1 and above = yes
set dupes 0

#your filename
set filename "nicklist.txt"

#your nicks to alert use spaces to seperate
set alertnicks "me you others"

bind nick - * nick_nickchange
bind join - * join_onjoin

setudef flag nicktrack

# make sure the file exists before we go to read it
# this initializes the file if it doesn't already exist
# and makes it blank to start with.
if {![file exists $filename]} {
   set file [open $filename "w"]
   close $file
}

# check for nick changes
proc nick_nickchange {nick uhost hand chan newnick} {
   if {![channel get $chan "nicktrack"]} {  return 0  }
   join_onjoin $newnick $uhost $hand $chan
   return 0
}

# check for joins
proc join_onjoin {nick uhost hand chan} {
   global filename dupes
   if {![channel get $chan "nicktrack"]} {  return 0  }
   # keep everything lowercase for simplicity.
   set nick [string tolower $nick]
   set uhost [string tolower $uhost]
   # read the file
   set file [open $filename "r"]
   set text [split [read $file] \n]
   close $file
   # locate a duplicate host
   set found [lsearch -glob $text "*<$uhost"]
   if {$found < 0} {
      # host isn't found so let's append the nick and host to our file
      set file [open $filename "a"]
      puts $file "$nick<$uhost"
      close $file
   } else {
      # the host exists, so set our list of nicks for that host
      set nicks [lindex [split [lindex $text $found] "<"] 0]
      # is the nick already known for that host?
      set nlist [split $nicks ","]
      if {[set pos [lsearch $nlist $nick]] != -1} { set nlist [lreplace $nlist $pos $pos] }

      # MAKE SURE TO READ THE COMMENTS BELOW

      # To make it output to channel remove the # the begins the line below.
      if {[string length [join $nlist]]} {
		foreach n [split $::alertnicks] {
			putserv "notice $n :*** $nick is also known as :[join $nlist ", "]."
		}
	}

      # To make it output to partyline remove the # the begins the line below.
      #if {[string length [join $nlist]]} { putloglev d * "*** $nick on $chan is also known as :[join $nlist ", "]." }

      set known [lsearch -exact [split $nicks ","] $nick]
      if {($known != -1) && ($dupes < 1)} {
         # if the nick is known return
         return
      } else {
         # otherwise add the nick to the nicks for that host
         set text [lreplace $text $found $found "$nicks,$nick<$uhost"]
      }
      # now lets write the new list to the file
      set file [open $filename "w"]
      foreach line $text {
         if {[string length $line]} { puts $file "$line" }
      }
      close $file
   }
   return 0
}

putlog "Nickname/Uhost tracker enabled." 