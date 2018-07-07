#---------------------------------------------------------------#
# incith:dictionary                                        v1.9 #
#                                                               #
# This script scrapes wordnetweb.princeton.edu/perl/webwn?s=    #
# and returns relevant information to irc.                      #
#                                                               #
# Usage:                                                        #
#   .chanset #channel +dictionary                               #
#   !dict [<noun/verb/adjective/adverb>][<number of results     #
#      start-end>] <word>                                       #
#                                                               #
# ChangeLog:                                                    #
#    v1.0 - first release, enjoy.. :)                           #
#    v1.1 - All messages not a definition changed to notice     #
#           the nickname.                                       #
#           Removed slight cruft from the output (S:)           #
#    v1.2 - Major config options added.                         #
#           Xmas present to holycrap. Wow. ;)                   #
#    v1.3 - Added in overlooked socket/timeout detection.       #
#    v1.4 - Added variable switch order for type/range.         #
#    v1.5 - Changed switch parsing order and also               #
#           refined expression matching.                        #
#    v1.6 - Added lexical information as attributes.            #
#    v1.7 - Corrected input parsing detection.                  #
#           Now correctly handles all input types below:        #
#           !dict --noun <word>                                 #
#           !dict --noun2-5 <word>                              #
#           !dict --noun7 <word>                                #
#           !dict --nounall <word>                              #
#           !dict --noun3-all <word>                            #
#           !dict --nounall-2 <word>                            #
#           noun can be also verb, adj, adv or all.             #
#           Added automatic redirect support.                   #
#    v1.8 - Thoroughly tested script, refined input parser      #
#             to eliminate any potential over-matching.         #
#           Removed debug code - holycrap spotted it. :D        #
#           Corrected support for redirects, added missing      #
#             upvar into while loop detecting redirects. This   #
#             more correctly simulates recursive behavior.      #
#    v1.9 - Debug options added per request.                    #
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
# property of: Copyright (C) 2005, Jordan - incith@incith.com   #
#                         as well as madwoota: google@woota.net #
#                                                               #
# Everything else:                                              #
# Copyleft (C) 2008, speechles                                  #
# imspeechless@gmail.com                                        #
# Jan 21st, 2009                                                #
#---------------------------------------------------------------#
package require http 2.3
setudef flag dictionary

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
  namespace eval dictionary {
    # set this to the command character you want to use for the binds
    # --
    variable command_char "!"

    # set this to the character you want to use for the switching.
    # you may set this to "" and have it function as well.
    # --
    variable switcher "--"

    # set this to correspond to the order you will allow switches
    # and their ranges.
    # 0 - <type><range>
    # 1 - <range><type>
    #
    # <type> being noun/verb/adverb/adjective/etc
    # <range> being <start>-<end> indexing.
    # --
    variable switchorder 0

    # set these to your preferred binds ("one two etc")
    # --
    variable binds "dict define"

    # set this to the website we are going to get our definitions from.
    # at the moment, only the site listed below is tested.
    # --
    set webdict "http://wordnetweb.princeton.edu/perl/webwn\?"

    # set these to your preferred binds for type selection ("noun no n")
    # Must be longest to shortest. The order you put here must
    # match the order you put in the typeline below this.
    # --
    variable types {
      "noun n"
      "adverb adv"
      "adjective adj"
      "verb v"
      "all a"
    }

    # what order does the list above appear, this must match how the website calls them
    # and must be in the same order the sublists above are done, hope you understand :P
    # --
    variable typeline "noun adverb adjective verb all"

    # How many definitions should be shown by default
    # --
    variable def 1

    # How many definitions should the script ever return, this is your maximum..
    # --
    variable max 5

    # if you want to allow users to search via /msg, enable this
    # 0 - no, 1 and above - yes
    # --
    variable private_messages 1

    # how should extra messages be sent to the user if activated in channel?
    # 0 - channel, 1 - nick
    # --
    variable extra 1

    # Should a total results line be given with the definition?
    # this affects 'display option 2' found below in display options section.
    # 0 - no, 1 and above - yes
    # --
    variable totalr 1

    # ** this is not an optional setting, if a string is too long to send, it won't be sent! **
    # It should be set to the max amount of characters that will be received in a public
    #   message by your IRC server.  If you find you aren't receiving results, try lowering this.
    # --
    variable split_length 440

    # number of minute(s) to ignore flooders, 0 to disable flood protection
    # 0 - no, 1 and above - yes
    # --
    variable ignore 1

    # how many requests in how many seconds is considered flooding?
    # by default, this allows 3 queries in 10 seconds, the 4th being ignored
    #   and ignoring the flooder for 'variable ignore' minutes
    # --
    variable flood 4:10

    # debug?
    # this enables putlogs for all user input.
    # If you modify the types variable and have trouble matching afterwards
    # enable this to determine how the script is parsing the input.
    # 1 and above enables, 0 or lower disables. This affects display option
    # 9 found below as well.
    # --
    variable debug 1

    # ---------------------------------------------------------------
    # display options are below in 8 sections. read them closely...
    # --

    ## MAIN DISPLAY OPTION
    # You get five variables to use here:
    # %%type%% - The type of word defined, noun, verb, etc..
    # %%attrib%% - The lexical relation to the word, better ;)
    # %%num%% - The count of definitions for each type.
    # %%total%% - The total count of definitions for each type.
    # %%def%% - The definition.. ah ;)
    #
    # You can use these however you like, put color etc go nuts ;P
    # --
    variable display "%%type%% \002%%attrib%%\002 (%%num%%/%%total%%) %%def%%"

    ## DISPLAY OPTION 1
    # You get one variable to use here:
    # %%max%% - your 'max' setting you chose above.
    #
    # This one is pretty simple to understand isn't it?
    # --
    variable display1 "Maximum limit of %%max%% reached..refine search to see more."

    ## DISPLAY OPTION 2
    # You get three variables to use here:
    # %%input%% - the word hopefully about to be defined.
    # %%totals%% - the noun/verb/etc amounts found
    # %%url%% - the url to see this with a web browser, to click.
    #
    # Keep in mind the 'totalr' option above can disable this message showing
    # so you may not need to config or care about this setting much if you've
    # disabled this already
    #
    # this is for totals.
    # --
    variable display2 "\002%%input%%\002: %%totals%% @ %%url%%"

    ## DISPLAY OPTION 3
    # You get four variables to use here:
    # %%input%% - the word hopefully about to be defined.
    # %%type%% - the type the word is, noun,verb,etc..
    # %%start%% - the start range chosen
    # %%end%% - the end range chosen
    #
    # this is for no results.
    # --
    variable display3 "\002%%input%%\002: No results found for \002%%type%% %%start%%-%%end%%\002"

    ## DISPLAY OPTION 4
    # You get two variables to use here:
    # %%last%% - the last trigger used to activate this script.
    # %%switch%% - the switch your presently using, you can choose "" (null string)
    #              for 'switcher' above and still have this show correctly left alone.
    #
    # this is for nothing given to search for. You may need to change the switch order
    # below if depending on your option used for switch order.
    # --
    variable display4 "%%last%% \[%%switch%%<noun/verb/adjective/adverb/all><number of results start-end>\] <word>"

    # DISPLAY OPTION 5
    # you get two variables to use here:
    # %%input%% - the word again we are looking for, remember?
    # %%reply%% - the reply the website gives when things go wrong.
    #
    # this is for problems..
    # --
    variable display5 "\002%%input%%\002: %%reply%%"

    # DISPLAY OPTION 6
    # you get one variable to use here:
    # %%site%% - the website we attempted to connect to.
    #
    # this is for socket errors.
    # --
    variable display6 "\002Socket error\002 attempting to connect to '%%site%%'."

    # DISPLAY OPTION 7
    # you get one variable to use here:
    # %%site%% - the website we attempted to connect to.
    #
    # this is for timeouts.
    # --
    variable display7 "\002Time-out error\002 occured when trying to query '%%site%%'."

    # DISPLAY OPTION 8
    # you get one variable to use here:
    # %%site%% - the website redirect both to and from.
    #
    # this is for redirect loop errors.
    # --
    variable display8 "\002Redirect error\002 '%%site%%' redirects to itself causing an infinite loop."

    # DISPLAY OPTION 9
    # you get a ton of (ten!) variables to use here:
    # %%nick%% - this is exactly what you think it is
    # %%where%% - where the script was activated
    # %%type%% - the users type (pre-parsed)
    # %%range%% - the users range (pre-parsed)
    # %%input%% - the users input (parsed)
    # %%start%% - the users start range (parsed)
    # %%end%% - the users end range (parsed)
    # %%typeline%% - the users type (parsed)
    # %%last%% - the last trigger used to activate
    # %%fullinput%% - the users full input (pre-parsed)
    #
    # for this to work you MUST enable the debug option above.
    # this is for whatever you want to display in partyline/logfiles.
    # below are a few examples, keep only one un-commented.
    # --
    # a) the way the debug line was originally in the script.
    # variable display9 "<( %%nick%%@%%where%% )> \"%%fullinput%%\" :: types = %%type%%; range = %%range%%; input = %%input%%; start = %%start%%; end = %%end%%; typeline = %%typeline%%"
    # b) here's an example to show what people are searching for.
    variable display9 "<(\002%%nick%%@%%where%%\002)> \"%%last%% %%fullinput%%\" --> \002%%input%%\002\ (%%typeline%% %%start%%-%%end%%)"

    # ---------------------------------------------------------------
    # MERRY XMAS HOLYCRAP!
    # if you've read this far then hopefully what you see here epitomizes what
    # a damn good dictionary script should look like? ;P
    # --
  }
}

