#---------------------------------------------------------------#
# incith:bf3                                               v1.0 #
#                                                               #
# This script basically scrapes battlefield 3's api and such.   #
#                                                               #
# Usage:                                                        #
#   .chanset #channel +bf3                                      #
#   !bf3 [-<platform>] <name to search for>                     #
#                                                               #
# ChangeLog:                                                    #
#    v1.0 - first release, enjoy.. :)                           #
#                                                               #
#    Requested by Mafaioz: If you like this script, then you    #
#    owe this guy your respect. Bow before him. Now! Do it!     #
#                                                               #
#    - - - Mafaioz, um.. like here's your BF3 script yo! :P     #
#                                                               #
#                                                               #
# TODO:                                                         #
#   - Suggestions/Thanks/Bugs, e-mail at bottom of header.      #
#                                                               #
# LICENSE:                                                      #
#   This code comes with ABSOLUTELY NO WARRANTY.                #
#                                                               #
#   This program is free software; you can redistribute it      #
#   and/or modify it under the terms of the GNU General Public  #
#   License as published by the Free Software Foundation;       #
#   either version 2 of the License, or (at your option) any    #
#   later version.                                              #
#                                                               #
#   This program is distributed in the hope that it will be     #
#   useful, but WITHOUT ANY WARRANTY; without even the implied  #
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR     #
#   PURPOSE.  See the GNU General Public License for more       #
#   details. (http://www.gnu.org/copyleft/library.txt)          #
#                                                               #
# Portions of the script, and the name of this script are       #
# property of: Copyright (C) 2005, Jordan - google@woota.net    #
#                                                               #
# Everything else:                                              #
# Copyleft (C) 2011, speechles                                  #
# imspeechless@gmail.com                                        #
#---------------------------------------------------------------#
package require http 2.3
setudef flag bf3

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
  namespace eval bf3 {
    # set this to the command character you want to use for the binds
    variable command_char "!"

    # set these to your preferred binds ("one two three etc etc")
    variable binds "bf3 b3"

    # set this to your default section if the user doesn't give one
    # pc / 360 / ps3
    variable section "ps3"

    # if you want to allow users to search via /msg, enable this
    variable private_messages 1

    # ** this is not an optional setting, if a string is too long to send, it won't be sent! **
    # It should be set to the max amount of characters that will be received in a public
    #   message by your IRC server.  If you find you aren't receiving results, try lowering this.
    variable split_length 403

    # number of minute(s) to ignore flooders, 0 to disable flood protection
    variable ignore 1

    # how many requests in how many seconds is considered flooding?
    # by default, this allows 3 queries in 10 seconds, the 4th being ignored
    #   and ignoring the flooder for 'variable ignore' minutes
    variable flood 4:10
  }
}

# end of configuration, script begins
namespace eval incith {
  namespace eval bf3 {
    variable version "incith:bf3-1.0"
  }
}

# bind the public binds
foreach bind [split $incith::bf3::binds " "] {
  bind pub -|- "${incith::bf3::command_char}$bind" incith::bf3::public_message
}

# bind the private message binds, if wanted
if {$incith::bf3::private_messages >= 1} {
  foreach bind [split $incith::bf3::binds " "] {
    bind msg -|- "${incith::bf3::command_char}$bind" incith::bf3::private_message
  }
}

