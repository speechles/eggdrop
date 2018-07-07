# Earthquake .. rumble rumble rumble

# This script will announce earthquakes just like an rss script
# as well as allowing users to type commands and see
# the latest news via notice as well. Fully configurable.
# Enjoy, and may the force be with you.... always....

# speechles was here :P

package require http
setudef flag tv

namespace eval tv {
   variable tv
   # config - make your changes here
   # trigger character
   set tv(pref) "!"

   # command used to reply to user
   # this can be a list of space delimited commands
   set tv(commands) "tv tvshow"

   # amount user can issue before throttle
   set tv(throttle) 2

   # throttle time
   set tv(throttle_time) 30

   # url to news page
   set tv(page) http://api.dailytvtorrents.org/1.0/episode.getLatest?show_name=

   # display format for news messages, variables are: %description, %title, %url 
   # these can be used and will be replaced with actual values, newline (\n) will
   # let you span multiple lines if you wish. If something is too long it will
   # be cut off, be aware of this... use colors, bold, but remember to \escape any
   # special tcl characters. 
   set tv(display_format) "\002USGS Earthquake\002: M\002%magnitude\002, %title ( %ago ago ) >> http://earthquake.usgs.gov/earthquakes/eventpage/%event"

   # script version
   set tv(version) "1.0"
}

# binds
foreach bind [split $::tv::tv(commands)] {
   bind pub -|- "$::tv::tv(pref)$bind" ::tv::pub_
   bind msg -|- "$::tv::tv(pref)$bind" ::tv::msg_
}

bind time - ?0* ::tv::throttleclean_

namespace eval tv {
   # main - msg bind - notice
   proc msg_ {nick uhost hand arg} {
         tv_ $nick $uhost $hand $nick $arg
   }

   # main - pub bind - privmsg
   proc pub_ {nick uhost hand chan arg} {
      if {[channel get $chan tv]} {
        tv_ $nick $uhost $hand $chan $arg
      }
   }

   # sub - give news
   proc tv_ {nick uhost hand chan arg} {
      if {![isbotnick $nick] && [throttle_ $uhost,$chan,news $::tv::tv(throttle_time)]} {
         putserv "$arg $chan :$nick, you have been Throttled! Your going too fast and making my head spin!"
	   return
      }
      set a "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1"
      set t [::http::config -useragent $a]
      catch { set t [::http::geturl $::tv::tv(page)[set a [string map [list %20 -] [http::formatQuery [string trim [string tolower $arg]]]]] -timeout 5000] } error
      # error condition 1, socket error or other general error
      if {![string match -nocase "::http::*" $error] && ![isbotnick $nick]} {
         putserv "privmsg $chan:[string totitle [string map {"\n" " | "} $error]] \( $::tv::tv(page) \)"
         return
      }
      # error condition 2, http error
      if {![string equal -nocase [::http::status $t] "ok"] || ![string equal -nocase [::http::ncode $t] 200]} {
         putserv "privmsg $chan :[::http::ncode $t] [string totitle [::http::status $t]] \( $::tv::tv(page)$a \)"
         return
      }
      set html [::http::data $t]
      ::http::cleanup $t
	if {![regexp -- {"num"\:"(.*?)"} $html - ep]} { set ep "n/a" }
	if {![regexp -- {"title"\:"(.*?)"} $html - title]} { set title "n/a" }
	if {![regexp -- {"age"\:(.*?),} $html - age]} { set age "n/a" }
	if {![regexp -- {"hd"\:"(.*?)"} $html - hd]} { set hd "n/a" }
	if {![regexp -- {"720"\:"(.*?)"} $html - 720]} { set 720 "n/a" }
	if {![regexp -- {"1080"\:"(.*?)"} $html - 1080]} { set 1080 "n/a" }
      if {[string length "$hd$720$1080"] < 200} {
		putserv "privmsg $chan :$ep $title ( [duration $age] ago ) \002HD\002: [unescape $hd] | \002720p\002: [unescape $720] | \0021080p\002: [unescape $1080]"
	} else {
		putserv "privmsg $chan :$ep $title ( [duration $age] ago ) \002HD\002: [unescape $hd] | \002720p\002: [unescape $720]"
		putserv "privmsg $chan :$ep $title ( [duration $age] ago ) \0021080p\002: [unescape $1080]"
	}
   }
    
   proc unescape {t} { return [string map [list \\ ""] $t] }

   # sub - map it
   proc mapit_ {t} { return [string map [list "&#039;" "'" "&quot;" "\""] $t] }

   # Throttle Proc (slightly altered, super action missles) - Thanks to user
   # see this post: http://forum.egghelp.org/viewtopic.php?t=9009&start=3
   proc throttle_ {id seconds} {
      if {[info exists ::tv::throttle($id)]&&[lindex $::tv::throttle($id) 0]>[clock seconds]} {
         set ::tv::throttle($id) [list [lindex $::tv::throttle($id) 0] [set value [expr {[lindex $::tv::throttle($id) 1] +1}]]]
         if {$value > $::tv::tv(throttle)} { set id 1 } { set id 0 }
      } {
         set ::tv::throttle($id) [list [expr {[clock seconds]+$seconds}] 1]
         set id 0
      }
   }
   # sub - clean throttled users
   proc throttleclean_ {args} {
      set now [clock seconds]
      foreach {id time} [array get ::tv::throttle] {
         if {[lindex $time 0]<=$now} {unset ::tv::throttle($id)}
      }
   }
}

putlog "tvtorrents announcer.tcl v$::tv::tv(version) loaded."




