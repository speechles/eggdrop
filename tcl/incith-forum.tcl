#---------------------------------------------------------------#
# incith:forum                                             v1.0 #
#                                                               #
# This script basically scrapes most phpbb forums and displays  #
# some information about one of their members onto irc.         #
# to irc.                                                       #
#                                                               #
# Usage:                                                        #
#   .chanset #channel +forum                                    #
#   !forum <member name begins with>                            #
#                                                               #
# ChangeLog:                                                    #
#    v1.0 - first release, enjoy.. :)                           #
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
setudef flag forum

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
  namespace eval forum {
    # set this to the command character you want to use for the binds
    variable command_char "!"

    # set these to your preferred binds ("one two")
    variable binds "forum"

    # if you want to allow users to search via /msg, enable this
    variable private_messages 1

    # Enter the EXACT URL of the forum search page leaving the name field empty
    variable forumsearch "http://www.trancelite.net/forum/index.php?act=members&name_box=begins&name="
    #variable forumsearch "http://www.invisionboard.pl/index.php?act=members&name_box=begins&name="

    # Enter the EXACT URL of the forum showuser page again, leaving field empty
    variable forumuser "http://www.trancelite.net/forum/index.php?showuser="

    # Enter the name of your forum below
    variable myforum "Forum-Name-Here"
 
    # Set your output here you have a few variables to use
    # %forum_name% = not read from page, this is display only
    # %forum_url% = the url to the member page 
    # The rest are read from the page....
    # %forum_nick% %forum_age% %forum_gender% %forum_member%
    # %forum_date% %forum_time% %forum_seen% %forum_location%
    # %forum_posts% %forum_profile%
    variable output "\002%forum_name%\002 for %forum_nick% \(%forum_age%/%forum_gender%) in %forum_member% | %forum_date% | %forum_time% | %forum_seen% | %forum_location% | %forum_posts% | %forum_profile% @ %forum_url%"

    # would you like to render output in charset detected?
    variable renderchar 1

    # would you like to force charset encoding? to enable this
    # the option above MUST be zero to 0
    variable mycharset "iso8859-2"

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
  namespace eval forum {
    variable version "incith:forum-1.0"
  }
}

# bind the public binds
foreach bind [split $incith::forum::binds " "] {
  bind pub -|- "${incith::forum::command_char}$bind" incith::forum::public_message
}

# bind the private message binds, if wanted
if {$incith::forum::private_messages >= 1} {
  foreach bind [split $incith::forum::binds " "] {
    bind msg -|- "${incith::forum::command_char}$bind" incith::forum::private_message
  }
}

namespace eval incith {
  namespace eval forum {
    # forum scraper
    # performs the real work of the script, this scrapes.
    #
    proc forum {input} {
      # local variable initialization
      set output ""

      # fetch the html
      set html [fetch_html $input 1]

      # standard fetch_html error catcher
	if {[regsub {!ERR!|(.*?)$} $html {} html]} {
        return $html
	}
      
      # grab the very top result from our nickname search.
      regexp -- {<div id="post-member-(.+?)"} $html - nickjump

      # if we have user error, and no nickname to parse, lets end the search.
      if {![info exists nickjump]} { return "Cannot complete your search request, \"${input}\" not found." ; return }

      #
      if {[regexp -nocase -- {<h4>The error returned was:</h4>]} $html - dummy]} {
        regexp -nocase -- {</h4>.+?<p>(.+?)</p} $html - nickjump
        return $nickjump
      }

      set html [fetch_html $nickjump 2]

      # parse the html
      regexp -- {<!-- Personal Info -->.*?<div class='row[0-9]'.*?>(.+?)<.*?<div class='row[0-9]'.*?>(.+?)<.*?<div class='row[0-9]'.*?>(.+?)<.*?<div class='row[0-9]'.*?>(.+?)<.*?<div class='row[0-9]'.*?>(.+?)<} $html - forum_nick forum_member forum_age forum_gender forum_location
      regexp -- {<!-- Statistics -->.*?<div class=.*?>.*?<div class=.*?>(.+?)<.*?<div class=.*?>(.+?)<.*?<div class=.*?>(.+?)<.*?<div class=.*?>(.+?)<.*?<div class=.*?>(.+?)<} $html - forum_date forum_profile forum_seen forum_time forum_posts

      regsub -nocase {%forum_name%} $::incith::forum::output "$::incith::forum::myforum" out
      regsub -nocase {%forum_nick%} $out [string trim $forum_nick] out
      regsub -nocase {%forum_age%} $out [string trim $forum_age] out
      regsub -nocase {%forum_gender%} $out [string trim $forum_gender] out
      regsub -nocase {%forum_member%} $out [string trim $forum_member] out
      regsub -nocase {%forum_date%} $out [string trim $forum_date] out
      regsub -nocase {%forum_time%} $out [string trim $forum_time] out
      regsub -nocase {%forum_seen%} $out [string trim $forum_seen] out
      regsub -nocase {%forum_location%} $out [string trim $forum_location] out
      regsub -nocase {%forum_posts%} $out [string trim $forum_posts] out
      regsub -nocase {%forum_profile%} $out [string trim $forum_profile] out
      regsub -nocase {%forum_url%} $out "$::incith::forum::forumuser$nickjump" out
      return $out
    }

