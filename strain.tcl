# MARIJUANA STRAINS FOR EGGDROP
# by speechles @ #roms-isos on EFnet
# ---< (copyleft) 2015 >---

# Uses:
# wgeturl - simple http wrapper for eggdrop
#
# v1.2 - putting into a functional script
# v1.1 - introducing an easier way...
# v1.0 - the beginning...

setudef flag strain
package require http

# https url support (future may need this)
if {![catch {package require tls}]} {
	tls::init -ssl3 0 -ssl2 0 -tls1 1
	http::register https 443 [list ::tls::socket -require 0 -request 1]
}

namespace eval marijuana {

	bind pub - !bud [namespace current]::strain

	proc strain {n u h c t} {
		if {![channel get $c strain]} { return }
		set url "http://www.medicalmarijuanastrains.com/?[http::formatQuery s $t x 0 y 0]"
		putlog $url
		set data [wgeturl $url]
		if {[llength $data] < 2} { putserv "privmsg $c :[join $data]" }
		set html [lindex $data 0]
		array set lines {}
		array set ur {1 "" 2 "" 3 ""}
		set fh [open "crapcrap.txt" w] ; puts $fh $html ; close $fh
		if {[regexp {"lcenter">(.+?)<span class="comments">} $html - lines(1)]} {
			regexp {<div class="entry">.*?src="(.*?)"} $lines(1) - ur(1)
		}
		if {[regexp {"lcenter">.*?"lcenter">(.+?)<span class="comments">} $html - lines(2)]} {
			regexp {<div class="entry">.*?src="(.*?)"} $lines(2) - ur(2)
		}
		if {[regexp {"lcenter">.*?"lcenter">.*?"lcenter">(.+?)<span class="comments">} $html - lines(3)]} {
			regexp {<div class="entry">.*?src="(.*?)"} $lines(3) - ur(3)
		}
		foreach count {1 2 3} {
			set output [list]
			if {[info exists lines($count)]} {
				set text $lines($count)
				if {![string match -nocase "*strain name:*" $lines($count)]} { continue }
				regexp {^.*?(<strong>.*?$)} $text - text
				set text [string map [list \n "; " \v "" \r "" \t "" <strong> \002 </strong> \002 "Strain Type:" "\002Strain Type:\002"] $text]
				regsub -all {<.*?>} $text {} text
				foreach line [split $text {;}] {
					if {[string length [string trim $line]]} { lappend output $line }
				}
				foreach line [line_wrap [decode "<< [make_tiny $ur($count)] >> [join $output {; }]"]] {
					putserv "privmsg $c :$line"
				}
			}
		}
		if {![info exists lines(1)]} {
			putserv "privmsg $c :Can't find a marijuana strain with \"$t\" in it. You makin' it up?"
		}
	}
	
