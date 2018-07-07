#---------------------------------------------------------------#
# incith:steam                                             v1.0 #
#                                                               #
# This script basically scrapes profile.mygamercard.net and     #
# returns relevant information about that gamer to irc.         #
#                                                               #
# Usage:                                                        #
#   .chanset #channel +steam                                    #
#   !steam <tag to search for>                                  #
#                                                               #
# ChangeLog:                                                    #
#    v1.0 - first release, enjoy.. :)                           #
#                                                               #
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
# Copyleft (C) 2008, speechles                                  #
# imspeechless@gmail.com                                        #
#---------------------------------------------------------------#
package require http 2.3
setudef flag steam

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
  namespace eval steam {
    # set this to the command character you want to use for the binds
    variable command_char "!"

    # set these to your preferred binds ("one two")
    variable binds "steam"

    # if you want to allow users to search via /msg, enable this
    variable private_messages 1

    # ** this is not an optional setting, if a string is too long to send, it won't be sent! **
    # It should be set to the max amount of characters that will be received in a public
    #   message by your IRC server.  If you find you aren't receiving results, try lowering this.
    variable split_length 440

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
  namespace eval steam {
    variable version "incith:steam-1.0"
  }
}

# bind the public binds
foreach bind [split $incith::steam::binds " "] {
  bind pub -|- "${incith::steam::command_char}$bind" incith::steam::public_message
}

# bind the private message binds, if wanted
if {$incith::steam::private_messages >= 1} {
  foreach bind [split $incith::steam::binds " "] {
    bind msg -|- "${incith::steam::command_char}$bind" incith::steam::private_message
  }
}

