# GREATWALL
# 2016 speechles was here
# .chanset #yourchan +greatwall

package require http
package require tls
http::register https 443 [list ::tls::socket -require 0 -request 1]

namespace eval greatwall {

setudef flag greatwall

bind pub - !great [namespace current]::public

# recursive wget with cookies and referer
proc getdata { channel url {type GET} {refer ""} {cookies ""} {re 0} {poison 0} } {
   # user agent
   ::http::config -useragent "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
   # if we have cookies, let's use em ;)
   if {[string equal -nocase GET $type]} {
      if {![string length $cookies]} {
         catch {set token [http::geturl $url -timeout 10000]} error
      } else {
         catch {set token [::http::geturl $url -headers [list "Referer" "$refer" "Cookie" "[join $cookies {;}]" ] -timeout 10000]} error
      }
   } else {
      foreach {url query} [split $url ?] {break}
      if {![string length $cookies]} {
         catch {set token [http::geturl $url -query $query -binary 1 -timeout 10000]} error
      } else {
         catch {set token [::http::geturl $url -query $query -binary 1 -headers [list "Referer" "$refer" "Cookie" "[join $cookies {;}]" ] -timeout 10000]} error
      }
   }
   # error condition 1, invalid socket or other general error
   if {![string match -nocase "::http::*" $error]} {
      putserv "privmsg $channel :Error: [string totitle [string map {"\n" " | "} $error]] \( $url \)"
      return 0
   }
   # error condition 2, http error
   if {![string equal -nocase [::http::status $token] "ok"]} {
      putserv "privmsg $channel :Http error: [string totitle [::http::status $token]] \( $url \)"
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
      		putserv "privmsg $channel :HTTP Error: Redirect error self to self \(3rd instance poisoned\) \( $url \)"
                  http::cleanup $token
                  return 0
               }
            }
            # poison any nested recursion over 10 traversals deep. no legitimate
            # site needs to do this. EVER!
            if {[incr re] > 10} {
      	  putserv "privmsg $channel :HTTP Error: Redirect error (>10 too deep) \( $url \)"
              http::cleanup $token
              return 0
            }
            http::cleanup $token
            # recursive redirect by passing cookies and referer
            # this is what makes it now work! :)
            if {![info exists ourCookies]} {
               return [s:wget $channel [string map {" " "%20"} $value] $url $type "" $re $poison]
            } else {
               return [s:wget $channel [string map {" " "%20"} $value] $url $type $ourCookies $re $poison]
            }
         }
      }
   }
   # waaay down here, we finally check the ncode for 400 or 500 codes
   if {[string match 4* [http::ncode $token]] || [string match 5* [http::ncode $token]]} {
      putserv "privmsg $channel :Http resource is not available: [http::ncode $token] \( $url \)"
      http::cleanup $token
      return 0
   }
   # --- return reply
   set data [http::data $token]
   http::cleanup $token
   if {[info exists ourCookies]} {
      return [list $data $ourCookies]
   } else {
      return [list $data ""]
   }

} 

proc public {n u h c t} {
	if {![channel get $c greatwall]} { return }
	putlog "in the shit"
	set uri [lindex [split $t] 0]
	set url "http://www.greatfirewallofchina.org/index.php?[http::formatQuery  [list siteurl $uri]]"
	putlog "url = $url"
	set data [lindex [getdata $c $url] 0]
	putlog "shoulda got data"
	set out [list]
	if {[string length $data]} {
		putlog "got data $data"
		set fh [open "shit.txt" w] ; puts $fh $data ; close $fh
		set pairs [regexp -all -inline {<td class="resultlocation">(.*?)<.*?<td class="resultstatus.*?">(.*?)<} $data]
		foreach {- location status} $pairs {
			putlog "nabbing pairs"
			lappend out "$location \002$status\002"
		}
		if {[llength $out]} {
			putlog "putting shit out"
			putserv "privmsg $c :$u - [join $out "; "]"
		}
	} else {
		putlog "no shit to show"
		putserv "privmsg $c :There was nothing to output. So I output this message."
	}
}

}
#eof