namespace eval incith {
  namespace eval bf3 {
    # bf3
    # performs the real work of the script, this scrapes.
    #
    proc bf3 {input} {
      # local variable initialization
      set bp $::incith::bf3::section
    
      # switches
      if {[regsub -nocase -all -- {-ps3} $input "" input]} { set bp "ps3" }
      if {[regsub -nocase -all -- {-pc} $input "" input]} { set bp "pc" }
      if {[regsub -nocase -all -- {-360} $input "" input]} { set bp "360" }

      # If the user omits the tag, let's yell at them...
      if {![string length [set input [string trim $input]]]} { return "No $bp ID Specified... Please supply a bf3 ID." }

      # fetch the html
      set html [fetch_html $input $bp]

      # standard fetch_html error catcher
	if {[string equal "ERRORERROR" [lindex [split $html] 0]]} {
        return [join [lrange [split $html] 1 end]]
      }

      if {[string match "*\"status\"\:\"notfound\"*" $html]} { return "Sorry, no search results were found for \"$input\" on $bp." }

      if {![regexp -nocase -- {"name"\:"(.*?)",} $html - nick]} { set nick "" }
      if {![regexp -nocase -- {"country_name"\:"(.*?)",} $html - country]} { set country "\[country\]" }
      if {![regexp -nocase -- {"rank"\:\{"nr"\:(.*?),"name"\:"(.*?)",} $html - rank class]} { set rank "\[rank\]" ; set class "\[class\]" }
      if {![regexp -nocase -- {"global"\:\{(.*?)\},} $html - global]} { set global "\[global\]" }
      if {![regexp -nocase -- {"time"\:(.*?),} $global - times]} {
        set time 0
      } else {
        set time [duration $times] ; set t [list]
        foreach {i g} [split $time] {
         if {[string length $i] < 2} { set i "0$i" }
         lappend t $i
        }
        if {[llength $t] > 4} {
          set time "[string trimleft [lindex $t 0] 0]w [string trimleft [lindex $t 1] 0]d [lindex $t 2]:[lindex $t 3]:[lindex $t 4]"
        } elseif {[llength $t] > 3} {
          set time "[string trimleft [lindex $t 0] 0]d [lindex $t 1]:[lindex $t 2]:[lindex $t 3]"
        } elseif {[llength $t] > 2} {
          set time "[lindex $t 0]:[lindex $t 1]:[lindex $t 2]"
        } elseif {[llength $t] > 1} {
          set time "[lindex $t 0]:[lindex $t 1]"
        } elseif {[llength $t] > 0} {
          set time "[lindex $t 0]"
        } else { set time 0 }
      }

      if {![regexp -nocase -- {"shots"\:(.*?),"hits"\:(.*?),} $global - shots hits]} {
        set shots 0 ; set hits 0 ; set accy 0
      } else {
        if {$shots > 0} {
          set accy "[expr {round((10000*$hits)/$shots)}]"
          set accy "[string range $accy 0 end-2].[string range $accy end-1 end]"
        } else { set accy 0 }
      }
      if {![regexp -nocase -- {"scores"\:\{"score"\:(.*?),} $html - score]} {
        set score 0 ; set spm 0
      } else {
        if {$times > 0} {
          set spm [format "%.2f" [expr {$score/($times/60)}]]
        } else { set spm 0 }
      }
      if {![regexp -nocase -- {"longesths"\:(.*?),} $global - long]} { set long 0 }
      if {![regexp -nocase -- {"kills"\:(.*?),} $global - kills]} { set kills 0 }
      if {![regexp -nocase -- {"deaths"\:(.*?),} $global - deaths]} { set deaths 0 }
      if {![regexp -nocase -- {"killassists"\:(.*?),} $global - assists]} { set assists 0 }
      if {$kills > 0 && $deaths > 0} {
        set kdr "[expr {round((100000*$kills)/$deaths)}]"
        set kdr "[string range $kdr 0 end-5].[string range $kdr end-4 end]"
        if {[string index $kdr 0] == "."} { set kdr "0$kdr" }
      } else { set kdr 0 }
      if {![regexp -nocase -- {"wins"\:(.*?),} $global - wins]} { set wins 0 }
      if {![regexp -nocase -- {"losses"\:(.*?),} $global - losses]} { set losses 0 }
      if {$wins > 0 && $losses > 0} {
        set wlr "[expr {round((100000*$wins)/$losses)}]"
        set wlr "[string range $wlr 0 end-5].[string range $wlr end-4 end]"
        if {[string index $wlr 0] == "."} { set wlr "0$wlr" }
      } else { set wlr 0 }
      if {![regexp -nocase -- {"nextranks"\:\[\{"nr":(.*?),"name":"(.*?)","score":(.*?),} $html - rnum rankname level]} {
        set level 0 ; set rankname "" ; set rnum 0 ; set left 0
      } else {
        if {$score > 0 && $level > 0} {
           set left [expr {$level - $score}]
        } { set left 0 }
      }
      if {[string length $nick]} {
        set output "$nick (of $country) - ($bp) Rank: [string totitle $class] ($rank); Played: $time; Score: [commify $score]; Score/Minute: [commify $spm]; Next Rank: [string totitle $rankname] (in [commify $left]); Accuracy: ${accy}%; Longest Headshot: [commify ${long}]m | Kills: [commify $kills]; Deaths: [commify $deaths]; Assists: [commify $assists]; K/D Ratio: ${kdr} | Wins: [commify $wins]; Losses: [commify $losses]; W/L Ratio: ${wlr} @ http://bf3stats.com/stats_$bp/[http::formatQuery $nick]#$bp"
      } else {
        return "Sorry, no search results were found for $input on $type."
      }
      return $output
    }

    # put pretty commas in numbers
    proc commify number {regsub -all {\d(?=(\d{3})+($|\.))} $number {\0,}}

    # FETCH_HTML
    # fetches html
    #
    proc fetch_html {input type} {
      # set our query, and replace spaces with %20's in our input.
      set query "http://api.bf3stats.com/$type/player/?player=[::http::formatQuery [string trim $input]]"
      
      set http [::http::config -useragent "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.1.8) Gecko/20100202 Firefox/3.5.8"]
	catch {set http [::http::geturl "$query" -timeout 5000]} error

      if {![string match -nocase "::http::*" $error]} {
        return "ERRORERROR [string totitle $error] \( $query \)"
      }
      if {![string equal -nocase [::http::status $http] "ok"]} {
        return "ERRORERROR [string totitle [::http::status $http]] \( $query \)"
      }

      set html [::http::data $http]
      ::http::cleanup $http

      # generic pre-parsing
      regsub -all "(?:\x91|\x92|&#39;)" $html {'} html
      regsub -all "(?:\x93|\x94|&quot;)" $html {"} html
      regsub -all "&amp;" $html {\&} html
      regsub -all "&times;" $html {*} html
      regsub -all "&nbsp;" $html { } html
      regsub -all -nocase "&#215;" $html "x" html
      regsub -all -nocase "&lt;" $html "<" html
      regsub -all -nocase "&gt;" $html ">" html
      regsub -all "\n" $html "" html

      return $html
    }

    # PUBLIC_MESSAGE
    # decides what to do with binds that get triggered
    #
    proc public_message {nick uhand hand chan input} {
      if {[lsearch -exact [channel info $chan] +bf3] != -1} {
        # flood protection check
        if {[flood $nick $uhand]} {
          return
        }
        send_output $input $chan
      }
    }

    # PRIVATE_MESSAGE
    # decides what to do with binds that get triggered
    #
    proc private_message {nick uhand hand input} {
      if {$incith::bf3::private_messages >= 1} {
        # flood protection check
        if {[flood $nick $uhand]} {
          return
        }
	send_output $input $nick
      }
    }
  }
}

# support routines
namespace eval incith {
  namespace eval bf3 {
    # SEND_OUTPUT
    # no point having two copies of this in public/private_message{}
    #
    proc send_output {input where} {
      foreach line [incith::bf3::parse_output [bf3 $input]] {
        putquick "PRIVMSG $where :$line"
      }
    }

    # PARSE_OUTPUT
    # prepares output for sending to a channel/user, calls line_wrap
    #
    proc parse_output {input} {
      set parsed_output [set parsed_current {}]
      foreach line [incith::bf3::line_wrap $input] {
        lappend parsed_output $line
      }
      return $parsed_output
    }  

    # LINE_WRAP
    # takes a long line in, and chops it before the specified length
    # http://forum.egghelp.org/viewtopic.php?t=6690
    #
    proc line_wrap {str {splitChr { }}} { 
      set out [set cur {}]
      set i 0
      set len $incith::bf3::split_length
      foreach word [split [set str][set str ""] $splitChr] { 
        if {[incr i [string len $word]] > $len} { 
          lappend out [join $cur $splitChr] 
          set cur [list $word] 
          set i [string len $word] 
        } else { 
          lappend cur $word 
        } 
        incr i 
      } 
      lappend out [join $cur $splitChr] 
    }

    # FLOOD_INIT
    # modified from bseen
    #
    variable flood_data
    variable flood_array
    proc flood_init {} {
      if {$incith::bf3::ignore < 1} {
        return 0
      }
      if {![string match *:* $incith::bf3::flood]} {
        putlog "$incith::bf3::version: variable flood not set correctly."
        return 1
      }
      set incith::bf3::flood_data(flood_num) [lindex [split $incith::bf3::flood :] 0]
      set incith::bf3::flood_data(flood_time) [lindex [split $incith::bf3::flood :] 1]
      set i [expr $incith::bf3::flood_data(flood_num) - 1]
      while {$i >= 0} {
        set incith::bf3::flood_array($i) 0
        incr i -1
      }
    }
    ; flood_init

    # FLOOD
    # updates a nd returns a users flood status
    #
    proc flood {nick uhand} {
      if {$incith::bf3::ignore < 1} {
        return 0
      }
      if {$incith::bf3::flood_data(flood_num) == 0} {
        return 0
      }
      set i [expr ${incith::bf3::flood_data(flood_num)} - 1]
      while {$i >= 1} {
        set incith::bf3::flood_array($i) $incith::bf3::flood_array([expr $i - 1])
        incr i -1
      }
      set incith::bf3::flood_array(0) [unixtime]
      if {[expr [unixtime] - $incith::bf3::flood_array([expr ${incith::bf3::flood_data(flood_num)} - 1])] <= ${incith::bf3::flood_data(flood_time)}} {
        putlog "$incith::bf3::version: flood detected from ${nick}."
        putserv "notice $nick :$incith::bf3::version: flood detected, placing you on ignore for $::incith::bf3::ignore minute(s)! :P"
        newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::bf3::version flooding $incith::bf3::ignore
        return 1
      } else {
        return 0
      }
    }
  }
}

putlog " - $incith::bf3::version loaded."

# EOF

