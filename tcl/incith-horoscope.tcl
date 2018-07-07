#---------------------------------------------------------------------#
# incith:horoscope                                               v3.3 #
#                                                                     #
# fetches daily horoscope from feeds.astrology.com                    #
# tested on Eggdrop & Windrop v1.6.19                                 #
#                                                                     #
# Usage:                                                              #
#   .chanset #channel +horoscope                                      #
#   !horoscope <zodiac/chinese sign>                                  #
#   !<zodiac/chinese sign>, if enabled                                #
#                                                                     #
# ChangeLog:                                                          #
#   3.3: Add flood protection w/ignore like all incith scripts have   #
#   3.2: Made the script work with the rss feeds & fixed goat error   #
#        -- Trixar_za                                                 #
#   3.1: fix for signs beginning with "s" not working                 #
#   3.0: script updated.                                              #
#                                                                     #
# Contact:                                                            #
#   E-mail (incith@gmail.com) cleanups, ideas, bugs, etc., to me.     #
#                                                                     #
# TODO:                                                               #
#   - flood protection                                                #
#   - max length variable for output, to prevent HTML floods          #
#                                                                     #
# LICENSE:                                                            #
#   This code comes with ABSOLUTELY NO WARRANTY.                      #
#                                                                     #
#   This program is free software; you can redistribute it and/or     #
#   modify it under the terms of the GNU General Public License as    #
#   published by the Free Software Foundation; either version 2 of    #
#   the License, or (at your option) any later version.               #
#   later version.                                                    #
#                                                                     #
#   This program is distributed in the hope that it will be useful,   #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of    #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.              #
#                                                                     #
#   See the GNU General Public License for more details.              #
#   (http://www.gnu.org/copyleft/library.txt)                         #
#                                                                     #
# Copyleft (C) 2005-09, Jordan                                        #
# http://incith.com ~ incith@gmail.com ~ irc.freenode.net/#incith     #
#---------------------------------------------------------------------#
package require http 2.3
setudef flag horoscope

namespace eval incith::horoscope {
  # the bind prefix/command char(s) {!} or {! .} etc, seperate with space)
  variable command_chars {! .}

  # binds {one two three}
  variable binds {horo zodiac}

  # bind each of the signs? (!virgo, !rat, etc)
  variable bind_signs 1

  # allow binds to be used in /msg's to the bot?
  variable private_messages 1

  # send public/channel output to the user instead?
  variable public_to_private 0

  # send replies as notices instead of private messages?
  variable notices 0

  # only send script 'errors' as notices? (not enough/invalid input etc)
  variable notice_errors_only 0

  # make use of bolding where appropriate?
  variable bold 1

  # maximum length of a reply before breaking it up
  variable split_length 440

  # if you're using a proxy, enter it here {hostname.com:3128}
  variable proxy {}

  # how long (in seconds) before the http request times out?
  variable timeout 30

  # use the callback function for non-blocking http fetches?
  # note: your eggdrop must be patched or else this will slow
  # lookups down a lot and even break some things.
  variable callback 0

  # number of minute(s) to ignore flooders, 0 to disable flood protection
  variable ignore 1

  # how many requests in how many seconds is considered flooding?
  # by default, this allows 3 queries in 10 seconds, the 4th being ignored
  # and ignoring the flooder for 'variable ignore' minutes
  variable flood 4:10
}

# script begings
namespace eval incith::horoscope {
  variable version "incith:horoscope-3.3"
  variable en_english "capricorn aquarius pisces aries taurus gemini cancer leo virgo libra scorpio sagittarius"
  variable en_chinese "rat ox tiger rabbit dragon snake horse goat ram sheep monkey rooster dog pig"
  variable en_signs "$en_english $en_chinese"
  variable debug 0
  array set static {}
}

# bind the binds
foreach command_char [split ${incith::horoscope::command_chars} " "] {
  foreach bind [split ${incith::horoscope::binds} " "] {
    # public message binds
    bind pub -|- "${command_char}${bind}" incith::horoscope::message_handler

    # private message binds
    if {${incith::horoscope::private_messages} >= 1} {
      bind msg -|- "${command_char}${bind}" incith::horoscope::message_handler
    }
  }
}