	proc wgeturl { url {type GET} {refer ""} {cookies ""} {re 0} {poison 0} } {
		http::config -useragent "Mozilla/Eggdrop Wget"
		# if we have cookies, let's use em ;)
		if {[string equal -nocase GET $type]} {
			if {![string length $cookies]} {
				catch {set token [http::geturl $url -binary 1 -timeout 10000]} error
			} else {
				catch {set token [::http::geturl $url -binary 1 -headers [list "Referer" "$refer" "Cookie" "[string trim [join $cookies {;}] {;}]" ] -timeout 10000]} error
			}
		} else {
			foreach {url query} [split $url ?] {break}
			if {![string length $cookies]} {
				catch {set token [http::geturl $url -query $query -binary 1 -timeout 10000]} error
			} else {
				catch {set token [::http::geturl $url -query $query -binary 1 -headers [list "Referer" "$refer" "Cookie" "[string trim [join $cookies {;}] {;}]" ] -timeout 10000]} error
			}
		}
		# error condition 1, invalid socket or other general error
		if {![string match -nocase "::http::*" $error]} {
			return [list "ERROR: [string totitle [string map {"\n" " | "} $error]] \( $url \)"]
			return 0
		}
		# error condition 2, http error
		if {![string equal -nocase [::http::status $token] "ok"]} {
			return [list "ERROR: [string totitle [::http::status $token]] \( $url \)"]
			http::cleanup $token
			return 0
		}
		upvar #0 $token state
		# iterate through the meta array to grab cookies
		foreach {name value} $state(meta) {
			# do we have cookies?
			if {[regexp -nocase ^Set-Cookie$ $name]} {
				# yes, add them to cookie list
				lappend ourCookies [lindex [split $value {;}] 0]
			}
		}
		# if no cookies this iteration remember cookies from last
		if {![info exists ourCookies] && [string length $cookies]} {
			set ourCookies $cookies
		}
		# recursive redirect support, 300's
		# the full gambit of browser support, hopefully ... ;)
		if {[string match "*[http::ncode $token]*" "303|302|301" ]} {
			foreach {name value} $state(meta) {
				if {[regexp -nocase ^location$ $name]} {
					if {![string match "http*" $value]} {
						# fix our locations if needed
						if {![string match "/" [string index $value 0]]} {
							set value "[join [lrange [split $url "/"] 0 2] "/"]/$value"
						} else {
							set value "[join [lrange [split $url "/"] 0 2] "/"]$value"
						}
					}
					# catch redirect to self's. There is one rule:
					# A url can redirect to itself a few times to attempt to
					# gain proper cookies, or referers. This is hard-coded at 2.
					# We catch the 3rd time and poison our recursion with it.
					# This will stop the madness ;)
					if {[string match [string map {" " "%20"} $value] $url]} {
						incr poison
						if {$poison > 2} {
							return [list "ERROR: Redirect error self to self \(3rd instance poisoned\) \( $url \)"]
							http::cleanup $token
							return 0
						}
					}
					# poison any nested recursion over 10 traversals deep. no legitimate
					# site needs to do this. EVER!
					if {[incr re] > 10} {
						return [list "ERROR: Redirect error (>10 too deep) \( $url \)"]
						http::cleanup $token
						return 0
					}
					# recursive redirect by passing cookies and referer
					# this is what makes it now work! :)
					if {![info exists ourCookies]} {
						http::cleanup $token
						return [wgeturl [string map {" " "%20"} $value] $url $type "" $re $poison]
					} else {
						http::cleanup $token
						return [wgeturl [string map {" " "%20"} $value] $url $type $ourCookies $re $poison]
					}
				}
			}
		}
		# waaay down here, we finally check the ncode for 400 or 500 codes
		if {[string match 4* [http::ncode $token]] || [string match 5* [http::ncode $token]]} {
			return [list "ERROR: Http resource is not available: [http::ncode $token] \( $url \)"]
			http::cleanup $token
			return 0
		}
		# --- return reply
		set data [http::data $token]
		set meta $state(meta)
		http::cleanup $token
		if {[info exists ourCookies]} {
			return [list $data $ourCookies]
		} else {
			return [list $data ""]
		}
	}

	proc make_tiny {url} {
		set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
		set http [::http::config -useragent $ua -useragent "utf-8"]
		set token [http::geturl "http://tinyurl.com/api-create.php?[http::formatQuery url $url]" -timeout 3000]
		upvar #0 $token state
		if {[string length $state(body)]} { return $state(body) }
		return $url
	}

	# LINE_WRAP
	# takes a long line in, and chops it before the specified length
	# http://forum.egghelp.org/viewtopic.php?t=6690
	#
	proc line_wrap {str {splitChr { }}} { 
 		set out [set cur {}]
		set i 0
		set len 400
		foreach word [split [set str][set str ""] $splitChr] { 
			if {[incr i [string length $word]] > $len} { 
				lappend out [join $cur $splitChr] 
				set cur [list $word] 
				set i [string length $word] 
			} else { 
				lappend cur $word 
			} 
			incr i 
  		} 
  		lappend out [join $cur $splitChr] 
	}

   proc decode {text {char utf-8}} {
      if {![string match *&* $text]} {return $text}
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
		&#8238; ""
      };
     set text [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] [string map $escapes $text]]
     regsub -all -- {&#([[:digit:]]{1,5});} $text {[encoding convertto $char [format %c [string trimleft "\1" "0"]]]} text
     regsub -all -- {&#x([[:xdigit:]]{1,4});} $text {[encoding converto $char [format %c [scan "\1" %x]]]} text
     return [subst "$text"]
   }
}
# eof