# end of configuration, script begins
namespace eval incith {
  namespace eval dictionary {
    variable version "incith:dictionary-1.9"
  }
}

# bind the public binds
foreach bind [split $incith::dictionary::binds " "] {
  bind pub -|- "${incith::dictionary::command_char}$bind" incith::dictionary::public_message
}

# bind the private message binds, if wanted
if {$incith::dictionary::private_messages >= 1} {
  foreach bind [split $incith::dictionary::binds " "] {
    bind msg -|- "${incith::dictionary::command_char}$bind" incith::dictionary::private_message
  }
}

namespace eval incith {
  namespace eval dictionary {
    # dictionary
    # performs the real work of the script, this scrapes.
    #
    proc dictionary {where nick input} {
      set di $input
      set dreg "^${incith::dictionary::switcher}(.*?) (.+?)$"
      if {![regexp -- "$dreg" $input - switch input ]} { set switch "" }
      if {![string length $input]} {
        regsub -nocase "%%last%%" ${incith::dictionary::display4} $::lastbind ds
        regsub -nocase "%%switch%%" $ds ${incith::dictionary::switcher} ds
        if {[expr {$::incith::dictionary::extra > 0}]} {
          puthelp "notice $nick :$ds"
        } else {
          puthelp "privmsg $where :$ds"
        }
        return
      }

      set ntype "all" ; set found 0 ; set n ""
      set count 0 ; set defs 1 ; set defe $::incith::dictionary::def
      foreach setting ${incith::dictionary::types} {
        foreach subset [split $setting] {
          if {[expr {$::incith::dictionary::switchorder > 0}]} {
            set dreg "(.*?)${subset}\$"
          } else {
            set dreg "${subset}(.*?)\$"
          }
          if {[expr {$found == 0}]} {
            if {[regexp -- "^$dreg" $switch - switch]} {
              set ntype [lindex [split ${incith::dictionary::typeline}] $count]
              append n $subset
              if {![regexp -- {^((?:[0-9]{1,2}|all))-((?:[0-9]{1,2}|all))$} $switch - defs defe]} {
                if {[regexp -- {^((?:[0-9]{1,2}|all))$} $switch]} {
                  set found 1
                  if {![string match "all" $switch]} {
                    set defs $switch ; set defe [expr {$switch + ${incith::dictionary::def}-1}]
                  } else {
                    set found 1 ; set defs 1 ; set defe $::incith::dictionary::max
                  }
                } elseif {[string match "all" $ntype] && ![string length $switch]} {
                  set found 1 ; set defs 1 ; set defe $::incith::dictionary::max
                }
              } else {
                set found 1 
                if {![string length $switch]} {
                  set defs 1 ; set defe $::incith::dictionary::def
                } elseif {[string match "all" $defs]} {
                  set defs 1
                } 
                if {[string match "all" $defe]} {
                  set defe [expr {$defs + $::incith::dictionary::max}]
                }
              }
            } elseif {![string length $switch]} {
              set found 1 ; set defs 1 ; set defe ${incith::dictionary::def}
            } 
          }
        }
        incr count
      }
      if {[expr {$found == 0}] && [string length "$switch"]} {
        set input "$n$switch $input"
      }
      if {$::incith::dictionary::debug > 0} {
        regsub -nocase "%%where%%" $::incith::dictionary::display9 "$where" ds
        regsub -nocase "%%nick%%" $ds "$nick" ds
        regsub -nocase "%%fullinput%%" $ds "$di" ds
        regsub -nocase "%%type%%" $ds "$n" ds
        regsub -nocase "%%range%%" $ds "$switch" ds
        regsub -nocase "%%input%%" $ds "$input" ds
        regsub -nocase "%%start%%" $ds "$defs" ds
        regsub -nocase "%%end%%" $ds "$defe" ds
        regsub -nocase "%%last%%" $ds "$::lastbind" ds
        regsub -nocase "%%typeline%%" $ds "$ntype" ds
        putlog "$ds"
      }

      set html [fetch_html $input 1]

	if {[string match -nocase "*socketerrorabort*" $html]} {
        regsub -nocase "%%site%%" $::incith::dictionary::display6 "${incith::dictionary::webdict}[::http::formatQuery s ${input}]" ds
        if {[expr {$::incith::dictionary::extra > 0}]} {
          puthelp "notice $nick :$ds"
        } else {
          puthelp "privmsg $where :$ds"
        }
        return
	}
	if {[string match -nocase "*timeouterrorabort*" $html]} {
        regsub -nocase "%%site%%" $::incith::dictionary::display7 "${incith::dictionary::webdict}[::http::formatQuery s ${input}]" ds
        if {[expr {$::incith::dictionary::extra > 0}]} {
          puthelp "notice $nick :$ds"
        } else {
          puthelp "privmsg $where :$ds"
        }
        return
	}
	if {[string match -nocase "*redirecterrorabort*" $html]} {
        regsub -nocase "%%site%%" $::incith::dictionary::display8 "${incith::dictionary::webdict}[::http::formatQuery s ${input}]" ds
        if {[expr {$::incith::dictionary::extra > 0}]} {
          puthelp "notice $nick :$ds"
        } else {
          puthelp "privmsg $where :$ds"
        }
        return
	}

      if {[regexp -- {<h3>(.*?)</h3></body></html>} $html - reply]} {
        regsub -nocase "%%input%%" ${incith::dictionary::display5} $input ds
        regsub -nocase "%%reply%%" $ds $reply ds
        if {[expr {$::incith::dictionary::extra > 0}]} {
          puthelp "notice $nick :$ds"
        } else {
          puthelp "privmsg $where :$ds"
        }
        return
      }
      set totals [list]
      set reply [list]
      while {[regexp -- {<h3>(.*?)</h3><ul>(.*?)</ul>} $html - type line]} {
        regsub -- {<h3>.*?</h3><ul>.*?</ul>} $html "" html
        set count 1
        while {[regexp -- {<li><.*?\.(.*?)>.*?</a>(.*?)</li>} $line - attrib def]} {
          regsub -- {<li>.*?</a>.*?</li>} $line "" line
          regsub -all {<(.*?)>} $def "" def
          lappend reply [list $type $count [string totitle [string map {"." " "} $attrib]] $def]
          incr count
        }
        lappend totals [list $type [expr {$count - 1}]]
      }

      set count 0
      foreach line $reply {
        if {[string match -nocase [lindex $line 0] $ntype] || [string match $ntype "all"]} {
          if {[expr {($defs <= [lindex $line 1]) && ($defe >= [lindex $line 1])}]} {
            set totalz [lindex [lindex $totals [lsearch -glob $totals "[lindex $line 0]*"]] 1]
            regsub -nocase "%%type%%" ${incith::dictionary::display} "[lindex $line 0]" ds
            regsub -nocase "%%num%%" $ds "[lindex $line 1]" ds
            regsub -nocase "%%attrib%%" $ds "[lindex $line 2]" ds
            regsub -nocase "%%total%%" $ds "$totalz" ds
            regsub -nocase "%%def%%" $ds "[join [lrange $line 3 end]]" ds
            puthelp "privmsg $where :$ds"
            incr count
            if {[expr {$count > $::incith::dictionary::max - 1}]} {
              regsub -nocase "%%max%%" ${incith::dictionary::display1} ${incith::dictionary::max} ds
              if {[expr {$::incith::dictionary::extra > 0}]} {
                puthelp "notice $nick :$ds"
              } else {
                puthelp "privmsg $where :$ds"
              }
              break
            }
          }
        }
      }
      if {[string match $count "0"]} {
        regsub -nocase "%%input%%" ${incith::dictionary::display3} $input ds
        regsub -nocase "%%type%%" $ds $ntype ds
        regsub -nocase "%%start%%" $ds $defs ds
        regsub -nocase "%%end%%" $ds $defe ds
        if {[expr {$::incith::dictionary::extra > 0}]} {
          puthelp "notice $nick :$ds"
        } else {
          puthelp "privmsg $where :$ds"
        }
      }
      if {[expr {$::incith::dictionary::totalr > 0}]} {
        regsub -nocase "%%totals%%" ${incith::dictionary::display2} "[join $totals "; "]" ds
        regsub -nocase "%%input%%" $ds $input ds
        regsub -nocase "%%url%%" $ds "${incith::dictionary::webdict}[::http::formatQuery s ${input}]" ds
        if {[expr {$::incith::dictionary::extra > 0}]} {
          puthelp "notice $nick :$ds"
        } else {
          puthelp "privmsg $where :$ds"
        }
      }
    }
          

