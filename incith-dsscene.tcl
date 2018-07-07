#---------------------------------------------------------------#
# incith:dsscene                                           v1.0 #
#                                                               #
# This script basically scrapes profile.mygamercard.net and     #
# returns relevant information about that gamer to irc.         #
#                                                               #
# Usage:                                                        #
#   .chanset #channel dsscene                                   #
#   !dsscene <tag to search for>                                #
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
# Copyleft (C) 2009, speechles                                  #
# imspeechless@gmail.com                                        #
#---------------------------------------------------------------#
package require http 2.3
setudef flag ds

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
  namespace eval dsscene {
    # set this to the command character you want to use for the binds
    variable command_char "!"

    # set these to your preferred binds ("one two")
    variable binds "ds dsscene new"

    # if you want to allow users to search via /msg, enable this
    variable private_messages 1

    # ** this is not an optional setting, if a string is too long to send, it won't be sent! **
    # It should be set to the max amount of characters that will be received in a public
    #   message by your IRC server.  If you find you aren't receiving results, try lowering this.
    variable split_length 440

    variable def 3
    variable max 5

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
  namespace eval dsscene {
    variable version "incith:dsscene-1.0"
  }
}

# bind the public binds
foreach bind [split $incith::dsscene::binds " "] {
  bind pub -|- "${incith::dsscene::command_char}$bind" incith::dsscene::public_message
}

# bind the private message binds, if wanted
if {$incith::dsscene::private_messages >= 1} {
  foreach bind [split $incith::dsscene::binds " "] {
    bind msg -|- "${incith::dsscene::command_char}$bind" incith::dsscene::private_message
  }
}