# bind each of the signs
if {${incith::horoscope::bind_signs} >= 1} {
  foreach command_char [split ${incith::horoscope::command_chars} " "] {
    foreach sign [split ${incith::horoscope::en_signs} " "] {
      bind pubm -|- "*${command_char}${sign}" incith::horoscope::message_handler
      if {${incith::horoscope::private_messages} >= 1} {
        bind msgm -|- "*${command_char}${sign}" incith::horoscope::message_handler
      }
    }
  }
}

namespace eval incith::horoscope {
  # [message_handler] : handles public & private messages
  #
  proc message_handler {nick uhand hand args} {
    # flood protection check
    if {[flood $nick $uhand]} {
      return
    }
    set input(who) $nick
    if {[llength $args] >= 2} { # public message
      set input(where) [lindex $args 0]
      if {${incith::horoscope::public_to_private} >= 1} {
        set input(chan) $input(who)
      } else {
        set input(chan) $input(where)
      }
      set input(query) [lindex $args 1]
      if {[channel get $input(where) horoscope] != 1} {
        return
      }
    } else {                    # private message
      set input(where) "private"
      set input(chan) $input(who)
      set input(query) [lindex $args 0]
      if {${incith::horoscope::private_messages} <= 0} {
        return
      }
    }

    # log it
    ipl $input(who) $input(where) $input(query)

    # do some cleanup
    # remove the command char if present
    foreach command_char [split ${incith::horoscope::command_chars} " "] {
      if {[string match "*${command_char}*" $input(query)]} {
        regsub -- "\\s*${command_char}\\s*" $input(query) {} input(query)
        break
      }
    }
    # ram or goat becomes sheep
    if {$input(query) == "ram" || $input(query) == "sheep"} {
      set input(query) "goat"
    }
    # check for valid sign
    set valid_sign 0
    foreach sign [split ${incith::horoscope::en_signs} " "] {
      if {$input(query) == $sign} {
        set valid_sign 1
        break
      }
    }
    # invalid, send a message and return
    if {$valid_sign <= 0} {
      send_output $input(chan) "Invalid sign '$input(query)'." $input(who)
      return
    }
    # valid, set our url
    set input(url) "http://www.astrology.com/horoscopes/daily-horoscope.rss"
    foreach sign [split ${incith::horoscope::en_chinese} " "] {
      if {$input(query) == $sign} {
        set input(url) "http://www.astrology.com/horoscopes/daily-chinese.rss"
        break
      }
    }

    # fetch the html
    fetch_html [array get input]
  }

  # [flood_init]
  # modified from bseen
  #
  variable flood_data
  variable flood_array
  proc flood_init {} {
    if {$incith::horoscope::ignore < 1} {
      return 0
    }
    if {![string match *:* $incith::horoscope::flood]} {
      putlog "$incith::horoscope::version: variable flood not set correctly."
      return 1
    }
    set incith::horoscope::flood_data(flood_num) [lindex [split $incith::horoscope::flood :] 0]
    set incith::horoscope::flood_data(flood_time) [lindex [split $incith::horoscope::flood :] 1]
    set i [expr $incith::horoscope::flood_data(flood_num) - 1]
    while {$i >= 0} {
      set incith::horoscope::flood_array($i) 0
      incr i -1
    }
  }
  ; flood_init

  # [flood]
  # updates and returns a users flood status
  #
  proc flood {nick uhand} {
    if {$incith::horoscope::ignore < 1} {
      return 0
    }
    if {$incith::horoscope::flood_data(flood_num) == 0} {
      return 0
    }
    set i [expr ${incith::horoscope::flood_data(flood_num)} - 1]
    while {$i >= 1} {
      set incith::horoscope::flood_array($i) $incith::horoscope::flood_array([expr $i - 1])
      incr i -1
    }
    set incith::horoscope::flood_array(0) [unixtime]
    if {[expr [unixtime] - $incith::horoscope::flood_array([expr ${incith::horoscope::flood_data(flood_num)} - 1])] <= ${incith::horoscope::flood_data(flood_time)}} {
      putlog "$incith::horoscope::version: flood detected from ${nick}."
      putserv "notice $nick :$incith::horoscope::version: flood detected, placing you on ignore for $::incith::horoscope::ignore minute(s)! :P"
      newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::horoscope::version flooding $incith::horoscope::ignore
      return 1
    } else {
      return 0
    }
  }