    # FETCH_HTML
    # fetches html
    #
    proc fetch_html {input switch} {

      # set our query properly.
      set query "${incith::dictionary::webdict}[::http::formatQuery s ${input} sub "Search WordNet" o4 1]"

      set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.7) Gecko/20070914 Firefox/2.0.0.7"
      set http [::http::config -useragent $ua]
	catch {set http [::http::geturl "$query" -timeout [expr 1000 * 20]]} error

      # site goes down, socket goes huh?
      if {[string match -nocase "*couldn't open socket*" $error]} {
        return "socketerrorabort"
      }
      if { [::http::status $http] == "timeout" } {
	  return "timeouterrorabort"
	}

      # REDIRECT ?
      set redir [::http::ncode $http]
      upvar #0 $http state
      while {[string match "*${redir}*" "302|301" ]} {
        foreach {name value} $state(meta) {
          if {[regexp -nocase ^location$ $name]} {
            if {[string match [string map {" " "%20"} $value] $query]} { return "redirecterrorabort" }
            if {![string match "http*" $value]} { set $value "[lindex [split $query] "/" 3]/$value" } 
            set http [::http::geturl "[string map {" " "%20"} $value]" -query "" -headers "Referer $query" -timeout [expr 1000 * 10]]
            if {[string match -nocase "*couldn't open socket*" $error]} {
              return "socketerrorabort"
            }
            if { [::http::status $http] == "timeout" } {
	        return "timeouterrorabort"
            }
            set redir [::http::ncode $http]
            set query [string map {" " "%20"} $value]
            upvar #0 $http state
          }
        } 
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
      regsub -all "(?:\n|\t|\r|\v)" $html "" html
      regsub -all "(?:<b>|</b>)" $html "\002" html

      return $html
    }

