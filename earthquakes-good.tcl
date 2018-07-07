# Earthquake .. rumble rumble rumble

# This script will announce earthquakes just like an rss script
# as well as allowing users to type commands and see
# the latest news via notice as well. Fully configurable.
# Enjoy, and may the force be with you.... always....

# speechles was here :P

package require http
setudef flag earthquake

namespace eval news {
   # config - make your changes here
   # trigger character
   set ary(pref) "!"

   # command used to reply to user
   # this can be a list of space delimited commands
   set ary(commands) "eq earthquake"

   # amount user can issue before throttle
   set ary(throttle) 2

   # throttle time
   set ary(throttle_time) 30

   # time to announce new news items
   # this can be a list of space delimited time binds.
   # the one you wish to use for bind_time uncommented.
   # set ary(bind_time) "00* 15* 30* 45*" ; # every 15 minutes
   # set ary(bind_time) "00* 30*" ; # every 30 minutes
   set ary(bind_time) "*" ; # every minute

   # url to news page
   #set ary(page) http://earthquake.usgs.gov/earthquakes/feed/csv/all/hour ; # all
   set ary(page) http://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/1.0_hour.csv
   #set ary(page) http://earthquake.usgs.gov/earthquakes/feed/csv/1.0/hour ; # only 1+ or higher

   # parsing regex used to gather news
   set ary(regex) {(.*?),(.*?),.*?"(.*?)",.*?,.*?,(.*?),.*?"(.*?)"}

   # how to snip last-id from the url mask
   set ary(snip_lastid) {}

   # max amount of news items to announce
   set ary(max_bot) 5

   # max amount of news items for users
   set ary(max_user) 5

   # display format for news messages, variables are: %description, %title, %url 
   # these can be used and will be replaced with actual values, newline (\n) will
   # let you span multiple lines if you wish. If something is too long it will
   # be cut off, be aware of this... use colors, bold, but remember to \escape any
   # special tcl characters. 
   set ary(display_format) "\002USGS Earthquake\002: %magnitude magnitude - %location ( %ago ago ) >> http://earthquake.usgs.gov/earthquakes/recenteqsus/Quakes/%sub%dir.html"

   # script version
   set ary(version) "1.1"
}

# binds
foreach bind [split $::news::ary(commands)] {
   bind pub -|- "$::news::ary(pref)$bind" ::news::pub_
   bind msg -|- "$::news::ary(pref)$bind" ::news::msg_
}
foreach bind [split $::news::ary(bind_time)] {
   bind time - $bind ::news::magic_
}
bind time - ?0* ::news::throttleclean_

namespace eval news {
   # main - time bind - magic
   proc magic_ {args} {
      news_ $::botnick [getchanhost $::botnick] $::botnick "all" "magic"
   }

   # main - msg bind - notice
   proc msg_ {nick uhost hand arg} {
         news_ $nick $uhost $hand $nick "notice"
   }

   # main - pub bind - privmsg
   proc pub_ {nick uhost hand chan arg} {
      if {[channel get $chan earthquake]} {
        news_ $nick $uhost $hand $chan "privmsg"
      }
   }

   # sub - give news
   proc news_ {nick uhost hand chan arg} {
      if {![isbotnick $nick] && [throttle_ $uhost,$chan,news $::news::ary(throttle_time)]} {
         putserv "$arg $chan :$nick, you have been Throttled! Your going too fast and making my head spin!"
	   return
      }
      set a "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1"
      set t [::http::config -useragent $a]
      catch { set t [::http::geturl $::news::ary(page) -timeout 30000] } error
      # error condition 1, socket error or other general error
      if {![string match -nocase "::http::*" $error] && ![isbotnick $nick]} {
         putserv "$arg $chan :[string totitle [string map {"\n" " | "} $error]] \( $::news::ary(page) \)"
         return
      }
      # error condition 2, http error
      if {![string equal -nocase [::http::status $t] "ok"] && ![isbotnick $nick]} {
         putserv "$arg $chan :[string totitle [::http::status $t]] \( $::news::ary(page) \)"
         return
      }
      set html [::http::data $t]
      ::http::cleanup $t
	set earthquakes [lrange [split $html "\n"] 1 end]
	foreach line $earthquakes { 
		regexp -- "$::news::ary(regex)" $line - sub dir ago magnitude location
		lappend quakes $ago $sub $dir $magnitude $location
	}
      set c 0 ; set lastid 0
	foreach {ago sub dir magnitude location} $quakes {
         incr c
	   if {![string match *.* $magnitude]} { append magnitude ".0" }
         set id [clock scan $ago] ; if {[string equal $id $lastid]} { break }
         if {[isbotnick $nick]} {
            if {$c > $::news::ary(max_bot)} { break }
            if {[info exists ::news::ary(last)]} { if {$id <= $::news::ary(last)} { break } }
         } elseif {$c > $::news::ary(max_user)} { break }
         set output [string map [list "%location" "[mapit_ $location]" "%magnitude" "$magnitude" "%ago" "[duration [expr {[clock seconds] - $id}]]" "%sub" "$sub" "%dir" "$dir"] $::news::ary(display_format)]
         if {![string equal "magic" $arg]} {
            foreach line [split $output "\n"] { puthelp "$arg $chan :$line" }
         } else {
            foreach ch [channels] {
               if {[channel get $ch earthquake]} {
		     foreach line [split $output "\n"] { puthelp "privmsg $ch :$line" }
		   }
            }
         }
         set lastid $id   
      }
      if {[string equal "magic" $arg]} { set ::news::ary(last) [clock scan [lindex $quakes 0]] }
   }

   # sub - map it
   proc mapit_ {t} { return [string map [list "&#039;" "'" "&quot;" "\""] $t] }

   # Throttle Proc (slightly altered, super action missles) - Thanks to user
   # see this post: http://forum.egghelp.org/viewtopic.php?t=9009&start=3
   proc throttle_ {id seconds} {
      if {[info exists ::news::throttle($id)]&&[lindex $::news::throttle($id) 0]>[clock seconds]} {
         set ::news::throttle($id) [list [lindex $::news::throttle($id) 0] [set value [expr {[lindex $::news::throttle($id) 1] +1}]]]
         if {$value > $::news::ary(throttle)} { set id 1 } { set id 0 }
      } {
         set ::news::throttle($id) [list [expr {[clock seconds]+$seconds}] 1]
         set id 0
      }
   }
   # sub - clean throttled users
   proc throttleclean_ {args} {
      set now [clock seconds]
      foreach {id time} [array get ::news::throttle] {
         if {[lindex $time 0]<=$now} {unset ::news::throttle($id)}
      }
   }
}

putlog "earthquake announcer.tcl v$::news::ary(version) loaded."