  # [fetch_html] : fetch html of a given url
  #
  proc fetch_html {tmpInput} {
    upvar #0 incith::horoscope::static static
    array set input $tmpInput

    # setup the timeout, for use below
    set timeout [expr round(1000 * ${incith::horoscope::timeout})]
    # setup proxy information, if any
    if {[string match {*:*} ${incith::horoscope::proxy}] == 1} {
      set proxy_info [split ${incith::horoscope::proxy} ":"]
    }
    # the "browser" we are using
    # NT 5.1 - XP, NT 6.0 - Vista
    set ua "Opera/9.63 (Windows NT 6.0; U; en)"
    if {[info exists proxy_info] == 1} {
      ::http::config -useragent $ua -proxyhost [lindex $proxy_info 0] -proxyport [lindex $proxy_info 1]
    } else {
      ::http::config -useragent $ua
    }
    # retrieve the html
    if {$incith::horoscope::callback >= 1} {
      catch {set token [::http::geturl "$input(url)" -command incith::horoscope::httpCommand -timeout $timeout]} output(status)
    } else {
      catch {set token [::http::geturl "$input(url)" -timeout $timeout]} output(status)
    }
    # need to check for some errors here:
    if {[string match "couldn't open socket: host is unreachable*" $output(status)]} {
      send_output $input(chan) "Unknown host '${input(query)}'." $input(who)
      return
    }
    # no errors, move on:
    set static($token,input) [array get input]
    # manually call our callback procedure if we're not using callbacks
    if {$incith::horoscope::callback <= 0} {
      httpCommand $token
    }
  }


  # [httpCommand] : makes sure the http request succeeded
  #
  proc httpCommand {token} {
    upvar #0 $token state
    upvar #0 incith::horoscope::static static
    # build the output array
    array set output $static($token,input)

    switch -exact [::http::status $token] {
      "timeout" {
        if {$incith::horoscope::debug >= 1} {
          ipl $output(who) $output(where) "status = timeout (url = $state(url))"
        }
        set output(error) "Operation timed out after ${incith::horoscope::timeout} seconds."
      }
      "error" {
        if {$incith::horoscope::debug >= 1} {
          ipl $output(who) $output(where) "status = error([::http::error $token]) (url = $state(url))"
        }
        set output(error) "An unknown error occurred. (Error #01)"
      }
      "ok" {
        switch -glob [::http::ncode $token] {
          3* {
            array set meta $state(meta)
            if {$incith::horoscope::debug >= 1} {
              ipl $output(who) $output(where) "redirecting to $meta(Location)"
            }
            set output(url) $meta(Location)
            # fetch_html $output(where) $output(who) $output(where) $meta(Location)
            fetch_html [array get output]
            return
          }
          200 {
            if {$incith::horoscope::debug >= 1} {
              ipl $output(who) $output(where) "parsing $state(url)"
            }
          }
          default {
            if {$incith::horoscope::debug >= 1} {
              ipl $output(who) $output(where) "status = default, error"
            }
            set output(error) "An unknown error occurred. (Error #02)"
          }
        }
      }
      default {
        if {$incith::horoscope::debug >= 1} {
          ipl $output(who) $output(where) "status = unknown, default, error"
        }
        set output(error) "An unknown error occurred. (Error #03)"
      }
    }
    set static($token,output) [array get output]
    process_html $token
  }


