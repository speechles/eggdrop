catch {package require http}

namespace eval ::cricketarchive {
	
	################################################################################################

	variable author		"iRoc <apnihost@gmail.com> (c)"
	variable version	"1.1.1"
	variable date		"08-Jul-2010"
	
	set time_up [clock clicks -milliseconds]
	
	variable options
	variable feeds
	variable token2feed
	
	setudef str cricketarchive-default_lang
	setudef str cricketarchive-usecolors
	
	################################################################################################
	
	set options(debug)          2
	set options(msg_len)        400
        set max_tcl_events          20
        set select_timeout          100	
	set options(fast)           0
	set options(default_lang)   {bn en}
	set options(usecolors)      1
	set options(check_time)     30000
	set options(url)            "http://www.cricketarchive.com/Archive/Scorecards/%s_commentary.html"
	set options(stop_no_output) 100
	
	################################################################################################
	
	proc compare_version {version1 version2} {
		
		set dec1 [split $version1 .]; set dec2 [split $version2 .]
		foreach a1 $dec1 a2 $dec2 {
			if {[string is space [set a1 [string trimleft $a1 0]]]} {set a1 0}
			if {[string is space [set a2 [string trimleft $a2 0]]]} {set a2 0}
			
			if {$a2 > $a1} {return 1} elseif {$a2 < $a1} {return 0}
		}
		return 0
		
	}
	
	if {[info procs lassign] == ""} {
		proc lassign {values args} {
			set vlen [llength $values]
			set alen [llength $args]
			for {set i $vlen} {$i < $alen} {incr i} {
				lappend values {}
			}
			uplevel 1 [list foreach $args $values break]
			return [lrange $values $alen end]
		}
	}
	
	if {[info command lreverse] == ""} {
		proc lreverse l {
			set r {}
			set r {}
			set i [llength $l]
			while {[incr i -1]} {lappend r [lindex $l $i]}
			lappend r [lindex $l 0]
		}
	}
	
	proc ladd {varName el} {
		upvar $varName var
		if {![info exists var]} {set var {}}
		if {[ni $var $el]} {
			lappend var $el
			return 1
		}
		return 0
	}
	
	if {[compare_version [info pa] 8.5]} {
		proc in {list element} {expr [lsearch -exact $list $element] >= 0}
		proc ni {list element} {expr [lsearch -exact $list $element] < 0}
	} else {
		proc in {list element} {expr {$element in $list}}
		proc ni {list element} {expr {$element ni $list}}
	}
	
	################################################################################################
	
	proc debug {text {level 1}} {
		variable options
		if {$options(debug) >= $level} {putlog "[namespace current]:: $text"}
	}
	
	proc Pop {varname {nth 0}} {
		upvar $varname args
		set r [lindex $args $nth]
		set args [lreplace $args $nth $nth]
		return $r
	}
	
	proc get_options_int {param {chan ""}} {
		variable options
		
		if {[check_isnull $chan] || ![validchan $chan]} {
			if {[info exists options($param)] && [string is digit $options($param)] && $options($param) >= 0} {
				return $options($param)
			}
		} else {
			set cset [channel get $chan cricketarchive-$param]
			if {![string is space $cset] && [string is digit $cset] && $cset >= 0} {return $cset}
			if {[info exists options($param)] && [string is digit $options($param)] && $options($param) >= 0} {
				return $options($param)
			}
		}
		return 0
		
	}
	
	proc importvars {lo} {
		
		foreach var $lo {
			set value [uplevel 2 "if {\[info exists $var\]} {set $var} else {set $var \"\"}"]
			uplevel [list set $var $value]
		}
		
	}
	
	proc check_isnull {str} {
		if {$str == "" || $str == "*"} {return 1} else {return 0}
	}
	
	################################################################################################
	
