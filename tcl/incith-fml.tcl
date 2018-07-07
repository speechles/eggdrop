#---------------------------------------------------------------#
# incith:fml                                               v1.2 #
#                                                               #
# FFFFFFFFFFFFFFFFF   MMMM          MMMM   LLLL                 #
# FFFF                MMMMM        MMMMM   LLLL                 #
# FFFF                MMMMMM      MMMMMM   LLLL                 #
# FFFFFFFFFFFFFFFFF   MMMMMMM    MMMMMMM   LLLL                 #
# FFFF                MMMMMMMMMMMMMMMMMM   LLLL                 #
# FFFF                MMMM MMMMMMMM MMMM   LLLL                 #
# FFFF                MMMM  MMMMMM  MMMM   LLLL                 #
# FFFF                MMMM   MMMM   MMMM   LLLLLLLLLLLLLLLLL    #
#                                                               #
# This script basically scrapes www.fmylife.com and             #
# returns relevant information to irc.                          #
#                                                               #
# Usage:                                                        #
#   enable query in channel:                                    #
#   .chanset #channel +fml                                      #
#                                                               #
#   enable automation in channel:                               #
#   .chanset #channel +fmlauto                                  #
#                                                               #
#   to query:                                                   #
#   !fml [<search terms>] [-<category>] [<range>] [-<page>]     #
#                                                               #
# ChangeLog:                                                    #
#    v1.0 - first release, enjoy.. :)                           #
#    v1.1 - add automatic system                                #
#           add today/fml stripping                             #
#           add full/single display output                      #
#           add better error handlers                           #
#    v1.2 - add search ability                                  #
#           add cookie keeping (5 min reset interval)           #
#           add bolding of search terms                         #
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
# Copyleft (C) 2011, speechles                                  #
# imspeechless@gmail.com                                        #
#---------------------------------------------------------------#
package require http 2.3
setudef flag fml
setudef flag fmlauto

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
	namespace eval fml {
		# set this to the command character you want to use for the binds
		variable command_char "!"

		# set these to your preferred binds ("one two")
		variable binds "fml fmyl fuckmylife"

		# set this to your default category
		# 1 - love
		# 2 - money
		# 3 - kids
		# 4 - work
		# 5 - health
		# 6 - intimacy
		# 7 - miscellaneous
		# 8 - random
		# 9 - search
		# 10 - animals
		variable default 8

		# if you want to allow users to search via /msg, enable this
		variable private_messages 1

		# ** this is not an optional setting, if a string is too long to send, it won't be sent! **
		# It should be set to the max amount of characters that will be received in a public
		#   message by your IRC server.  If you find you aren't receiving results, try lowering this.
		variable split_length 440

		# set your default amount, and maximum amount to show.
		variable def 1
		variable max 5

		# Set the timestring to automate requests here when channel is set +fmlauto
		# default is every 5 minutes.
		variable timestring [list "?0*" "?5*"]

		# set the arguments to pass for automated requests. To use the default action
		# as if a user types simply !fml with no arguments, use "" here
		variable autoarg ""

		# Which version to display:
		# 0 - short - just the FML line
		# 1 - long - FML line + all that extra crap
		variable display 0

		# Strip "Today," at front.
		# (0 no/1 yes)
		variable striptoday 1

		# Strip "FML" at end.
		# (0 no/1 yes)
		variable stripfml 1

		# Bold search results, when using fml to search words?
		# (0 no/1 yes)
		variable bold 1

		# number of minute(s) to ignore flooders, 0 to disable flood protection
		variable ignore 1

		# how many requests in how many seconds is considered flooding?
		# by default, this allows 10 queries in 60 seconds, the 11th being ignored
		# and ignoring the flooder for 'variable ignore' minutes
		variable flood 60:60
	}
}

bind pub - !fmlcrumble fmlcrumble
bind pub - !fmlcookie fmlcookie

proc fmlcrumble {nick uhost handle chan text} {
	if {![channel get $chan fml]} { return }
	global FMLCookie
	if {![info exists FMLCookie]} { putserv "privmsg $chan :\002FML\002: Cookie does not exist." ; return }
	putserv "privmsg $chan :\002FML\002: Crumbling \"[join $::FMLCookie {;}]\"."
	unset FMLCookie ""
}

