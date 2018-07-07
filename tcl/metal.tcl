# Metal v1.0 2013-04-07

# metal-archives.com script
# (cl)2013 speechles
#
# TO ENABLE IN YOUR CHANNEL:
# .chanset #yourchan +metal
#
# TO SEARCH:
# ( use -search )
# !metal *band -search
# !metal -search *band*
# !metal band* -search
# !metal -search band
#
# TO DISPLAY RESULTS:
# ( don't use -search )
# !metal *band
# !metal *band*
# !metal band*
# !metal band
#
# speechles was here :P

package require http
setudef flag metal

namespace eval metal {
   variable metal
   # ---> start config

   # trigger character
   set metal(pref) "!"

   # command used to reply to user
   # this can be a list of space delimited commands
   set metal(commands) "metal m"

   # amount user can issue before throttle
   set metal(throttle) 2

   # throttle time
   set metal(throttle_time) 30

   # how many max results to display in search
   set metal(amount) 3

   # how many max albums to show in results pages
   set metal(albums) 3

   # url to metal page
   set metal(page) http://www.metal-archives.com/search/ajax-band-search/?field=name&query=

   # display line for many results
   set metal(many) "\002%total\002 bands (showing first %amount)"

   # display line for a few results
   set metal(few) "\002%total\002 bands"

   # display line for search
   set metal(search) "\002%name\002 - %genre (%location) @ %url"
   
   # display for no results found in search
   set metal(no_results) "Sorry %nick, there are no results for %search."

   # display character for splitting things
   set metal(split) " | "

   # script version
   set metal(version) "1.0"

   # In the future, maybe more of the display will be customizable
   # through the config, until then... dance like an robot ;)

   # <--- config ends
}

# binds
foreach bind [split $::metal::metal(commands)] {
   bind pub -|- "$::metal::metal(pref)$bind" ::metal::pub_
   bind msg -|- "$::metal::metal(pref)$bind" ::metal::msg_
}

bind time - ?0* ::metal::throttleclean_

namespace eval metal {
   # main - msg bind - notice
   proc msg_ {nick uhost hand arg} {
         metal_ $nick $uhost $hand $nick $arg
   }

   # main - pub bind - privmsg
   proc pub_ {nick uhost hand chan arg} {
      if {[channel get $chan metal]} {
        metal_ $nick $uhost $hand $chan $arg
      }
   }