	proc put_msgdest {args} {
		variable options
		
		set opts(-type)  "privmsg";
		set opts(-speed) 2;
		
		if {[llength $args] > 2} {
			while {[string match -* [lindex $args 0]]} {
				switch -glob -- [lindex $args 0] {
					-type  { set opts(-type)  [Pop args 1] }
					-speed { set opts(-speed) [Pop args 1] }
					-- { Pop args; break }
					default {
						set opt [join [lsort [array names opts -*]] ", "]
						return -code error "bad option [lindex $args 0]: must be $opt"
					}
				}
				Pop args
			}
		}
		
		if {[llength $args] != 2} {
			return -code error "wrong # args: should be \"put_msgdest ?switches? dest text\""
		}
		
		set dest [lindex $args 0]
		set text [lindex $args 1]
		
		set text [string map [list {\002} "\002" {\037} "\037" {\026} "\026" {\003} "\003" {\017} "\017"] $text]
		
		set list_out [list]
		
		if {[string length $text] <= $options(msg_len)} {
			lappend list_out $text
		} else {
			
			set str_out ""
			set str_color ""
			set new 1
			
			set reg_color  {(\003\d{1,2}(?:,\d{1,2})?|\003|\037|\026|\017|\002|\d{1,2}(?:,\d{1,2})?|||||)}
			set reg_dcolor {|\037\037||\002\002||\026\026}
			set reg_ccolor {[\017](.*?)$}
			
			foreach _0 [split $text] {
				
				if {$new} {set _1 $_0; set new 0} else {set _1 " $_0"}
				
				if {[string length "$_0"] > $options(msg_len)} {

					set str_tmp "$str_out$_1"
					while {[string length $str_tmp] > $options(msg_len)} {
						set str_out [string range "$str_color$str_tmp" 0 [expr $options(msg_len)-1]]
						set str_tmp [string range "$str_color$str_tmp" $options(msg_len) end]
						lappend list_out "$str_color$str_out"
						foreach {block color} [regexp -all -inline -- $reg_color $str_out] {
							append str_color $color
						}
						while {[regexp -all -- $reg_ccolor $str_color -> str_color]} {}
						regsub -all -- $reg_dcolor $str_color {} str_color
					}
					set str_out $str_tmp
				} elseif {[string length "$str_color$str_out$_1"] > $options(msg_len)} {

					lappend list_out "$str_color$str_out"
					foreach {block color} [regexp -all -inline -- $reg_color $str_out] {
						append str_color $color
					}
					while {[regexp -all -- $reg_ccolor $str_color -> str_color]} {}
					regsub -all -- $reg_dcolor $str_color {} str_color
					set str_out $_0
				} else {
					append str_out $_1
				}
				
			}
			
			if {![string is space $str_out]} {lappend list_out "$str_color$str_out"}
			
		}
		
		if {$opts(-type) == "privmsg"} {
			set put_out "PRIVMSG [join $dest ","] :"
		} elseif {$opts(-type) == "notice"} {
			set put_out "NOTICE [join $dest ","] :"
		} elseif {$opts(-type) == "dcc" && [valididx $dest]} {
			set put_out ""
		} else {
			return
		}
		
		foreach _ $list_out {
			set msg $put_out$_
			if {$opts(-type) == "dcc"} {
				putdcc $dest $msg
			} elseif {$options(fast) || $opts(-speed) == 0} {
				append msg "\n"
				putdccraw 0 [string length $msg] $msg
			} elseif {$opts(-speed) == 1} {
				putquick $msg
			} elseif {$opts(-speed) == 2} {
				putserv $msg
			} elseif {$opts(-speed) == 3} {
				puthelp $msg
			}
		}
		
	}
	
	proc get_text {args} {
		variable text
		variable options
		
		set opts(-black) 0;
		set opts(-color) 0;
		set opts(-type)  "text";
		set opts(-hand)  "*";
		set opts(-chan)  "";
		set opts(-lang)  "";
		
		while {[string match -* [lindex $args 0]]} {
			switch -glob -- [lindex $args 0] {
				-black { set opts(-black) 1 }
				-color { set opts(-color) 1 }
				-type  { set opts(-type)  [Pop args 1] }
				-hand  { set opts(-hand)  [Pop args 1] }
				-chan  { set opts(-chan)  [Pop args 1] }
				-lang  { set opts(-lang)  [Pop args 1] }
				-- { Pop args; break }
				default {
					set opt [join [lsort [array names opts -*]] ", "]
					return -code error "bad option [lindex $args 0]: must be $opt"
				}
			}
			Pop args
		}
		
		if {$opts(-black) && $opts(-color)} {
			return -code error "can't use \"-black -color\" at the same time together"
		} elseif {$opts(-black)} {
			set colors {black}
		} elseif {$opts(-color)} {
			set colors {color}
		} else {
			if {[get_options_int usecolors $opts(-chan)]} {
				set colors {color black}
			} else {
				set colors {black color}
			}
		}
		
		if {$opts(-lang) == ""} {
			set langs [list]
			if {![check_isnull $opts(-hand)]} {
				foreach _ [getuser $opts(-hand) XTRA cricketarchive-default_lang] {
					if {[string is space $_]} continue
					ladd langs $_
				}
			}
			if {![check_isnull $opts(-chan)] && [validchan $opts(-chan)]} {
				foreach _ [channel get $opts(-chan) cricketarchive-default_lang] {
					if {[string is space $_]} continue
					ladd langs $_
				}
			}
			if {[info exists options(default_lang)]} {
				foreach _ $options(default_lang) {
					if {[string is space $_]} continue
					ladd langs $_
				}
			}
		} else {
			set langs $opts(-lang)
		}
		
		switch -- $opts(-type) {
			args - help - help2 {
				if {[llength $args] != 1} {
					return -code error "wrong # args: should be \"get_text ?switches? command\""
				}
				foreach color $colors {
					foreach lang $langs {
						if {[info exists text($opts(-type),$color,$lang,[lindex $args 0])]} {
							return $text($opts(-type),$color,$lang,[lindex $args 0])
						}
					}
				}
			}
			default {
				if {[llength $args] != 2} {
					return -code error "wrong # args: should be \"get_text ?switches? name tag\""
				}
				foreach color $colors {
					foreach lang $langs {
						if {[info exists text($opts(-type),$color,$lang,[lindex $args 0],[lindex $args 1])]} {
							return $text($opts(-type),$color,$lang,[lindex $args 0],[lindex $args 1])
						}
					}
				}
			}
		}
		
		return "null"
		
	}
	
