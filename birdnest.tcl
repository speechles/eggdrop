# Script to grab titles from webpages - Copyright C.Leonhardt (rosc2112 at yahoo com) Aug.11.2007 
# http://members.dandy.net/~fbn/urltitle.tcl.txt
# Loosely based on the tinyurl script by Jer and other bits and pieces of my own..

################################################################################################################

# Usage: 

# 1) Set the configs below
# 2) .chanset #channelname +urltitle        ;# enable script
# 3) .chanset #channelname +logurltitle     ;# enable logging
# Then just input a url in channel and the script will retrieve the title from the corresponding page.

# When reporting bugs, PLEASE include the .set errorInfo debug info! 
# Read here: http://forum.egghelp.org/viewtopic.php?t=10215

################################################################################################################

# Configs:

set urltitle(trigger) "!s"
set urltitle(ignore) "bdkqr|dkqr" 	;# User flags script will ignore input from
set urltitle(pubmflags) "-|-" 	;# user flags required for channel eggdrop use
set urltitle(length) 1	 		;# minimum url length to trigger channel eggdrop use
set urltitle(delay) 1 			;# minimum seconds to wait before another eggdrop use
set urltitle(timeout) 60000 		;# geturl timeout (1/1000ths of a second)

################################################################################################################
# Script begins:

package require http			;# You need the http package..
set urltitle(last) 111 			;# Internal variable, stores time of last eggdrop use, don't change..
setudef flag urltitle			;# Channel flag to enable script.
setudef flag logurltitle		;# Channel flag to enable logging of script.

if {[catch {package require tls}]} { putlog "Birdnest cannot be used without tls package." ;putlog "Birdnest.tcl unloaded" ;return
} else { ::http::register https 443 [list ::tls::socket -require 0 -request 1] }