proc fmlcookie {nick uhost handle chan text} {
	if {![channel get $chan fml]} { return }
	global FMLCookie
	if {[info exists  FMLCookie]} {
		if {[llength $FMLCookie]} {
			putserv "privmsg $chan :\002FML\002: Cookie \"[join $::FMLCookie {;}]\"."
		} else {
			putserv "privmsg $chan :\002FML\002: Cookie is empty."
		}
	} else {
		putserv "privmsg $chan :\002FML\002: Cookie does not exist."
	}
}

# initialize cookies every 5 minutes, use this to tell if timer is already running
if {![info exists fmltimer]} {
	set fmltimer 1
	timer 5 fml_cookie_timer
}
if {![info exists FMLCookie]} {
	set FMLCookie ""
}

# recursive timer to kill fml cookies every 5 minutes.
proc fml_cookie_timer {args} {
	if {[info exists ::incith::fml::active]} {
		unset ::incith::fml::active
		timer 5 fml_cookie_timer
	} else {
		timer 5 fml_cookie_timer
		set FMLCookie ""
	}
}

# end of configuration, script begins
namespace eval incith {
	namespace eval fml {
		variable version "incith:fml-1.2"
	}
}

# attach time binds to the timestring list
# which will call the procedure below
foreach bind $::incith::fml::timestring {
	bind time - "$bind" ::incith::fml::timer
}

# bind the public binds
foreach bind [split $incith::fml::binds " "] {
	bind pub -|- "${incith::fml::command_char}$bind" incith::fml::public_message
}

# bind the private message binds, if wanted
if {$incith::fml::private_messages >= 1} {
	foreach bind [split $incith::fml::binds " "] {
		bind msg -|- "${incith::fml::command_char}$bind" incith::fml::private_message
	}
}