  # [process_html] :
  #
  proc process_html {token} {
    upvar #0 $token state
    upvar #0 incith::horoscope::static static
    array set output $static($token,output)

    # get the html
    set html $state(body)

    # store the HTML to a file
    if {$incith::horoscope::debug >= 1} {
      set fopen [open incith-horoscope.html w]
      puts $fopen $html
      close $fopen
    }

    # html cleanups
    regsub -all {\n} $html {} html
    regsub -all {\t} $html {} html
    regsub -all {&nbsp;} $html { } html
    regsub -all {&gt;} $html {>} html
    regsub -all {&lt;} $html {<} html
    regsub -all {&amp;} $html {\&} html
    regsub -all {&times;} $html {*} html
    regsub -all {(?:\x91|\x92|&#39;)} $html {'} html
    regsub -all {(?:\x93|\x94|&quot;)} $html {"} html
    regsub -all {&#215;} $html {x} html
    regsub -all {(?:<!\[CDATA\[)} $html {} html

    # html parsing
    #
    # fetch the sign and the horoscope
    set output(sign) [string totitle $output(query)]
    set regex "<title>$output(sign) (.*?)</title>.+<description><p>(.*?)</p>"
    regexp $regex $html - junk output(horoscope)

    # check for errors
    if {![info exists output(horoscope)]} {
      set output(error) "Error while attempting to fetch the horoscope."
    } else {
      # remove trailing spaces
      set output(horoscope) [string trimright $output(horoscope)]
    }
    if {![info exists output(sign)]} {
      set output(sign) $output(query)
    }
    # convert sign to Sign/proper case
    set output(sign) [string totitle $output(sign)]

    # process the output array
    set static($token,output) [array get output]
    process_output $token
    # return 1 here as we took care of the message
    return 1
  }


  # [process_output] : create the output and send it
  #
  proc process_output {token} {
    upvar #0 $token state
    upvar #0 incith::horoscope::static static
    array set output $static($token,output)

    # check for errors
    if {[info exists output(error)]} {
      send_output $output(chan) $output(error) $output(who)
      return
    }

    # send the result
    send_output $output(chan) "[ibold "${output(sign)}:"] $output(horoscope)"

    # clean the static array for this http session
    foreach value [array get static] {
      if {[info exists static($value)]} {
        if {[string match *${token}* $value]} {
          unset static($value)
        }
      }
    }
  }


  # [ipl] : a putlog procedure
  #
  proc ipl {who {where {}} {what {}}} {
    if {$where == "" && $what == ""} {
      # first argument only = data only
      putlog "${incith::horoscope::version}: ${who}"
    } elseif {$where != "" && $what == ""} {
      # two arguments = who and data
      putlog "${incith::horoscope::version}: <${who}> ${where}"
    } else {
      # all three...
      putlog "${incith::horoscope::version}: <${who}/${where}> ${what}"
    }
  }


  # [send_output] : sends $data appropriately out to $where
  #
  proc send_output {where data {isErrorNick {}}} {
    if {${incith::horoscope::notices} >= 1} {
      foreach line [incith::horoscope::line_wrap $data] {
        putquick "NOTICE $where :${line}"
      }
    } elseif {${incith::horoscope::notice_errors_only} >= 1 && $isErrorNick != ""} {
      foreach line [incith::horoscope::line_wrap $data] {
        putquick "NOTICE $isErrorNick :${line}"
      }
    } else {
      foreach line [incith::horoscope::line_wrap $data] {
        putquick "PRIVMSG $where :${line}"
      }
    }
  }


  # [line_wrap] : takes a long line in, and chops it before the specified length
  # http://forum.egghelp.org/viewtopic.php?t=6690
  #
  proc line_wrap {str {splitChr { }}} {
    set out [set cur {}]
    set i 0
    set len $incith::horoscope::split_length
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


  # [ibold] : bolds some text, if bolding is enabled
  #
  proc ibold {input} {
    if {${incith::horoscope::bold} >= 1} {
      return "\002${input}\002"
    }
    return $input
  }


  # [iul] : underlines some text, if underlining is enabled
  #
  proc iul {input} {
    if {${incith::horoscope::underline} >= 1} {
      return "\037${input}\037"
    }
    return $input
  }
}

# the script has loaded.
incith::horoscope::ipl "loaded."

# EOF