   # sub - give metal
   proc metal_ {nick uhost hand chan arg} {
      if {[throttle_ $uhost,$chan,news $::metal::metal(throttle_time)]} {
         putserv "privmsg $chan :$nick, you have been Throttled! You're going too fast and making my head spin!"
	   return
      }
	variable metal
      if {[regsub -nocase -all -- {-search} [string trim $arg] "" arg]} { set w1 0 }
      set a "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1"
      set t [::http::config -useragent $a]
      catch { set t [::http::geturl $::metal::metal(page)[set a [string map [list %20 -] [http::formatQuery [string trim [string tolower $arg]]]]] -timeout 15000] } error
      # error condition 1, socket error or other general error
      if {![string match -nocase "::http::*" $error] && ![isbotnick $nick]} {
         putserv "privmsg $chan :[string totitle [string map {"\n" " | "} $error]] \( $metal(page)$a \)"
         return
      }
      # error condition 2, http error
      if {![string equal -nocase [::http::status $t] "ok"] || ![string equal -nocase [::http::ncode $t] 200]} {
         putserv "privmsg $chan :[::http::ncode $t] [string totitle [::http::status $t]] \( $metal(page)$a \)"
         return
      }
      set html [::http::data $t]
      ::http::cleanup $t
	regexp -nocase -- {"itotalrecords"\:(.*?),} $html - total
	if {$total < 1} {
		putserv "privmsg $chan :[string map [list %nick $nick %search $a] $metal(no_results)]"
		return 1
	}
	if {[info exists w1]} {
		if {$total > $metal(amount)} {
			set max $metal(amount)
			lappend output "[string map [list %total $total %amount $max] $metal(many)]"
		} else {
			set max $total
			lappend output "[string map [list %total $total] $metal(few)]"
		}
		for {set count 0} {$count < $max} {incr count} {
			regexp -nocase -- {a href=.*?"(.*?)">(.*?)</a>.*?-->".*?"(.*?)".*?"(.*?)"} $html - url name genre location
			lappend output "[string map [list %url [unescape $url] %name $name %genre $genre %location $location] $metal(search)]"
			regsub -nocase -- {a href=.*?".*?">.*?</a>.*?-->".*?".*?".*?".*?"} $html "" html
		}
		foreach line [split [join $output $metal(split)] "\n"] { putserv "privmsg $chan :$line" }
	} else {
		regexp -nocase -- {a href=.*?"(.*?)">} $html - url
      	catch { set t [::http::geturl [unescape $url] -timeout 15000] } error
     		# error condition 1, socket error or other general error
     		if {![string match -nocase "::http::*" $error] && ![isbotnick $nick]} {
         		putserv "privmsg $chan :[string totitle [string map {"\n" " | "} $error]] \( $url \)"
         		return
      	}
     		# error condition 2, http error
      	if {![string equal -nocase [::http::status $t] "ok"] || ![string equal -nocase [::http::ncode $t] 200]} {
         		putserv "privmsg $chan :[::http::ncode $t] [string totitle [::http::status $t]] \( $metal(page)$a \)"
         		return
    		}
     		set html [::http::data $t]
		::http::cleanup $t
  		regexp -nocase -- {<h1 class="band_name">.*?href=.*?>(.*?)</a>} $html - band
		while {[regexp -nocase -- {<dt.*?>(.*?)</dt>.*?<dd.*?>(.*?)</dd>} $html - name value]} {
			regsub -nocase -- {<dt.*?>.*?</dt>.*?<dd.*?>.*?</dd>} $html "" html
			regsub -all -- {<.*?>} [string map [list \n "" \t "" \v "" \r "" \x01 "" \a ""] $value] "" value
			regsub -all -- {<.*?>} [string map [list \n "" \t "" \v "" \r "" \x01 "" \a ""] $name] "" name
			lappend results "[string trim $name] [string trim $value]"
		}
		regexp -nocase -- {<div id="band_tab_members_current">(.*?)<div id="auditTrail">} $html - htm
		regsub -all -nocase -- {<td colspan="2".*?>.*?</td>} $htm "" htm
		while {[regexp -nocase -- {<td.*?>(.*?)</td>.*?<td.*?>(.*?)</td>} $htm - name value]} {
			regsub -nocase -- {<td.*?>.*?</td>.*?<td.*?>.*?</td>} $htm "" htm
			regsub -all -- {<.*?>} [string map [list \n "" \t "" \v "" \r "" \x01 ""] $value] "" value
			regsub -all -- {<.*?>} [string map [list \n "" \t "" \v "" \r "" \x01 ""] $name] "" name
			lappend moreresults "[url_map [string range $name 0 end-1]]: [url_map [string trim $value]]"
		}
		putserv "privmsg $chan :\002$band\002$metal(split)[join $results "; "]"
		if {[info exists moreresults]} { putserv "privmsg $chan :\002$band\002$metal(split)Members: [join $moreresults "; "]" }
		set output "privmsg $chan :\002$band\002$metal(split)[unescape $url]"
      	catch { set t [::http::geturl [set url http://www.metal-archives.com/band/discography/id/[unescape [lindex [split $url /] end]]] -timeout 5000] } error
     		# error condition 1, socket error or other general error
     		if {![string match -nocase "::http::*" $error] && ![isbotnick $nick]} {
         		putserv "privmsg $chan :[string totitle [string map {"\n" " | "} $error]] \( $url \)"
         		return
      	}
     		# error condition 2, http error
      	if {![string equal -nocase [::http::status $t] "ok"] || ![string equal -nocase [::http::ncode $t] 200]} {
         		putserv "privmsg $chan :[::http::ncode $t] [string totitle [::http::status $t]] \( $metal(page)$a \)"
         		return
    		}
     		set html [::http::data $t]
		::http::cleanup $t
		set album [regexp -all -inline -- {<td><a href=".*?">(.*?)</a>} $html]; foreach {junk count} $album { lappend albums $count }
		if {[info exists albums]} {
			if {[expr {[llength $albums]-$metal(albums)}] > 0 } {
				putserv "privmsg $chan :\002$band\002$metal(split)Albums: [join [lrange $albums 0 [expr {$metal(albums)-1}]] "; "] (...and [expr {[llength $albums] - $metal(albums)}] more)"
			} else {
				putserv "privmsg $chan :\002$band\002$metal(split)Albums: [join [lrange $albums 0 [expr {$metal(albums)-1}]] "; "]"
			}
		}
		putserv $output
	}
   }
    
   proc unescape {t} { return [string map [list \\ ""] $t] }

   # sub - map it
   proc url_map {text {char "utf-8"} } {
	# code below is neccessary to prevent numerous html markups
	# from appearing in the output (ie, &quot;, &#5671;, etc)
	# stolen (borrowed is a better term) from tcllib's htmlparse ;)
	# works unpatched utf-8 or not, unlike htmlparse::mapEscapes
	# which will only work properly patched....
	set escapes {
		&nbsp; \xa0 &iexcl; \xa1 &cent; \xa2 &pound; \xa3 &curren; \xa4
		&yen; \xa5 &brvbar; \xa6 &sect; \xa7 &uml; \xa8 &copy; \xa9
		&ordf; \xaa &laquo; \xab &not; \xac &shy; \xad &reg; \xae
		&macr; \xaf &deg; \xb0 &plusmn; \xb1 &sup2; \xb2 &sup3; \xb3
		&acute; \xb4 &micro; \xb5 &para; \xb6 &middot; \xb7 &cedil; \xb8
		&sup1; \xb9 &ordm; \xba &raquo; \xbb &frac14; \xbc &frac12; \xbd
		&frac34; \xbe &iquest; \xbf &Agrave; \xc0 &Aacute; \xc1 &Acirc; \xc2
		&Atilde; \xc3 &Auml; \xc4 &Aring; \xc5 &AElig; \xc6 &Ccedil; \xc7
		&Egrave; \xc8 &Eacute; \xc9 &Ecirc; \xca &Euml; \xcb &Igrave; \xcc
		&Iacute; \xcd &Icirc; \xce &Iuml; \xcf &ETH; \xd0 &Ntilde; \xd1
		&Ograve; \xd2 &Oacute; \xd3 &Ocirc; \xd4 &Otilde; \xd5 &Ouml; \xd6
		&times; \xd7 &Oslash; \xd8 &Ugrave; \xd9 &Uacute; \xda &Ucirc; \xdb
		&Uuml; \xdc &Yacute; \xdd &THORN; \xde &szlig; \xdf &agrave; \xe0
		&aacute; \xe1 &acirc; \xe2 &atilde; \xe3 &auml; \xe4 &aring; \xe5
		&aelig; \xe6 &ccedil; \xe7 &egrave; \xe8 &eacute; \xe9 &ecirc; \xea
		&euml; \xeb &igrave; \xec &iacute; \xed &icirc; \xee &iuml; \xef
		&eth; \xf0 &ntilde; \xf1 &ograve; \xf2 &oacute; \xf3 &ocirc; \xf4
		&otilde; \xf5 &ouml; \xf6 &divide; \xf7 &oslash; \xf8 &ugrave; \xf9
		&uacute; \xfa &ucirc; \xfb &uuml; \xfc &yacute; \xfd &thorn; \xfe
		&yuml; \xff &fnof; \u192 &Alpha; \u391 &Beta; \u392 &Gamma; \u393 &Delta; \u394
		&Epsilon; \u395 &Zeta; \u396 &Eta; \u397 &Theta; \u398 &Iota; \u399
		&Kappa; \u39A &Lambda; \u39B &Mu; \u39C &Nu; \u39D &Xi; \u39E
		&Omicron; \u39F &Pi; \u3A0 &Rho; \u3A1 &Sigma; \u3A3 &Tau; \u3A4
		&Upsilon; \u3A5 &Phi; \u3A6 &Chi; \u3A7 &Psi; \u3A8 &Omega; \u3A9
		&alpha; \u3B1 &beta; \u3B2 &gamma; \u3B3 &delta; \u3B4 &epsilon; \u3B5
		&zeta; \u3B6 &eta; \u3B7 &theta; \u3B8 &iota; \u3B9 &kappa; \u3BA
		&lambda; \u3BB &mu; \u3BC &nu; \u3BD &xi; \u3BE &omicron; \u3BF
		&pi; \u3C0 &rho; \u3C1 &sigmaf; \u3C2 &sigma; \u3C3 &tau; \u3C4
		&upsilon; \u3C5 &phi; \u3C6 &chi; \u3C7 &psi; \u3C8 &omega; \u3C9
		&thetasym; \u3D1 &upsih; \u3D2 &piv; \u3D6 &bull; \u2022
		&hellip; \u2026 &prime; \u2032 &Prime; \u2033 &oline; \u203E
		&frasl; \u2044 &weierp; \u2118 &image; \u2111 &real; \u211C
		&trade; \u2122 &alefsym; \u2135 &larr; \u2190 &uarr; \u2191
		&rarr; \u2192 &darr; \u2193 &harr; \u2194 &crarr; \u21B5
		&lArr; \u21D0 &uArr; \u21D1 &rArr; \u21D2 &dArr; \u21D3 &hArr; \u21D4
		&forall; \u2200 &part; \u2202 &exist; \u2203 &empty; \u2205
		&nabla; \u2207 &isin; \u2208 &notin; \u2209 &ni; \u220B &prod; \u220F
		&sum; \u2211 &minus; \u2212 &lowast; \u2217 &radic; \u221A
		&prop; \u221D &infin; \u221E &ang; \u2220 &and; \u2227 &or; \u2228
		&cap; \u2229 &cup; \u222A &int; \u222B &there4; \u2234 &sim; \u223C
		&cong; \u2245 &asymp; \u2248 &ne; \u2260 &equiv; \u2261 &le; \u2264
		&ge; \u2265 &sub; \u2282 &sup; \u2283 &nsub; \u2284 &sube; \u2286
		&supe; \u2287 &oplus; \u2295 &otimes; \u2297 &perp; \u22A5
		&sdot; \u22C5 &lceil; \u2308 &rceil; \u2309 &lfloor; \u230A
		&rfloor; \u230B &lang; \u2329 &rang; \u232A &loz; \u25CA
		&spades; \u2660 &clubs; \u2663 &hearts; \u2665 &diams; \u2666
		&quot; \x22 &amp; \x26 &lt; \x3C &gt; \x3E O&Elig; \u152 &oelig; \u153
		&Scaron; \u160 &scaron; \u161 &Yuml; \u178 &circ; \u2C6
		&tilde; \u2DC &ensp; \u2002 &emsp; \u2003 &thinsp; \u2009
		&zwnj; \u200C &zwj; \u200D &lrm; \u200E &rlm; \u200F &ndash; \u2013
		&mdash; \u2014 &lsquo; \u2018 &rsquo; \u2019 &sbquo; \u201A
		&ldquo; \u201C &rdquo; \u201D &bdquo; \u201E &dagger; \u2020
		&Dagger; \u2021 &permil; \u2030 &lsaquo; \u2039 &rsaquo; \u203A
		&euro; \u20AC &apos; \u0027 &lrm; "" &rlm; "" &#8236; "" &#8237; ""
		&#8238; "" &#8212; \u2014
	};
	if {![string equal $char [encoding system]]} { set text [encoding convertfrom $char $text] }
	set text [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\"" "\\\""] [string map $escapes $text]]
	regsub -all -- {&#([[:digit:]]{1,5});} $text {[format %c [string trimleft "\1" "0"]]} text
	regsub -all -- {&#x([[:xdigit:]]{1,4});} $text {[format %c [scan "\1" %x]]} text
	catch { set text "[subst "$text"]" }
	if {![string equal $char [encoding system]]} { set text [encoding convertto $char $text] }
	return "$text"
   }

   # IS THE BOT PATCHED?!
   # thanks thommey :P
   proc BotIsPatched { } { catch {botonchan #\uC0A0} e ; if {[string equal [string length $e] [string bytelength $e]]} { return 0 } { return 1 } }

   # Throttle Proc (slightly altered, super action missles) - Thanks to user
   # see this post: http://forum.egghelp.org/viewtopic.php?t=9009&start=3
   proc throttle_ {id seconds} {
      if {[info exists ::metal::throttle($id)]&&[lindex $::metal::throttle($id) 0]>[clock seconds]} {
         set ::metal::throttle($id) [list [lindex $::metal::throttle($id) 0] [set value [expr {[lindex $::metal::throttle($id) 1] +1}]]]
         if {$value > $::metal::metal(throttle)} { set id 1 } { set id 0 }
      } {
         set ::metal::throttle($id) [list [expr {[clock seconds]+$seconds}] 1]
         set id 0
      }
   }
   # sub - clean throttled users
   proc throttleclean_ {args} {
      set now [clock seconds]
      foreach {id time} [array get ::metal::throttle] {
         if {[lindex $time 0]<=$now} {unset ::metal::throttle($id)}
      }
   }
}
putlog "Metal announcer.tcl v$::metal::metal(version) :: Http: [package present http];BotIsPatched: [metal::BotIsPatched];EncodingSystem: [encoding system];Tcl: $tcl_version;Eggdrop: [lindex $version 0];Suzi: [if {[info exists ::sp_version]} { set a "YES $::sp_version" } { set a "NO" }]"

#eof