	proc set_text {args} {
		variable text
		
		set opts(-black) 0;
		set opts(-color) 0;
		set opts(-type)  "text";
		
		while {[string match -* [lindex $args 0]]} {
			switch -glob -- [lindex $args 0] {
				-black { set opts(-black) 1 }
				-color { set opts(-color) 1 }
				-type  { set opts(-type)  [Pop args 1] }
				-- { Pop args; break }
				default {
					set opt [join [lsort [array names opts -*]] ", "]
					return -code error "bad option [lindex $args 0]: must be $opt"
				}
			}
			Pop args
		}
		
		if {$opts(-black) && $opts(-color)} {
			return -code error "can't use \"-black -color\" at the same time together"
		} elseif {$opts(-black)} {
			set color "black"
		} elseif {$opts(-color)} {
			set color "color"
		} else {
			set color "black"
		}
		
		switch -- $opts(-type) {
			args - help - help2 {
				if {[llength $args] != 3} {
					return -code error "wrong # args: should be \"set_text ?switches? lang command string\""
				}
				set text($opts(-type),$color,[lindex $args 0],[lindex $args 1]) [lindex $args 2]
			}
			default {
				if {[llength $args] != 4} {
					return -code error "wrong # args: should be \"set_text ?switches? lang name tag string\""
				}
				set text($opts(-type),$color,[lindex $args 0],[lindex $args 1],[lindex $args 2]) [lindex $args 3]
			}
		}
		
		return
		
	}
	
	proc sprintf {name text args} {
		
		if {[string index $text 0] == "#"} {
			importvars [list shand schan]
			if {![info exists schan]} {set schan "*"}
			set textlang [get_text -hand $shand -chan $schan -- $name $text]
			if {$textlang == "null"} {
				return "Module \002$name\002, text \002$text\002 not found. Args: [join $args ", "]"
			} else {
				set text $textlang
			}
		}
		set ind 0
		set first [string first "%s" $text]
		while {$first >= 0} {
			set text [string replace $text $first [expr $first+1] [lindex $args $ind]]
			set first [string first "%s" $text [expr $first+[string length [lindex $args $ind]]]]
			incr ind
		}
		return $text
		
	}
	
	################################################################################################
	