    # PUBLIC_MESSAGE
    # decides what to do with binds that get triggered
    #
    proc public_message {nick uhand hand chan input} {
      if {[lsearch -exact [channel info $chan] +dictionary] != -1} {
        # flood protection check
        if {[flood $nick $uhand]} {
          return
        }
        send_output $input $chan $nick
      }
    }

    # PRIVATE_MESSAGE
    # decides what to do with binds that get triggered
    #
    proc private_message {nick uhand hand input} {
      if {[expr {$incith::dictionary::private_messages >= 1}]} {
        # flood protection check
        if {[flood $nick $uhand]} {
          return
        }
	send_output $input $nick $nick
      }
    }
  }
}

# support routines
namespace eval incith {
  namespace eval dictionary {
    # SEND_OUTPUT
    # no point having two copies of this in public/private_message{}
    #
    proc send_output {input where nick} {
      foreach line [incith::dictionary::parse_output [dictionary $where $nick $input]] {
        putquick "PRIVMSG $where :$line"
      }
    }

    # PARSE_OUTPUT
    # prepares output for sending to a channel/user, calls line_wrap
    #
    proc parse_output {input} {
      set parsed_output [set parsed_current {}]
      foreach line [incith::dictionary::line_wrap $input] {
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
      set len $incith::dictionary::split_length
      regsub -all "\002" $str "<ZQ" str
      regsub -all "\037" $str "<ZX" str
      foreach word [split [set str][set str ""] $splitChr] { 
        if {[expr {[incr i [string len $word]] > $len}]} { 
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
      if {[expr {$incith::dictionary::ignore < 1}]} {
        return 0
      }
      if {![string match *:* $incith::dictionary::flood]} {
        putlog "$incith::dictionary::version: variable flood not set correctly."
        return 1
      }
      set incith::dictionary::flood_data(flood_num) [lindex [split $incith::dictionary::flood :] 0]
      set incith::dictionary::flood_data(flood_time) [lindex [split $incith::dictionary::flood :] 1]
      set i [expr $incith::dictionary::flood_data(flood_num) - 1]
      while {[expr {$i >= 0}]} {
        set incith::dictionary::flood_array($i) 0
        incr i -1
      }
    }
    ; flood_init

    # FLOOD
    # updates a nd returns a users flood status
    #
    proc flood {nick uhand} {
      if {[expr {$incith::dictionary::ignore < 1}]} {
        return 0
      }
      if {[expr {$incith::dictionary::flood_data(flood_num) == 0}]} {
        return 0
      }
      set i [expr ${incith::dictionary::flood_data(flood_num)} - 1]
      while {[expr {$i >= 1}]} {
        set incith::dictionary::flood_array($i) $incith::dictionary::flood_array([expr $i - 1])
        incr i -1
      }
      set incith::dictionary::flood_array(0) [unixtime]
      if {[expr [unixtime] - $incith::dictionary::flood_array([expr ${incith::dictionary::flood_data(flood_num)} - 1])] <= ${incith::dictionary::flood_data(flood_time)}} {
        putlog "$incith::dictionary::version: flood detected from ${nick}."
        putserv "notice $nick :$incith::dictionary::version: flood detected, placing you on ignore for $::incith::dictionary::ignore minute(s)! :P"
        newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::dictionary::version flooding $incith::dictionary::ignore
        return 1
      } else {
        return 0
      }
    }
  }
}

putlog " - $incith::dictionary::version loaded."

# EOF