    # FETCH_HTML
    # fetches html
    #
    proc fetch_html {input switch} {
      # a + joins words together in the search, so we change +'s to there search-form value
      regsub -all -- {\+} $input {%2B} input

      # finally, change spaces to +'s for a properly formatted search string.
      regsub -all -- { } $input {+} input

      # set our query, and replace spaces with %20's in our input.
      if {$switch == 1} {
        set query "$::incith::forum::forumsearch${input}"
      } else {
        set query "$::incith::forum::forumuser${input}"
      }

      set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.7) Gecko/20070914 Firefox/2.0.0.7"
      set http [::http::config -useragent $ua]
      # stole this bit from rosc2112 on egghelp forums
      # borrowed is a better term, all procs eventually need this error handler.
	catch {set http [::http::geturl "$query" -timeout [expr 1000 * 20]]} error
      if {![string match -nocase "::http::*" $error]} {
        return "!ERR!|[string totitle $error] \( $fullquery \)"
      }
      if {![string equal -nocase [::http::status $http] "ok"]} {
        return "!ERR!|[string totitle [::http::status $http]] \( $fullquery \)"
      }
      upvar #0 $http state
      if {$::incith::forum::renderchar > 0} {
        set html [incithencode [::http::data $http] [string map -nocase {"UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $state(charset)]]
      } else {
        set html [incithencode [::http::data $http] $::incith::forum::mycharset]
      }
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
      regsub -all -nocase "<span id.*?>" $html "" html
      regsub -all -nocase "<img src=.*?>" $html "" html
      regsub -all -nocase "</span>" $html "" html
      if {$switch != 1} { regsub -all -nocase "<div id=.*?>" $html "" html }
      regsub -all "\n" $html "" html
      regsub -all "\t" $html "" html
      regsub -all "\r" $html "" html
      regsub -all "\v" $html "" html
      # DEBUG DEBUG                    
      set junk [open "webby.txt" w]
      puts $junk $html
      close $junk
      return $html
    }

    proc incithencode {text enc} {
      if {[lsearch -exact [encoding names] $enc] != -1} {
        set text [encoding convertto $enc $text]
      }
      return $text
    }

    # PUBLIC_MESSAGE
    # decides what to do with binds that get triggered
    #
    proc public_message {nick uhand hand chan input} {
      if {[lsearch -exact [channel info $chan] +forum] != -1} {
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
      if {$incith::forum::private_messages >= 1} {
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
  namespace eval forum {
    # SEND_OUTPUT
    # no point having two copies of this in public/private_message{}
    #
    proc send_output {input where} {
      foreach line [incith::forum::parse_output [forum $input]] {
        putquick "PRIVMSG $where :$line"
      }
    }

    # PARSE_OUTPUT
    # prepares output for sending to a channel/user, calls line_wrap
    #
    proc parse_output {input} {
      set parsed_output [set parsed_current {}]
      foreach line [incith::forum::line_wrap $input] {
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
      set len $incith::forum::split_length
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
      if {$incith::forum::ignore < 1} {
        return 0
      }
      if {![string match *:* $incith::forum::flood]} {
        putlog "$incith::forum::version: variable flood not set correctly."
        return 1
      }
      set incith::forum::flood_data(flood_num) [lindex [split $incith::forum::flood :] 0]
      set incith::forum::flood_data(flood_time) [lindex [split $incith::forum::flood :] 1]
      set i [expr $incith::forum::flood_data(flood_num) - 1]
      while {$i >= 0} {
        set incith::forum::flood_array($i) 0
        incr i -1
      }
    }
    ; flood_init

    # FLOOD
    # updates a nd returns a users flood status
    #
    proc flood {nick uhand} {
      if {$incith::forum::ignore < 1} {
        return 0
      }
      if {$incith::forum::flood_data(flood_num) == 0} {
        return 0
      }
      set i [expr ${incith::forum::flood_data(flood_num)} - 1]
      while {$i >= 1} {
        set incith::forum::flood_array($i) $incith::forum::flood_array([expr $i - 1])
        incr i -1
      }
      set incith::forum::flood_array(0) [unixtime]
      if {[expr [unixtime] - $incith::forum::flood_array([expr ${incith::forum::flood_data(flood_num)} - 1])] <= ${incith::forum::flood_data(flood_time)}} {
        putlog "$incith::forum::version: flood detected from ${nick}."
        putserv "notice $nick :$incith::forum::version: flood detected, placing you on ignore for $::incith::forum::ignore minute(s)! :P"
        newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::forum::version flooding $incith::forum::ignore
        return 1
      } else {
        return 0
      }
    }
  }
}

putlog " - $incith::forum::version loaded."

# EOF