namespace eval incith {
  namespace eval dsscene {
    proc releases {input where} {
      set type 1
      if {[regsub -- {xxx} $input "" input]} { set type 2 }
      if {[regsub -- {ique} $input "" input]} { set type 3 }
      if {[regsub -- {dsi} $input "" input]} { set type 4 }
      if {$type != 1} { set input [string trim $input] }
      if {![regexp -- {^((?:[0-9]{1,2}|all))-((?:[0-9]{1,2}|all))$} $input - defs defe]} {
        if {[regexp -- {^((?:[0-9]{1,2}|all))$} $input]} {
          if {![string match "all" $input]} {
            set defs $input ; set defe [expr {$input + ${incith::dsscene::def}-1}]
          } else {
            set defs 1 ; set defe $::incith::dsscene::max
          }
        } elseif {![string length $input]} {
          set defs 1 ; set defe $::incith::dsscene::def
        }
      } else {
        if {![string length $input]} {
          set defs 1 ; set defe $::incith::dsscene::def
        } elseif {[string match "all" $defs]} {
          set defs 1
        } 
        if {[string match "all" $defe]} {
          set defe [expr {$defs + $::incith::dsscene::max}]
        }
      }
      set html [fetch_html "" $type]
      set output [list] ; set count 1
      while {[regexp -nocase {<tr class="boxCenter">.*?class="romlistTxt">.*?class="romlistTxt">(.+?)</div>.*?class="romlistTxt"><a href="(.+?)".*?>(.+?)</a>.*?class="romlistTxt".*?alt='(.+?)'.*?class="romlisttxt">(.+?)</div>.*?class="romlistTxt">(.+?)</div>.*?class="romlistTxt">(.+?)</div>.*?nowrap="nowrap">.*?class="romlistTxt".*?title="(.*?)".*?>(.+?)</div>} $html - num link title region group size save dir name]} {
       regsub -- {<tr class="boxCenter">.+?<td nowrap class="romBoxSubHeadDiv"></td>} $html "" html
       if {![string equal -nocase $dir $name]} { set name "$dir/$name" }
       lappend output "$count \002\037$num\037 $title\002 \($region\)\($group\) -> $name \[$size/$save\] http://ds-scene.net$link"
       incr count
       if {$count > 20} { break }
      }

      set count 1
      foreach line $output {
        if {[expr {($defs <= [lindex [split $line] 0]) && ($defe >= [lindex [split $line] 0])}]} {
          putserv "privmsg $where :[join [lrange [split $line] 1 end-1]] @ [lindex [split $line] end]"
          incr count
          if {[expr {$count > $::incith::dsscene::max}]} {
            putserv "privmsg $where :Max-results of $::incith::dsscene::max reached, refine search to see more of the last 20 games released."
            break
          }
        }
      }
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
    proc fetch_html {input type} {
      # a + joins words together in the search, so we change +'s to there search-form value
      regsub -all -- {\+} $input {%2B} input

      # finally, change spaces to +'s for a properly formatted search string.
      regsub -all -- { } $input {+} input
      switch -- $type {
         1 { set query "http://www.ds-scene.net/?s=releases" }
         2 { set query "http://www.ds-scene.net/?s=releases&f1=xxxx" }
         3 { set query "http://www.ds-scene.net/?s=releases&f1=ique" }
         4 { set query "http://www.ds-scene.net/?s=releases&f1=dsiw" }
      }
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
      regsub -all {(?:\n|\r|\t|\v)} $html "" html
      regsub -all {(?:<b>|</b>)} $html "" html
      # DEBUG DEBUG                    
      set junk [open "webby.txt" w]
      puts $junk $html
      close $junk
      return $html
    }

    # PUBLIC_MESSAGE
    # decides what to do with binds that get triggered
    #
    proc public_message {nick uhand hand chan input} {
      if {[lsearch -exact [channel info $chan] +ds] != -1} {
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
      if {$incith::dsscene::private_messages >= 1} {
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
  namespace eval dsscene {
    # SEND_OUTPUT
    # no point having two copies of this in public/private_message{}
    #
    proc send_output {input where} {
      foreach line [incith::dsscene::parse_output [releases $input $where]] {
        putquick "PRIVMSG $where :$line"
      }
    }

    # PARSE_OUTPUT
    # prepares output for sending to a channel/user, calls line_wrap
    #
    proc parse_output {input} {
      set parsed_output "" ; set parsed_current "" ; set lastline "" ; set fix ""
      foreach line [incith::dsscene::line_wrap $input] {
          if {[expr {[regexp -all {\002} $lastline] & 1 }]} {
            append fix "\002"
          }

          if {[expr {[regexp -all {\037} $lastline] & 1 }]} {
            append fix "\037"
          }
          lappend parsed_output "$fix$line"
          set lastline $line
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
      set len $incith::dsscene::split_length
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
      if {$incith::dsscene::ignore < 1} {
        return 0
      }
      if {![string match *:* $incith::dsscene::flood]} {
        putlog "$incith::dsscene::version: variable flood not set correctly."
        return 1
      }
      set incith::dsscene::flood_data(flood_num) [lindex [split $incith::dsscene::flood :] 0]
      set incith::dsscene::flood_data(flood_time) [lindex [split $incith::dsscene::flood :] 1]
      set i [expr $incith::dsscene::flood_data(flood_num) - 1]
      while {$i >= 0} {
        set incith::dsscene::flood_array($i) 0
        incr i -1
      }
    }
    ; flood_init

    proc maketiny {url} {
      set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
      set http [::http::config -useragent $ua -useragent "utf-8"]
      set token [http::geturl "http://tinyurl.com/api-create.php?[http::formatQuery url $url]" -timeout 3000]
      upvar #0 $token state
      if {[string length $state(body)]} { return $state(body) }
      return $url
    }

    # FLOOD
    # updates a nd returns a users flood status
    #
    proc flood {nick uhand} {
      if {$incith::dsscene::ignore < 1} {
        return 0
      }
      if {$incith::dsscene::flood_data(flood_num) == 0} {
        return 0
      }
      set i [expr ${incith::dsscene::flood_data(flood_num)} - 1]
      while {$i >= 1} {
        set incith::dsscene::flood_array($i) $incith::dsscene::flood_array([expr $i - 1])
        incr i -1
      }
      set incith::dsscene::flood_array(0) [unixtime]
      if {[expr [unixtime] - $incith::dsscene::flood_array([expr ${incith::dsscene::flood_data(flood_num)} - 1])] <= ${incith::dsscene::flood_data(flood_time)}} {
        putlog "$incith::dsscene::version: flood detected from ${nick}."
        putserv "notice $nick :$incith::dsscene::version: flood detected, placing you on ignore for $::incith::dsscene::ignore minute(s)! :P"
        newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::dsscene::version flooding $incith::dsscene::ignore
        return 1
      } else {
        return 0
      }
    }
  }
}

putlog " - $incith::dsscene::version loaded."

# EOF