	proc http_done {token} {
		variable options
		variable feeds
		variable token2feed
		
		if {[catch {
		set feed $token2feed($token)
		
		debug "http_done $feed" 2
		
		set errid  [::http::status $token]
		set errtxt [::http::error  $token]
		set ncode  [::http::ncode  $token]
		
		debug "http_done $feed ($errid) ($errtxt) ($ncode)" 2
		
		if { $errid == {ok} && $ncode == 200} {
			
			upvar #0 $token state
			set data $state(body)
			set data [encoding convertfrom iso8859-1 $data]
			
			#::ccs::SaveFile test.html $data
			
			#if {[regexp -- {<div class=\"cf_uf_col3\" style=\"border:none\">(.*?)<br />(.*?)</div>} $data -> a b]} {
			#	
			#	set a [string trim [string map {{\n} {}} $a]]
			#	set b [string trim [string map {{\n} {}} $b]]
			#	
			#	if {$feeds($feed,header) != [list $a $b]} {
			#		foreach chan $feeds($feed,chan) {
			#			put_msgdest -- $chan [sprintf cricketarchive #109 $a $b]
			#		}
			#		set feeds($feed,header) [list $a $b]
			#	}
			#	
			#}
			
			set ldata [regexp -all -inline -- {<tr>(.+?)</tr>} $data]
			#set ldata [regexp -all -inline -- {<div class=\"row([a-z]+?)\">.*<strong>(.+?)</strong>.*?<strong><font .*?>(.+?)</font></strong>(.+?)</font>.*?</div>} $data]
			
			set temp_live {}
			foreach {-> a} $ldata {
				
				if {[regexp -- {<td .+?>(\d+)</td><td .+?>([a-z0-9]+)</td><td .+?>([a-z0-9]+)</td><td .+?>(.+?)</td>} $a -> c1 c2 c3 c4]} {
					
				} elseif {[regexp -- {<td width="100" colspan="3" valign="top">(.*?)</td><td>(.+?)</td>} $a -> c1 c2]} {
					set c3 ""
					set c4 ""
				} elseif {[regexp -- {<td colspan="3" align="center"></td><td><a .+?>(.+?)</a> (.+?)</td>} $a -> c1 c2]} {
					set c3 ""
					set c4 ""
				} else {
					continue
				}
				regsub -all {<.+?>(.*?)</.+?>} $c4 "\00312\\1\00304" c4
				regsub -all {<br>} $c4 { } c4
				
				if {[lsearch -exact $feeds($feed,live) [list $c1 $c2 $c3 $c4]] < 0} {
					lappend feeds($feed,live) [list $c1 $c2 $c3 $c4]
					lappend temp_live [list $c1 $c2 $c3 $c4]
				}
				
			}
			
 			if ($feeds($feed,start)) {
 				set feeds($feed,start) 0
 				set l [lrange $temp_live end end]
 			} else {
 				set l $temp_live
 			}
			
			foreach _ $l {
				lassign $_ c1 c2 c3 c4
				foreach chan $feeds($feed,chan) {
					if {$c3 == "" && $c4 == ""} {
						put_msgdest -- $chan [sprintf cricketarchive #107 $c1 $c2]
					} else {
						put_msgdest -- $chan [sprintf cricketarchive #106 $c1 $c2 $c3 $c4]
					}
				}
			}
			if {[llength $temp_live] == 0} {
				incr feeds($feed,null)
				if {$feeds($feed,null) >= $options(stop_no_output)} {
					foreach chan $feeds($feed,chan) {
						put_msgdest -- $chan [sprintf cricketarchive #108 $feed]
					}
					timer_stop $feed
				}
			} else {
				set feeds($feed,null) 0
			}
			
		}
		
		#set feeds($feed,token) ""
		::http::cleanup $token
		unset token2feed($token)
		
		} err]} {
			debug "http_done, error: $err"
		}
	}
	
	proc timer_check {feed} {
		variable options
		variable feeds
		variable token2feed
		
		debug "timer_check $feed" 2
		
		timer_start $feed
		::http::config -urlencoding utf-8
		::http::config -useragent "Opera/9.10 (Windows NT 5.1; U; ru)"
		
		set url [string map [list %s "[string range $feed 0 2]/$feed/$feed"] $options(url)]
		
		debug "get url $url" 2
		set token [::http::geturl $url -command [namespace origin http_done] -binary true -timeout 20000]
		set feeds($feed,token) $token
		set token2feed($token) $feed
		
	}
	
	proc timer_start {feed} {
		variable options
		variable feeds
		
		debug "timer_start $feed" 2
		
		set feeds($feed,timer) [after $options(check_time) [list [namespace origin timer_check] $feed]]
		
	}
	
	proc timer_stop {feed} {
		variable feeds
		
		debug "timer_stop $feed" 2
		
		after cancel $feeds($feed,timer)
		foreach _ [array names feeds "$feed,*"] { unset feeds($_) }
		
	}
	
	proc pub_startmatch {nick uhost hand chan text} {
		variable feeds
		
		if {![regexp -nocase -- {^(\d+)$} $text -> feed]} {
			put_msgdest -type notice -- $nick [sprintf cricketarchive #101]
			return
		}
		
		if {[info exists feeds($feed,feed)]} {
			
			if {[in $feeds($feed,chan) $chan]} {
				put_msgdest -- $chan [sprintf cricketarchive #103 $feed]
			} else {
				lappend feeds($feed,chan) $chan
				put_msgdest -- $chan [sprintf cricketarchive #102 $feed]
			}
			
		} else {
			
			set feeds($feed,feed)   1
			set feeds($feed,chan)   [list $chan]
			set feeds($feed,timer)  0
			set feeds($feed,token)  ""
			set feeds($feed,header) {}
			set feeds($feed,live)   {}
			set feeds($feed,null)   0
			set feeds($feed,start)  1
			put_msgdest -- $chan [sprintf cricketarchive #102 $feed]
			
			timer_check $feed
			
		}
		
		debug "<<$nick ($hand)>> !$chan! start match, feed $feed"
		
	}
	
	proc pub_stopmatch {nick uhost hand chan text} {
		variable feeds
		
		if {![regexp -nocase -- {^(\d+)$} $text -> feed]} {
			put_msgdest -type notice -- $nick [sprintf cricketarchive #101]
			return
		}
		
		if {[info exists feeds($feed,feed)]} {
			
			if {[in $feeds($feed,chan) $chan]} {
				set feeds($feed,chan) [lsearch -not -inline -all $feeds($feed,chan) $chan]
				if {[llength $feeds($feed,chan)] == 0} {
					timer_stop $feed
				}
				put_msgdest -- $chan [sprintf cricketarchive #104 $feed]
			} else {
				put_msgdest -- $chan [sprintf cricketarchive #105 $feed]
			}
			
		} else {
			
			put_msgdest -- $chan [sprintf cricketarchive #105 $feed]
			
		}
		
		debug "<<$nick ($hand)>> !$chan! stop match, feed $feed"
		
	}
	
	

	proc pub_infomatch {nick uhost hand chan text} {	
	   set t [::http::geturl http://www.cricketarchive.com/]
	   set data [::http::data $t]
	   ::http::cleanup $t
	   
		set l [regexp -all -inline -- {<tr><td height="22"><div align="center"><a href="/Archive/Scorecards/.*?/.*?/(.*?)_mini.html">(.*?)</a></div></td></tr>} $data]
		
	   foreach {black a b } $l {
		   
		   set a [string trim $a " \n"]
		   set b [string trim $b " \n"]
		      
		   regsub -all {<.+?>} $a {} a
		   regsub -all {<.+?>} $b {} b
		   
			putserv "PRIVMSG $chan :4$b 3Start Command !startmatch $a"
	   }
	}	
	
	################################################################################################
	
	proc prerehash {type} {
		binds_down
	}
	
	proc binds_down {} {
		
		set b [binds "[namespace current]::*"]
		foreach _ $b {unbind [lindex $_ 0] [lindex $_ 1] [lindex $_ 2] [lindex $_ 4]}
		debug "[llength $b] binds is down"
		
	}
	
	proc main {} {
		
		bind pub  -|- !startmatch [namespace origin pub_startmatch]
		bind pub  -|- !stopmatch  [namespace origin pub_stopmatch]
		bind pub  -|- !infomatch  [namespace origin pub_infomatch]
		bind evnt -|- prerehash   [namespace origin prerehash]
		
		debug "[llength [binds "[namespace current]::*"]] binds is up"
	}

	################################################################################################
	# Тексты
	
	set_text en cricketarchive #101 "\00305You must specify #Id match."
	set_text en cricketarchive #102 "\00305Watching the match #Id %s added to display the current channel."
	set_text en cricketarchive #103 "\00305Watching the match #Id %s is already added to output for the current channel."
	set_text en cricketarchive #104 "\00305Watching the match #Id %s is stopped for the current channel."
	set_text en cricketarchive #105 "\00305Watching the match #Id %s is not conducted on the current channel."
	set_text en cricketarchive #106 "10Over: %s, 10Ball: %s, 10Runs: %s 4%s"
      set_text en cricketarchive #107 "3%s 3%s"
	set_text en cricketarchive #108 "\00305Watching the match #Id %s stopped due to lack of output."
#	set_text en cricketarchive #109 "\00314%s \017>> \00314%s"
      set_text en cricketarchive #109 "12 %s -|- %s %s %s "
	################################################################################################
	# Запуск
	
	main
	
	set time_down [clock clicks -milliseconds]
	debug "v$version \[$date\] by $author loaded in [expr ($time_down-$time_up)/1000.0] s"
	
}