namespace eval incith {
	namespace eval fml {
		proc fml {input where} {
			set ::incith::fml::active 1
			set type $::incith::fml::default ; set defs 1 ; set defe 1 ; set page 0
			if {[regexp -- {-page ([0-9])} $input - page]} { regsub -- {-page [0-9]} $input "" input }
			if {[regsub -- {-love} $input "" input]} { set type 1 }
			if {[regsub -- {-money} $input "" input]} { set type 2 }
			if {[regsub -- {-kids} $input "" input]} { set type 3 }
			if {[regsub -- {-work} $input "" input]} { set type 4 }
			if {[regsub -- {-health} $input "" input]} { set type 5 }
			if {[regsub -- {-intimacy} $input "" input]} { set type 6 }
			if {[regsub -- {-misc} $input "" input]} { set type 7 }
			if {[regsub -- {-random} $input "" input]} { set type 8 }
			if {[regsub -- {-animals} $input "" input]} { set type 10 }
			if {![regexp -- {([0-9]{1,2})-([0-9]{1,2})} $input - defs defe]} {
				if {[regexp -- {([0-9]{1,2})} $input - digit]} {
					regsub -- {([0-9]{1,2})} $input {} input
					if {![string match "all" $input]} {
						set defs $digit ; set defe [expr {$digit + ${incith::fml::def}-1}]
					} else {
						set defs 1 ; set defe $::incith::fml::max
					}
				} elseif {![string length $input]} {
					set defs 1 ; set defe $::incith::fml::def
				}
			} else {
				regsub -- {([0-9]{1,2})-([0-9]{1,2})} $input {} input
				if {[string match "all" $defs]} {
					set defs 1
				}
				if {[string match "all" $defe]} {
					set defe [expr {$defs + $::incith::fml::max}]
				}
			}
			set input [string trim $input]
			if {[string length $input]} { set type 9 }
			if {$defs > 15 || $defe > 15 || $defs < 0 || $defe < 0} { putserv "privmsg $where :Bad range ($defs - $defe). Select a range from 1 thru 15!" ; return }
			set html [fetch_html $input $type $page]
			# standard fetch_html error catcher
			if {[string match -nocase "*socketerrorabort*" $html]} {
				regsub {(.+?)\|} $html {} html
				return "FML: Socket Error accessing '${html}' .. Does it exist?"
			}
			if {[string match -nocase "*timeouterrorabort*" $html]} {
				return "FML: Connection has timed out..."
			}
			set output [list] ; set count 1
			set file [open "shitfuck.txt" w] ; puts $file $html ; close $file
			set capture [regexp -all -inline {<div class="post article.*?>(.*?)</span></div>} $html]
			putlog "capture is $capture"
			foreach {junk entry} $capture {
				regexp -- {^.*?<a href="(.*?)"} $entry - link
				regsub -all {<span class="dyn-vote-j".*?>} $entry " " entry
				regsub {</p>} $entry "|" entry
				regsub -all {</p>} $entry " - " entry
				regsub -all {<.*?>} $entry "" entry
				lappend output "$count $entry www.fmylife.com$link"
				incr count
				if {$count > 20} { break }
			}

			set count 1
			foreach line $output {
				if {[expr {($defs <= [lindex [split $line] 0]) && ($defe >= [lindex [split $line] 0])}]} {
					set out "[string trim [join [lrange [split $line] 1 end-1]]] @ [set link [lindex [split $line] end]] (page $page/entry [expr {$defs + $count - 1}])"
					set front [string trim [lindex [split $out "|"] 0]]
					if {$::incith::fml::striptoday > 0} {
						set front "[string totitle [string index [string trim [string range $front 7 end]] 0]][string range [string trim [string range $front 7 end]] 1 end]"
					}
					if {$::incith::fml::stripfml > 0 } {
						set front [string range $front 0 end-4]
					}
					#if {$::incith::fml::bold > 0} {
					#	foreach word $input {
					#	  set front [string map [list "[string totitle $word]" "\002[string totitle $word]\002"] $front]
					#   set front [string map [list "[string toupper $word]" "\002[string toupper $word]\002"] $front]
					#   set front [string map [list "[string tolower $word]" "\002[string tolower $word]\002"] $front]
					# }
					#}
					#set newfront [string tolower $front]
					#set pos 0
					#while {[set pos [string first [string tolower $input] $newfront $pos]] != -1} {
					#	 set front "[string range $front 0 [expr {$pos -1}]]\037\002[string range $front $pos [expr {$pos + [string length $input] -1}]]\037\002[string range $front [expr {$pos + [string length $input]}] end]"
					#	 set newfront [string range $newfront [expr {$pos+1}] end]
					#	 incr pos
					#}
					#set front [string map [list "[string totitle $input]" "\037\002[string totitle $input]\037\002"] $front]
					#set front [string map [list "[string toupper $input]" "\037\002[string toupper $input]\037\002"] $front]
					#set front [string map [list "[string tolower $input]" "\037\002[string tolower $input]\037\002"] $front]
					if {$type == 9} {
						set safe_input [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] $input]
						regsub -nocase -all -- $safe_input $front "\002\037&\037\002\017" front
					}
					if {[string length [set out "$front|[join [lrange [split $out "|"] 1 end] "|"]"]]} { set shown 1 }
					if {$::incith::fml::display >0 } {
						foreach l [split $out "|"] {
							putserv "privmsg $where :$l"
						}
					} else {
						putserv "privmsg $where :[lindex [split $out "|"] 0]"
					}
					incr count
					if {[expr {$count > $::incith::fml::max}]} {
						break
					}
				}
			}
			if {![info exists shown]} {
				if {$page > 0} { set pages " on page $page" } { set pages "" }
				if {[llength $output] > 1 } {
					putserv "privmsg $where :There are only [llength $output] fml's available for \"$input\"$pages"
				} elseif {[llength $output] == 1} {
					putserv "privmsg $where :There is only 1 fml for \"$input\"$pages."
				} else {
					putserv "privmsg $where :There are no fml's at all for \"$input\"$pages."
				}
			}
		}

		# invoke automatic fml, using default manner with privmsg
		proc timer {args} {
			foreach chan [channels] {
				if {[channel get $chan fmlauto]} {
					::incith::fml::fml $::incith::fml::autoarg $chan
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
		proc fetch_html {input type page} {
			global FMLCookie
			set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
			set http [::http::config -useragent $ua] ; set url "" ; set fullquery ""
			if ([string match *$type* "|8|9|"]} {
			incr type -1
		}
		switch -- $type {
			1 { set query "http://www.fmylife.com/love?page=$page" }
			2 { set query "http://www.fmylife.com/money?page=$page" }
			3 { set query "http://www.fmylife.com/kids?page=$page" }
			4 { set query "http://www.fmylife.com/work?page=$page" }
			5 { set query "http://www.fmylife.com/health?page=$page" }
			6 { set query "http://www.fmylife.com/intimacy?page=$page" }
			7 { set query "http://www.fmylife.com/miscellaneous?page=$page" }
			8 { set query "http://www.fmylife.com/random?page=$page" }
			9 {
				set url "http://www.fmylife.com/apps/search.php"
				#set url "http://www.fmylife.com/search/advanced"
				set query "type=article&auteur=&texte=[::http::formatQuery [string trim $input]]&categ=&option=all&order=date&submit=Search%20for%20FMLs"
				set fullquery "$url\?$query"
			}
			10 { set query "http://www.fmylife.com/animals?page=$page" }
		}
		if {$type != 9 } {
			if {[info exists FMLCookie] && [string length $FMLCookie]} {
				catch {set http [::http::geturl "$query" -headers "[string trim "Referer $query"] Cookie [join $FMLCookie {;}]" -timeout [expr 1000 * 15]]} error
			} else {
				catch {set http [::http::geturl "$query" -timeout [expr 1000 * 15]]} error
			}
		} else {
			if {[info exists FMLCookie] && [string length $FMLCookie]} {
				catch {set http [::http::geturl "$url" -query $query -headers "[string trim "Referer $url"] Cookie [join $FMLCookie {;}]" -timeout [expr 1000 * 15]]} error
			} else {
				catch {set http [::http::geturl "$url" -query $query -timeout [expr 1000 * 15]]} error
			}
		}
		if {[string match -nocase "*couldn't open socket*" $error]} {
			return "socketerrorabort|${query}"
		}
		if { [::http::status $http] == "timeout" } {
			return "timeouterrorabort"
		}
		set html [::http::data $http]
		#if {![string equal -nocase "utf-8" [encoding system]]} { set html [encoding convertto "utf-8" $html] }
		upvar #0 $http state
		set redir [::http::ncode $http]
		# iterate through the meta array
		foreach {name value} $state(meta) {
			# do we have cookies?
			if {[string equal -nocase $name "Set-Cookie"]} {
				# yes, add them to cookie list
				lappend FMLCookies [lindex [split $value {;}] 0]
			}
		}
		if {[string length $FMLCookies]} { set FMLCookie $FMLCookies }
		if {$type != 9} {
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
			regsub -all {(?:<b>|</b>)} $html "\002" html
			::http::cleanup $http
			return $html
		} else {
			if {[info exists FMLCookies] && [llength $FMLCookies]} {
				set cookies "[join $FMLCookies {;}]" ; set FMLCookie $cookies
			} else {
				set cookies ""
			}
			# REDIRECT ?
			set r 0
			while {[string match "*${redir}*" "307|303|302|301"]} {
				foreach {name value} $state(meta) {
					if {[regexp -nocase ^location$ $name]} {
						if {![string match "http*" $value]} {
							if {![string match "/" [string index $value 0]]} {
								set value "[join [lrange [split $url "/"] 0 2] "/"]/$value"
							} else {
								set value "[join [lrange [split $url "/"] 0 2] "/"]$value"
							}
						}
						::http::cleanup $http
						if {[string match [string map {" " "%20"} $value] $url]} {
							if {![info exists poison]} {
								set poison 1
							} else {
								incr poison
								if {$poison > 2} {
									return "socketerrorabort|redirect nested too deep to same location > 2"
								}
							}
						}
						if {$page != 0} {
							set a [lindex [split $value \?] 0]
							set b [lindex [split $value \?] 1]
							set value "$a?page=$page&$b"
						}
						set http [::http::config -useragent "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"]
						if {[string length $cookies]} {
							catch {set http [::http::geturl "[string map {" " "%20"} $value]" -headers "[string trim "Referer $url"] Cookie $cookies" -timeout [expr 1000 * 20]]} error
						} else {
							catch {set http [::http::geturl "[string map {" " "%20"} $value]" -headers "[string trim "Referer $url"]" -timeout [expr 1000 * 20]]} error
						}
						if {![string match -nocase "::http::*" $error]} {
							return "socketerrorabort|$error"
						}
						if {![string equal -nocase [set err [::http::status $http]] "ok"]} {
							::http::cleanup $http
							return "socketerrorabort|$err"
						}
						set redir [::http::ncode $http]
						set url [string map {" " "%20"} $value]
						set html [::http::data $http]
						if {![string equal -nocase "utf-8" [encoding system]]} { set html [encoding convertto "utf-8" $html] }
						upvar #0 $http state
						if {[incr r] > 10} { return "socketerrorabort|redirect nested too deep > 10" }
						# iterate through the meta array
						set FMLCookies [list]
						foreach {n v} $state(meta) {
							# do we have cookies?
							if {[string equal -nocase $n "Set-Cookie"]} {
								# yes, add them to cookie list
								lappend FMLCookies [lindex [split $v {;}] 0]
							}
						}
						if {[info exists FMLCookies] && [llength $FMLCookies]} {
							set cookies "[join $FMLCookies {;}]" ; set FMLCookie $cookies
						}
					}
				}
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
			regsub -all {(?:\n|\r|\t|\v)} $html "" html
			regsub -all {(?:<b>|</b>)} $html "\002" html
			return $html

		}
	}

	# PUBLIC_MESSAGE
	# decides what to do with binds that get triggered
	#
	proc public_message {nick uhand hand chan input} {
		if {[lsearch -exact [channel info $chan] +fml] != -1} {
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
		if {$incith::fml::private_messages >= 1} {
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
	namespace eval fml {
		# SEND_OUTPUT
		# no point having two copies of this in public/private_message{}
		#
		proc send_output {input where} {
			foreach line [incith::fml::parse_output [fml $input $where]] {
				foreach section [split $line "\n"] {
					putserv "PRIVMSG $where :$section"
				}
			}
		}

		# PARSE_OUTPUT
		# prepares output for sending to a channel/user, calls line_wrap
		#
		proc parse_output {input} {
			set parsed_output "" ; set parsed_current "" ; set lastline "" ; set fix ""
			foreach line [incith::fml::line_wrap $input] {
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
			set len $incith::fml::split_length
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
			if {$incith::fml::ignore < 1} {
				return 0
			}
			if {![string match *:* $incith::fml::flood]} {
				putlog "$incith::fml::version: variable flood not set correctly."
				return 1
			}
			set incith::fml::flood_data(flood_num) [lindex [split $incith::fml::flood :] 0]
			set incith::fml::flood_data(flood_time) [lindex [split $incith::fml::flood :] 1]
			set i [expr $incith::fml::flood_data(flood_num) - 1]
			while {$i >= 0} {
				set incith::fml::flood_array($i) 0
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
			if {$incith::fml::ignore < 1} {
				return 0
			}
			if {$incith::fml::flood_data(flood_num) == 0} {
				return 0
			}
			set i [expr ${incith::fml::flood_data(flood_num)} - 1]
			while {$i >= 1} {
				set incith::fml::flood_array($i) $incith::fml::flood_array([expr $i - 1])
				incr i -1
			}
			set incith::fml::flood_array(0) [unixtime]
			if {[expr [unixtime] - $incith::fml::flood_array([expr ${incith::fml::flood_data(flood_num)} - 1])] <= ${incith::fml::flood_data(flood_time)}} {
				putlog "$incith::fml::version: flood detected from ${nick}."
				putserv "notice $nick :$incith::fml::version: flood detected, placing you on ignore for $::incith::fml::ignore minute(s)! :P"
				newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::fml::version flooding $incith::fml::ignore
				return 1
			} else {
				return 0
			}
		}
	}
}

putlog " - $incith::fml::version loaded."

# EOF