set urltitlever "0.05m"
bind pubm $urltitle(pubmflags) {*://*} pubm:urltitle
bind pub $urltitle(pubmflags) $urltitle(trigger) pub:urltitle
proc pub:urltitle {nick host user chan text} {
	global urltitle
	if {([channel get $chan urltitle]) && ([expr [unixtime] - $urltitle(delay)] > $urltitle(last)) && \
	(![matchattr $user $urltitle(ignore)])} {
		set id [lindex [split $text] 0]
		if {[regexp -- {^[0-9]+$} $id]} {
			set word "https://twitter.com/twitter/statuses/$id"
			set urltitle(last) [unixtime]
			set urtitle [urltitle $word]
			if {[llength $urtitle]} {
				foreach line [split [url_map [url_map [lindex $urtitle 0]]] "\n\r"] {
					puthelp "PRIVMSG $chan :$line"
				}
			}
            }
       }
}
proc pubm:urltitle {nick host user chan text} {
	global urltitle
	if {([channel get $chan urltitle]) && ([expr [unixtime] - $urltitle(delay)] > $urltitle(last)) && \
	(![matchattr $user $urltitle(ignore)])} {
		foreach word [split $text] {
			if {[string length $word] >= $urltitle(length) && \
			[regexp {^(f|ht)tp(s|)://} $word] && \
			![regexp {://([^/:]*:([^/]*@|\d+(/|$))|.*/\.)} $word]} {
				set urltitle(last) [unixtime]
				set urtitle [urltitle $word]
				if {[llength $urtitle]} {                  
					foreach line [split [lindex $urtitle 0] "\n"] {
						puthelp "PRIVMSG $chan :$line"
					}
				}
				break
			}
		}
        }
	if {[channel get $chan logurltitle]} {
		foreach word [split $text] {
			if {[string match "*://*" $word]} {
				putlog "<$nick:$chan> $word -> $urtitle"
			}
		}
	}
	# change to return 0 if you want the pubm trigger logged additionally..
	return 1
}

proc urltitle {url} {
	if {[info exists url] && [string length $url]} {
		set title ""
            if {[string match *twitter.com* $url]} {
			catch {set http [::http::geturl $url -timeout $::urltitle(timeout)]} error
			if {[string match -nocase "*couldn't open socket*" $error]} {
				return "Error: couldn't connect..Try again later"
			}
			if { [::http::status $http] == "timeout" } {
				return "Error: connection timed out while trying to contact $url"
			}
			#regsub -all {(?:\n|\t|\v|\r|\x01)} $data " " data
			set ncode [http::ncode $http]
			set count 0 ; set cookies ""
                  while {[string match 30* $ncode]} {
				incr count ; if {$count > 10} { http::cleanup $http ; return [list "Error: traversal limit reached >10"] }
   				upvar #0 $http state
   				if {![info exists state(meta)]} { putserv "privmsg $chan :Error: unsupported URL error \( $url \)" ; return 0 }
				upvar #0 $http state; array set metas $state(meta) ; set red $metas(location)
				http::cleanup $http
				catch {set http [::http::geturl $red -timeout $::urltitle(timeout)]} error
				if {[string match -nocase "*couldn't open socket*" $error]} {
					return [list "Error: couldn't connect..Try again later"]
				}
				if { [::http::status $http] == "timeout" } {
					return [list "Error: connection timed out while trying to contact $red"]
				}
				set ncode [::http::ncode $http]
			}
			if {![string equal -nocase "utf-8" [encoding system]]} {
				set data [encoding convertto "utf-8" [::http::data $http]]
			} else {
				set data [::http::data $http]
			}
			http::cleanup $http
			#regsub -all {(?:\n|\t|\v|\r|\x01|\b|\a|\f)} $data " " data
                  if {[regexp -nocase {<p class="js-tweet-text tweet-text ">(.*?)</p>} $data match ltweet]} {
				regexp -- {<p class="js-tweet-text">(.*?)</p>} $data match ftweet
                        regexp -- {<span class="metadata">.*?<span title=.*>(.*?)(?:</span>|</a></span>)} $data match ago
				#regsub -all -nocase -- {<a href="(.*?)".*?>(.*?)</a>} [string trim $ltweet] "\\2 ( http://twitter.com\\1 \)" ltweet
				#regsub -all -nocase -- {<a href="http\://twitter.com(http.*?)".*?>(.*?)</a>} $ltweet "\\1" ltweet
				#regsub -all -nocase -- {<a href="(.*?)".*?>(.*?)</a>} [string trim $ftweet] "\\2 ( http://twitter.com\\1 \)" ftweet
				#regsub -all -nocase -- {<a href="http\://twitter.com(http.*?)".*?>(.*?)</a>} $ftweet "\\1" ftweet
				#regsub -all -nocase -- {<a href="(/.*?)".*?>(.*?)</a>} $ltweet "\\2 ( http://twitter.com/\\1 \)" ltweet
				#regsub -all -nocase -- {<a href="(/.*?)".*?>(.*?)</a>} $ftweet "\\2 ( http://twitter.com/\\1 \)" ftweet
				#regsub -all -nocase -- {(?!&lt;@)<a class="tweet.*?href="(.*?)".*?>(.*?)</a>(?!&gt;)} $ltweet "\\2 \( _\?\=\\1 \)" ltweet
				#regsub -all -nocase -- {&lt;\+@<a class="tweet.*?href=".*?".*?>(.*?)</a>&gt;} $ltweet "<+@\\1>" ltweet
				#regsub -all -nocase -- {&lt;\@<a class="tweet.*?href=".*?".*?>(.*?)</a>&gt;} $ltweet "<@\\1>" ltweet
				#regsub -all -nocase -- {_\?\=(.*?) } $ltweet "http://twitter.com\\1 " ltweet
                        #regsub -all -nocase -- {\\n} $ltweet "shit" ltweet
				regsub -all -nocase -- {<.*?>} $ltweet "" ltweet
				regsub -all -nocase -- {<.*?>} $ftweet "" ftweet
				set ltweet [join [split [url_map [url_map $ltweet]] "\r\t\v\a\b\a\f\n"] " "]
				set ftweet [join [split [url_map [url_map $ftweet]] "\r\t\v\a\b\a\f\n"] " "]
                        if {[regexp -nocase {<strong class="fullname js-action-profile-name show-popup-with-id">(.*?)</strong>.*?strong class="fullname js-action-profile-name show-popup-with-id">(.*?)</strong} $data match real freal]} {
					regsub -- {<span class="icon verified"><span class="visuallyhidden">Verified account</span></span>} $real " *Verified*" real
					regsub -- {<span class="icon verified"><span class="visuallyhidden">Verified account</span></span>} $freal " *Verified*" freal
				} else {
                        	regexp -nocase {<strong class="fullname js-action-profile-name show-popup-with-id">(.*?)</strong>} $data match real
				}
                        if {![regexp -nocase {<span class="username js-action-profile-name">.*?<b>(.*?)</b>.*?<span class="username js-action-profile-name">.*?<b>(.*?)</b>} $data match screen fscreen]} {
                        	regexp -nocase {<span class="username js-action-profile-name">.*?<b>(.*?)</b>} $data match screen
				}
 				#regexp -nocase {data-screen-name="(.*?)"} $data match screen
				#regexp -nocase {data-screen-name=".*?data-screen-name="(.*?)"} $data match fscreen
                        if {[regexp -nocase {"retweet_count"\:(.*?)(?:,\})} $data match rtw]} { 
                        	switch -- $rtw {
                        		0 { set rt "" }
                        		1 { set rt " - Retweeted by 1 person" }
                        		default { set rt " - Retweeted by $rtw people" }
					}
				} else { set rt "" }
				#regexp -nocase {class="tweet-url screen-name" hreflang="[a-z]{2}" title="(.*?)">(.*?)</a>} $data match real screen
				if {[info exists ftweet] && ![string equal $ftweet $ltweet]} {
					set firstline "\002[url_map [url_map @$screen]]\002 ([url_map [url_map $real]]): $ftweet\n"
					set real $freal ; set screen $fscreen
				} else { set firstline "" }
				return [list "$firstline\002[url_map [url_map @$screen]]\002 ([url_map [url_map $real]]): $ltweet \017( $ago$rt ) - $url" "twitter"]
			}
		}
	}
}

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


putlog "Url Title Grabber $urltitlever (rosc) script loaded.. (super action rocket missles by speechles :P)"