namespace eval incith {
  namespace eval steam {
    # steam
    # performs the real work of the script, this scrapes.
    #
    proc steam {input} {
      # local variable initialization
      set results 0 ; set output ""

      # If the user omits the tag, let's yell at them...
      if {$input == ""} { return "No id specified, search terminated. Please supply a steam id." }

      # fetch the html
      set html [fetch_html $input]
      regsub -all {(?:\n|\r|\t|\v)} $html "" html

      # DEBUG DEBUG                    
      set junk [open "ig-debug.txt" w]
      puts $junk $html
      close $junk

      # standard fetch_html error catcher
	if {[string match -nocase "*socketerrorabort*" $html]} {
            regsub {(.+?)\|} $html {} html
            return "There was a socket error accessing '${html}'..."
	}
	if {[string match -nocase "*timeouterrorabort*" $html]} {
		return "The connection has timed out..."
	}

      # parse the html
      if {[regexp -- {"personaname":"(.*?)"} $html - steam_nick]} {
        set steam_nick [string trim $steam_nick]
      } else { set steam_nick "notfound" }
      if {[regexp -nocase {profileBlock.+?<h1>(.*?)</h1><h2>(.+?)<img style} $html - steam_shout steam_profile]} {
        if {[info exists steam_shout]} { set steam_shout " \037$steam_shout\017 " }
        regsub {</h2><h2>} $steam_profile " of " steam_profile
        set steam_profile "$steam_shout\([string trim $steam_profile]\)"
      } else {
        set steam_profile "" 
      }
      if {[regexp -- {<p id="statusOfflineText">(.+?)</p>} $html - steam_offline]} {
        if {[string match "*</div>*" $steam_offline]} {
          regexp -- {<p class="errorPrivate">(.*?)</p>} $html - steam_offline
        }
        set steam_offline " | Note: [string trim $steam_offline]"
      } else {
        set steam_offline ""
      }
      if {[regexp -- {Member since (.+?)"} $html - steam_memberdate]} {
        set steam_memberdate [string trim $steam_memberdate]
      } else {
        set steam_memberdate "None"
      }
      if {[regexp -- {Steam Rating:</div>(.+?)<} $html - steam_rating]} {
        set steam_rating [string trim $steam_rating]
      } else {
        set steam_rating "None"
      }
      if {[regexp -- {Playing time:</div>(.+?)<} $html - steam_playing]} {
        set steam_playing [string trim $steam_playing]
      } else {
        set steam_playing "None"
      }
      if {[regexp -- {<div class="mostPlayedBlock">(.+?)</span>} $html - steam_gamemost]} {
        regsub {<br />} $steam_gamemost " w/" steam_gamemost
        regsub -all {<(.+?)>} $steam_gamemost "" steam_gamemost
        set steam_gamemost [string trim $steam_gamemost]
      } else {
        set steam_gamemost "None"
      }

      # alter this to change the output display to your liking.. :
      set output "\002Steam\002 for $steam_nick$steam_profile | MemberSince: $steam_memberdate | Rating: $steam_rating | PlayingTime: $steam_playing | Currently: $steam_gamemost $steam_offline @ http://steamcommunity.com/id/[urlencode $input]"
      # make sure we have something to send
      if {[string equal $steam_nick "notfound"]} {
        regexp -- {<div id="message">(.+?)</h3>} $html - msg
        regsub -all {<h.*?>} $msg "\002" msg
        regsub -all {</h.*?>} $msg "\002" msg
        regsub -all {<p class.*?>} $msg " " msg
        regsub -all {</p>} $msg " " msg
        regsub -all {<.*?>} $msg "" msg
        return $msg
      }
      return $output
    }

    proc urlencode {text} {
      set url ""
      foreach byte [split [encoding convertto utf-8 $text] ""] {
        scan $byte %c i
        if {$i < 65 || $i > 122} {
          append url [format %%%02X $i]
        } else {
          append url $byte
        }
      }
      return [string map {%3A : %2D - %2E . %30 0 %31 1 %32 2 %33 3 %34 4 %35 5 %36 6 %37 7 %38 8 %39 9 \[ %5B \\ %5C \] %5D \^ %5E \_ %5F \` %60} $url]
    } 

    # FETCH_HTML
    # fetches html
    #
    proc fetch_html {input} {
      # a + joins words together in the search, so we change +'s to there search-form value
      regsub -all -- {\+} $input {%2B} input

      # finally, change spaces to +'s for a properly formatted search string.
      regsub -all -- { } $input {+} input

      # set our query, and replace spaces with %20's in our input.
      set query "http://steamcommunity.com/id/[urlencode $input]"

      # stole this bit from rosc2112 on egghelp forums
      # borrowed is a better term, all procs eventually need this error handler.
	catch {set http [::http::geturl "$query" -timeout [expr 1000 * 15]]} error
	if {[string match -nocase "*couldn't open socket*" $error]} {
            return "socketerrorabort|${query}"
	}
	if { [::http::status $http] == "timeout" } {
		return "timeouterrorabort"
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
      if {[lsearch -exact [channel info $chan] +steam] != -1} {
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
      if {$incith::steam::private_messages >= 1} {
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
  namespace eval steam {
    # SEND_OUTPUT
    # no point having two copies of this in public/private_message{}
    #
    proc send_output {input where} {
      foreach line [incith::steam::parse_output [steam $input]] {
        putquick "PRIVMSG $where :$line"
      }
    }

    # PARSE_OUTPUT
    # prepares output for sending to a channel/user, calls line_wrap
    #
    proc parse_output {input} {
      set parsed_output [set parsed_current {}]
      foreach line [incith::steam::line_wrap $input] {
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
      set len $incith::steam::split_length
      regsub -all "\002" $str "<ZQ" str
      regsub -all "\037" $str "<ZX" str
      foreach word [split [set str][set str ""] $splitChr] { 
        if {[incr i [string len $word]] > $len} { 
          regsub -all "<ZQ" $cur "\002" cur
          regsub -all "<ZX" $cur "\037" cur
          lappend out [join $cur $splitChr] 
          set cur [list $word] 
          set i [string len $word] 
        } else { 
          lappend cur $word 
        } 
        incr i 
      } 
      regsub -all "<ZQ" $cur "\002" cur
      regsub -all "<ZX" $cur "\037" cur
      lappend out [join $cur $splitChr] 
    }

    # FLOOD_INIT
    # modified from bseen
    #
    variable flood_data
    variable flood_array
    proc flood_init {} {
      if {$incith::steam::ignore < 1} {
        return 0
      }
      if {![string match *:* $incith::steam::flood]} {
        putlog "$incith::steam::version: variable flood not set correctly."
        return 1
      }
      set incith::steam::flood_data(flood_num) [lindex [split $incith::steam::flood :] 0]
      set incith::steam::flood_data(flood_time) [lindex [split $incith::steam::flood :] 1]
      set i [expr $incith::steam::flood_data(flood_num) - 1]
      while {$i >= 0} {
        set incith::steam::flood_array($i) 0
        incr i -1
      }
    }
    ; flood_init

    # FLOOD
    # updates a nd returns a users flood status
    #
    proc flood {nick uhand} {
      if {$incith::steam::ignore < 1} {
        return 0
      }
      if {$incith::steam::flood_data(flood_num) == 0} {
        return 0
      }
      set i [expr ${incith::steam::flood_data(flood_num)} - 1]
      while {$i >= 1} {
        set incith::steam::flood_array($i) $incith::steam::flood_array([expr $i - 1])
        incr i -1
      }
      set incith::steam::flood_array(0) [unixtime]
      if {[expr [unixtime] - $incith::steam::flood_array([expr ${incith::steam::flood_data(flood_num)} - 1])] <= ${incith::steam::flood_data(flood_time)}} {
        putlog "$incith::steam::version: flood detected from ${nick}."
        putserv "notice $nick :$incith::steam::version: flood detected, placing you on ignore for $::incith::steam::ignore minute(s)! :P"
        newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::steam::version flooding $incith::steam::ignore
        return 1
      } else {
        return 0
      }
    }
  }
}

putlog " - $incith::steam::version loaded."

# EOF
