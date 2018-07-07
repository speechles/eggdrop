# Whereis IP geolocation scrape script (v1.7)
# by speechles - Proof-of-concept 
# :: March 08th, 2015
# -- Cookies / Referer / 302 Redirects ---
#
# MAKE SURE TO: .chanset #yourchan +whereis 
# This script will not function in your channel
# until you've done this...
#
# --> http://www.ip-adress.com/ip_tracer/
# Scrapes the url above and generates relevant
# information to display onto irc. fully
# configurable, allows members to login, has
# full error handlers, redirects, cookies,
# and super action rocket missles.
#
#
# * v1.7 - added: Hex Ident detection when
#          resolving nicknames into hosts.
# * v1.6 - added: Html element transcoding
#          support.
# * v1.5 - added: Skip advertisement
#          in middle of redirects, now works
#          as did before. Enjoy ;)
# * v1.4 - added: Multiple Accounts:
#          Script can now use as many
#          accounts as you want, and it or
#          you can easily manage their use.
#          added: Http post requests:
#          along with post requests and 302
#          traversals required for logging in
#          it is now also required for fetching
#          requests when logged in as well.
# * v1.3 - added: EatForFree config option:
#          Script will wait until free
#          quota has been used up before
#          attempting to login to account.
# * v1.2 - auto-login mechanism added:
#          detects over quota useage on
#          free mode and will auto login
#          and detect remaining and daily
#          totals. quite effective. ;)
# * v1.1 - login mechanism added: 
#        - uses cookies/referer/redirection
# * v1.0 - first release
#
# -- by speechles (via egghelp.org forums)
# -- if you like this script donate to slennox. ;P

### fully commented, want to know how something works?
### every line explains it's purpose, just read comments
##
# --> CONFIG start

# This will allow you to customize your output.
# To see everything, only put "*" in the list below.
# Otherwise, put the tags you wish to see in the list
# and keep in mind the order you use is the order
# they will appear during output.
# Wildcards are acceptable, this is done using [string match]
# Case is irrelevant, we are using -nocase.
# - example below:
# variable whereisFilter [list "*city:" "*state:" "*country:" "*isp*"]
# this would show the city, state, country and isp of the user.
# ---
variable whereisFilter [list "*"]

# Set your theme here, use colors whatever you want
# using the 4 variables found immediately below:

# What symbols/text should seperate your output?
# --- 1
variable whereisDivider "; "

# How would you like your output to be rendered?
# There are two fields to each entry, Name and Value.
# You can put spaces, color, and other things here
# and they will be prefixed to the name and value
# when displayed.
# --- 2 3 4
variable whereisPrefix "" 
variable whereisName ""
variable whereisValue " \002"

# If you have an account you can set details
# for it below, and the script will login
# and use this info for requests.
# - !wlogin and !wlogout control this feature.
# - must be owner or master to use either.
# If you don't want to use this feature
# set whereisAlwaysLogin to 0.
# 
# NOTE: You can still set whereisAlwaysLogin
# to zero, and manually use !wlogin and
# !wlogout to manage the scripts use of your
# account as well...as well as using
# !wauto to turn this on and off at whim.
# ---
variable whereisAlwaysLogin 1

# set your accounts up here
# the method is simple
# "your-email@site.com:password-goes-here"
# add as many as you like, the script will
# cycle through them, or you can using
# !wnext and !wprev
# ---
variable whereisAccounts {
  "sup_g_likes_the_cock@sexy.com:cunts"
  "hey nigger stop touch my cock@blow.me:too"
  "stop being a dick@faggot.face:jew"
}

# If you want to use all the free quota of
# usage before letting the bot automatically
# use your account, see this option below to 1.
# ---
variable whereisEatForFree 1

# --< CONFIG end

# setup our binds
bind pub -|- !whereis whereis
bind pub mn|mn !wAuto whereisAuto
bind pub mn|mn !wlogin whereisLogin
bind pub mn|mn !wLogout whereisLogout
bind pub mn|mn !wStatus whereisStatus
bind pub mn|mn !wNext whereisNext
bind pub mn|mn !wPrev whereisNext

# setup our flag
setudef flag whereis

# we require http package commands
package require http

# initialize states only if they
# are empty. otherwise carry
# over states already known, the
# user can use !wlogout or !wlogin
# if this is ever incorrect.
if {![info exists whereisLogged]} {
  set whereisLogged 0
}
if {![info exists whereisCookies]} {
  set whereisCookies ""
}
if {![info exists whereisDaily]} {
  set whereisDaily 0
}
if {![info exists whereisRemain]} {
  set whereisRemain 0
}
if {![info exists whereisLogin]} {
  set whereisLogin 0
}
if {![info exists whereisAccPos]} {
  set whereisAccPos 0
}

proc whereisNext {nick uhost hand chan text} {
  # flag
  if {![channel get $chan whereis]} { return }
  # was this an automated request?
  if {[string equal "auto" $text]} {
    # yes, automated is always next
    set lb "!wNext"
  } else {
    # no, then read our last bind
    set lb $::lastbind
  }
  # decide which direction to go.
  switch -- $lb {
    # Move down the account list
    "!wPrev" { incr ::whereisAccPos -1
               if {$::whereisAccPos < 0} {
                 set ::whereisAccPos [expr {[llength $::whereisAccounts] -1}]
               }
               set w "Previous"
             }
    # Move up the account list
    "!wNext" { incr ::whereisAccPos 1
               if {[expr {$::whereisAccPos +1}] > [llength $::whereisAccounts]} {
                 set ::whereisAccPos 0
               }
               set w "Next"
             }
  }
  # find accout we are positioned on
  set acctInfo [split [lindex $::whereisAccounts $::whereisAccPos] :]
  # email
  set e [lindex $acctInfo 0]
  # message channel we found the account
  putserv "privmsg $chan :\002Whereis\002: $w Account ([expr {$::whereisAccPos + 1}]/[llength $::whereisAccounts]) $e"
  # login
  whereisLogin $nick $uhost $hand $chan $text
}

proc whereisAuto {nick uhost hand chan text} {
  # flag
  if {![channel get $chan whereis]} { return }
  # invert value of always login config option
  # this uses binary and, will cycle between 0 and 1
  # this does not overwrite the value, a .rehash
  # or .restart will return the original value.
  set ::whereisAlwaysLogin [expr {[incr ::whereisAlwaysLogin] % 2}]
  # is the present value 1?
  if {$::whereisAlwaysLogin > 0} {
    # yes - it's on
    putserv "privmsg $chan :\002Whereis\002: Enabled automatic account login."
  } else {
    # no - it's off
    putserv "privmsg $chan :\002Whereis\002: Disabled automatic account login."
  }
}

proc whereisStatus {nick uhost hand chan text} {
  # flag
  if {![channel get $chan whereis]} { return }
  # set account length count empty until needed
  set l ""
  # are we supposed to be logged in?
  if {$::whereisAlwaysLogin > 0} {
    if {$::whereisLogin > 0} {
      # yes, are we logged in?
      if {$::whereisLogged > 0} {
        # yes, find account we are positioned on
        set acctInfo [split [lindex $::whereisAccounts $::whereisAccPos] :]
        # email
        set e [lindex $acctInfo 0]
        # length of accounts list
        set l "([expr {$::whereisAccPos + 1}]/[llength $::whereisAccounts]) "
        # are we a gold member?
        if {![string equal "999" $::whereisDaily]} {
          # no, display normal account info
          putserv "privmsg $chan :\002Whereis\002: Always login; Logged in; Account ${l}($e; DailyLimit: \002$::whereisDaily\002 with \002$::whereisRemain\002 remaining.)"
        } else {
          # yes, display we are gold
          putserv "privmsg $chan :\002Whereis\002: Always login; Logged in; Account ${l}($e; Gold Member)"
        }
      } else {
        # no, spam that we aren't and we're in free mode
        putserv "privmsg $chan :\002Whereis\002: Account $l; Always login; Logged out; Free mode."
      }
    } else {
      # we haven't used the command or logged in yet.
      # are we eating for free?
      if {$::whereisEatForFree > 0} {
        # yes, display that we are
        putserv "privmsg $chan :\002Whereis\002: ${l}Always login; Eating for free; Free mode."
      } else {
        # no display that we are waiting to login instead
        putserv "privmsg $chan :\002Whereis\002: ${l}Always login; Waiting for login; Free mode."
      }
    }
  } else {
    # we are set to not login, so display this
    if {$::whereisLogged > 0} {
      # yes, find account we are positioned on
      set acctInfo [split [lindex $::whereisAccounts $::whereisAccPos] :]
      # email
      set e [lindex $acctInfo 0]
      # length of accounts list
      set l "([expr {$::whereisAccPos + 1}]/[llength $::whereisAccounts]) "
      # are we a gold member?
      if {![string equal "999" $::whereisDaily]} {
        # no, display normal account info
        putserv "privmsg $chan :\002Whereis\002: Never login; Logged in; Account ${l}($e; DailyLimit: \002$::whereisDaily\002 with \002$::whereisRemain\002 remaining.)"
      } else {
        # yes, display we are gold
        putserv "privmsg $chan :\002Whereis\002: Never login; Logged in; Account ${l}($e; Gold Member)"
      }
    } else {
      putserv "privmsg $chan :\002Whereis\002: Never login; Logged out; Free mode."
    }
  }
}


proc whereisLogout {nick uhost hand chan text} {
   # flag
   if {![channel get $chan whereis]} { return }
   # are we even logged in?
   if {$::whereisLogged > 0} {
     # yes, which accout are we logging out of?
     set acctInfo [split [lindex $::whereisAccounts $::whereisAccPos] :]
     set e [lindex $acctInfo 0]
     # we are now logged out
     putserv "privmsg $chan :\002Whereis\002: Logout Successful! Accout ([expr {$::whereisAccPos + 1}]/[llength $::whereisAccounts]) $e"
   } else {
     # we were never logged in, we didnt need to logout
     putserv "privmsg $chan :\002Whereis\002: Logout Successful! Never logged in..."
   }
   # initialize states and erase any stored cookies.
   set ::whereisLogin 0
   set ::whereisLogged 0
   set ::whereisCookies ""
   set ::whereisDaily 0
   set ::whereisRemain 0
}

proc whereisLogin {nick uhost hand chan text} {
   # flag
   if {![channel get $chan whereis]} { return }
   # set state that we want to be logged in
   set ::whereisLogin 1
   # set url
   set url "http://www.ip-adress.com/login/"
   # determine which account we are positioned on
   set acctInfo [split [lindex $::whereisAccounts $::whereisAccPos] :]
   # email
   set e [lindex $acctInfo 0]
   # password
   set p [lindex $acctInfo 1]
   # set query
   set query "login=$e&password=$p&submit=login&remember=1"
   # set referer
   set ref "$url?$query"
   # user agent
   ::http::config -useragent "Mozilla/5.0 ; Gecko"
   # get url using post method
   catch { set http [::http::geturl $url -query $query -timeout 10000] } error
   # error condition 1: invalid http session
   if {![string match -nocase "::http::*" $error]} {
      putserv "privmsg $chan :\002Whereis\002: Login Failed: [string totitle $error] \( $url \)"
      set ::whereisLogged 0
      return 0
   }
   # error condition 2: http error
   if {![string equal -nocase [::http::status $http] "ok"]} {
      putserv "privmsg $chan :\002Whereis\002: Login Failed: [string totitle [::http::status $http]] \( $url \)"
      set ::whereisLogged 0
      return 0
   }
   # initialize url and redirect counters
   set r 0 ; set url $ref
   # clear cookies
   set ::whereisCookies [list]
   # reassociate variables
   upvar #0 $http state
   # iterate through the meta array
   foreach {name value} $state(meta) {
     # do we have cookies?                                                                                                                                                                             
     if {[string equal -nocase $name "Set-Cookie"]} {
       # yes, add them to cookie list                                                                                                                                                                          
       lappend ::whereisCookies [lindex [split $value ;] 0]                                                                                                                                                             
     }                                                                                                                                                                                                             
   }
   # store http code into redirect
   set redir [::http::ncode $http]
   # is this really a redirect?
   while {[string match "*${redir}*" "303|302|301" ]} {
     # yes, iterate through the meta array
     foreach {name value} $state(meta) {
       # do we have a location to reference
       if {[regexp -nocase ^location$ $name]} {
         # yes, check if it's a partial uri
         if {![string match "http*" $value]} {
           # does it start with a slash?
           if {![string match "/" [string index $value 0]]} {
             # no, then we need to add that manually
             set value "[join [lrange [split $url "/"] 0 2] "/"]/$value"
           } else {
             # yes, then we can concat this to our primary url/
             set value "[join [lrange [split $url "/"] 0 2] "/"]$value"
           }
         }
         # check if redirects to self causing endless redirecting
         if {[string match [string map {" " "%20"} $value] $url]} { putserv "privmsg $chan :\002Whereis\002: redirect error (self to self)\( $url \)" ; return }
         # get url with cookies and referer
         catch {set http [::http::geturl "[string map {" " "%20"} $value]" -query $query -headers [list Referer $ref Cookie [join $::whereisCookies {;}]] -timeout [expr 1000 * 10]]} error
         # cache url for looping while
         set url [string map {" " "%20"} $value]
         # error condition 1: invalid http session
         if {![string match -nocase "::http::*" $error]} {
            putserv "privmsg $chan :\002Whereis\002: Login Failed: [string totitle $error] \( $value \)"
            set ::whereisLogged 0
            return 0
         }
         # error condition 2: http error
         if {![string equal -nocase [::http::status $http] "ok"]} {
            putserv "privmsg $chan :\002Whereis\002: Login Failed: [string totitle [::http::status $http]] \( $url \)"
            set ::whereisLogged 0
            return 0
         }
         # cache http code for looping while
         set redir [::http::ncode $http]
         # reassociate variables
         upvar #0 $http state
         # keep traversals to 10 or less
         if {[incr r] > 10} { putserv "privmsg $chan :\002Whereis\002: redirect error (>10 too deep) \( $url \)" ; return }
       }
     } 
   }
   # get data, to check if we are logged in or not
   set html [::http::data $http]
   # copy the html to a file here, this may be a stupid ad.
   # Need to do this so users can give the html for the
   # GOLD MEMBER and other accounts..      
   set c [open "whereis-tcl.html" w]
   puts $c $html
   close $c
   # bypass the stupid ad trying to get you to become a pay member....
   if {[regexp -nocase {\"/member/\">} $html]} {
     catch {set http [::http::geturl "http://www.ip-adress.com/member/" -headers [list Referer [string map {" " "%20"} $value] Cookie [join $::whereisCookies {;}]] -timeout [expr 1000 * 10]]} error
     # cache url for looping while
     # error condition 1: invalid http session
     if {![string match -nocase "::http::*" $error]} {
        putserv "privmsg $chan :\002Whereis\002: Login Failed: [string totitle $error] \( http://www.ip-adress.com/member \)"
        set ::whereisLogged 0
        return 0
     }
     # error condition 2: http error
     if {![string equal -nocase [::http::status $http] "ok"]} {
        putserv "privmsg $chan :\002Whereis\002: Login Failed: [string totitle [::http::status $http]] \( http://www.ip-adress.com/member \)"
        set ::whereisLogged 0
        return 0
     }
     # get html
     set html [::http::data $http]
   }
   # cleanup http token
   ::http::cleanup $http
   # cleanse html of problematic undisplayable characters
   regsub -all {(?:\n|\t|\v|\r|\x01)} $html " " html
   # check that 'login failed' isn't within the html
   if {![string match -nocase "*login failed*" $html]} { 
     # wasn't found, we must be logged in. ;)
     # do we have any quota left?
     if {![regexp -nocase {<div class="row2">.*?<span class="limit.*?>(.*?)</span.*?<span class="limit.*?>(.*?)</span.*?<span class="limit.*?>(.*?)</span><br>} $html - daily remain extra]} {
       # no, are we a gold member account?
       if {![regexp -nocase {Gold Member<br>} $html]} {
         # no, we should message we are exceeded...
         putserv "privmsg $chan :\002Whereis\002: Account quota appears to have been exceeded..."
         # then we should logout
         set lf [whereisLogout $nick $uhost $hand $chan $text]
         # and return 0 to indicate logged out
         return 0
       } else {
         # yes, we are a gold member, set some fake variables
         set daily 999 ; set remain 999 ; set extra 0
       }
     }
     # yes, set state as logged in
     set ::whereisLogged 1
     # track daily amount allowed
     set ::whereisDaily $daily
     # track remaining amount
     set ::whereisRemain [expr {$remain + $extra}]
     # are we a gold member?
     if {![string equal "999" $daily]} {
       # no, display normal account information
       putserv "privmsg $chan :\002Whereis\002: Login Successful! Account ([expr {$::whereisAccPos + 1}]/[llength $::whereisAccounts]) ($e; DailyLimit: \002$daily\002 with \002$::whereisRemain\002 remaining.)"
     } else {
       # yes, display we are gold
       putserv "privmsg $chan :\002Whereis\002: Login Successful! Account ([expr {$::whereisAccPos + 1}]/[llength $::whereisAccounts]) ($e; Gold Member)"
     }
     # return 1 to indicate login was successful. ;D
     return 1
   } else {
     # was found, we aren't logged in. ;(
     putserv "privmsg $chan :\002Whereis\002: Login Failed! Account ([expr {$::whereisAccPos + 1}]/[llength $::whereisAccounts]) $e"
     # set state that we aren't logged in
     set ::whereisLogged 0
     # move to next account, is there a next account?
     if {[expr {$::whereisAccPos +1}] == [llength $::whereisAccounts] && [llength $::whereisAccounts] > 1} {
       # no then logout we can't login, and no more accounts to cycle
       # reset account position
       set ::whereisAccPos 0
       # message channel we reached last account and failed to login
       putserv "privmsg $chan :\002Whereis\002: Out of Next Accounts..."
       # logout
       whereisLogout $nick $uhost $hand $chan $text
       # return 0 to indicate we couldn't login.
       return 0
     } else {
       # move to next account using auto
       whereisNext $nick $uhost $hand $chan "auto"
     }
   }
}

# html element transcoder
proc whereisDecode {text char} {
   set char [string tolower $char]
   # if nothing to transcode return text
   if {![string match *&* $text]} {return $text}
   # html entity map
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
  # convertfrom encoding...
  if {![string equal $char [encoding system]]} { set text [encoding convertfrom $char $text] }
  # convert html entities and sanitize string for subst
  set text [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] [string map $escapes $text]]
  # map remaining entities
  regsub -all -- {&#([[:digit:]]{1,5});} $text {[format %c [string trimleft "\1" "0"]]} text
  regsub -all -- {&#x([[:xdigit:]]{1,4});} $text {[format %c [scan "\1" %x]]} text
  regsub -all -- {\\x([[:xdigit:]]{1,2})} $text {[format %c [scan "\1" %x]]} text
  # apply transcoding
  set text [subst "$text"]
  # convertto encoding...
  if {![string equal $char [encoding system]]} { set text [encoding convertto $char $text] }
  # return transcoded text
  return $text
}

proc whereis {nick uhost hand chan text {maxed 0}} {
   # flag
   if {![channel get $chan whereis]} { return }
   # resolve nicknames to their irc hostmasks
   # this won't work correctly for cloaked (+x) users
   if {![string match "*.*" $text]} {
      set part [split [getchanhost [lindex [split $text] 0] $chan] @]
      foreach {ident host} $part { break }
      if {[info exists ident] && [string length [set ip [hexIdent $ident]]]} {
		set text $ip
	} elseif {[info exists host] && [string length $host]} {
		set text $host
	}
   }
   # useragent
   ::http::config -useragent "Mozilla/5.0 ; Gecko"
   # did we want to be logged in?
   if {(($::whereisLogin > 0 || $::whereisAlwaysLogin > 0) && $::whereisRemain > -1 && ($::whereisEatForFree <1 || $maxed == 1)) || $::whereisLogged > 0} {
     # yes, are we logged in already?
     if {$::whereisLogged == 0} {
       # no, attempt to login
       set lf [whereisLogin $nick $uhost $hand $chan $text]
     }
     # if we run out of remaining queries and we are logged in
     # let's say so, and logout for the query instead.
     if {$::whereisLogged > 0 && [incr ::whereisRemain -1] < 0} {
       putserv "privmsg $chan :\002Whereis\002: Quota of $::whereisDaily exceed..."
       set junk [whereisLogout $nick $uhost $hand $chan $text]
     }
     # set query line up for out post below
     set query [http::formatQuery "QRY" $text "lookup" 1 "submit" "IP Address or Host Lookup"]
     # post query, with error handler, cookies and referer used. This is logged in.
     catch { set http [::http::geturl "http://www.ip-adress.com/ip_tracer/" -query $query -headers [list referer "http://www.ip-adress.com/ip_tracer/" Cookie [join $::whereisCookies]] -timeout 10000 ] } error
   } else {
     # geturl, with error handler, no cookies or referer used. This is not logged in.
     catch { set http [::http::geturl "http://www.ip-adress.com/ip_tracer/$text" -timeout 10000 ] } error
   }
   # associate the state array
   upvar #0 $http state
   # error condition 1: invalid http session
   if {![string match -nocase "::http::*" $error]} {
      putserv "privmsg $chan :\002Whereis\002: [string totitle $error] \( http://www.ip-adress.com/ip_tracer/$text \)"
      return 0
   }
   # error condition 2: http error
   if {![string equal -nocase [::http::status $http] "ok"]} {
      putserv "privmsg $chan :\002Whereis\002: [string totitle [::http::status $http]] \( http://www.ip-adress.com/ip_tracer/$text \)"
      return 0
   }
   # logged in now uses a redirected catch after supplying required php session cookie
   # are we redirected?
   if {[string match "*[::http::ncode $http]*" "303|302|301" ]} {
     # yes, associate the state array
     upvar #0 $http state
     # iterate the state meta array
     foreach {name value} $state(meta) {
       # do we have a location field?
       if {[regexp -nocase ^location$ $name]} {
         # yes, traverse to it
         if {![string match "http*" $value]} {
           # does it start with a slash?
           if {![string match "/" [string index $value 0]]} {
             # no, then we need to add that manually
             set value "http://www.ip-adress.com/$value"
           } else {
             # yes, then we can concat this to our primary url/
             set value "http://www.ip-adress.com$value"
           }
         }
         catch {set http [::http::geturl "$value" -headers [list Referer "http://www.ip-adress.com/ip_tracer/" Cookie [join $::whereisCookies]] -timeout [expr 1000 * 10]]} error
         # error condition 1: invalid http session
         if {![string match -nocase "::http::*" $error]} {
           putserv "privmsg $chan :\002Whereis\002: [string totitle $error] \( http://www.ip-adress.com/ip_tracer/$text \)"
           return 0
         }
         # error condition 2: http error
         if {![string equal -nocase [::http::status $http] "ok"]} {
           putserv "privmsg $chan :\002Whereis\002: [string totitle [::http::status $http]] \( http://www.ip-adress.com/ip_tracer/$text \)"
           return 0
         }
       }
     }
   }
   # get html data, decoding any html elements to real characters.
   set data [whereisDecode [::http::data $http] $state(charset)]
   # cleanup http token
   ::http::cleanup $http
   # cleanse html for parsing
   regsub -all {\[<.*?>\]} $data "" data
   regsub -all "<script.*?>.*?</script>" $data "" data
   regsub -all "<a href.*?</a>" $data "" data
   regsub -all "<img src=.*?>" $data "" data
   regsub -all {(?:\n|\t|\v|\r|</span>)} $data "" data
   regsub -all {<span.*?>} $data "" data
   # can we retrieve table fields?
   while {[regexp -nocase -- {<th>(.*?)</th>.*?<td>(.*?)</td>} $data -> type attrib]} {
      # yes, add them to variables and partially cleanse them.
      set type [string map {"::" ":"} [string totitle [string trim [string map -nocase {"ip country code" "country code" "ip country" "country" "ip state" "state" "ip city" "city" "ip latitude" "latitude" "ip longitude" "longitude" " :" ":"} [string map -nocase {"ip address" "ip" " :" ":"} $type]]]]]
      # remove all excess spacing
      while {[string match "*  *" $type]} { regsub -all -- {  } $type " " type }
      # is this our own ip?
      if {[string match -nocase "my *" $type] && ![info exists own]} {
        # yes, these are free. increment our count back up
        incr ::whereisRemain 1
        # flag so we only do this once
        set own 0
      }
      # are we over quota?
      if {![string length [string trim $attrib]]} {
        # yes, is this the free account?
        if {$::whereisAlwaysLogin > 0 && $::whereisLogged < 1} {
          # yes, have we done this yet?
          if {![info exists doneit]} {
            # no, message channel we exceeded quota and attempt to login
            putserv "privmsg $chan :\002Whereis\002: Free quota has been exceeded..."
            # set flag so we don't do this again
            set doneit 0
            # attempt to login
            whereisLogin $nick $uhost $hand $chan $text
            # was the login successful?
            if {$::whereisLogged > 0} {
              # yes, retry logged in
              whereis $nick $uhost $hand $chan $text 1
              # we don't want to nest the recursion so return
              return
            } else {
              # disable automatic login, we can't login.
              whereisAuto $nick $uhost $hand $chan $text
              # set account position to first entry.
              set ::whereisAccPos 0
            }
          }
        }
      }
      # add variables to output list
      lappend output "[string totitle [string trim $type]]|[string trim $attrib]"
      # remove scraped table fields for looping while
      regsub -nocase -- {<th>.*?</th>.*?<td>.*?</td>} $data "" data
   }
   # do we have output?
   if {[info exists output]} {
     # yes, determine what exactly to output...
     foreach entry $::whereisFilter {
        foreach attribute $output {
           # does the attribute match any filter masks?
           if {[string match -nocase $entry [lindex [split $attribute |] 0]]} {
              # yes, add to spam list
              lappend spamline "$::whereisName[string trim [lindex [split $attribute |] 0]]\017$::whereisValue[string trim [lindex [split $attribute |] 1]]\017"
           }
        }
      }
      # was a spam list created?
      if {[info exists spamline]} {
         # if created, does it have any contents?
         if {[llength $spamline]} {
           # yes, spam first 9
           puthelp "privmsg $chan :$::whereisPrefix[join [lrange $spamline 0 8] $::whereisDivider]"
           # more than 9?
           if {[llength $spamline] > 8} {
              # yes, spam the rest
              puthelp "privmsg $chan :$::whereisPrefix[join [lrange $spamline 9 [llength $spamline]] $::whereisDivider]"
           }
         }
      } else {
         # we have output but nothing in the spam list, declare
         puthelp "privmsg $chan :$text returns some useful information for me to reply with, but filtering is preventing me from showing you... ;/"
      }
   } else {
      # we have no output at all, declare
      puthelp "privmsg $chan :$text returns no useful information for me to reply with... ;/"
      # if we are logged in, this doesn't count against our quota so add back the 1 we took away. ;)
      if {$::whereisLogged > 0} { incr ::whereisRemain 1 }
   }
}

proc hexIdent {a} {
	if {[string length $a] == 8} {
		while {[string length $a]} {
			set piece [string range $a 0 1]
			set a [string range $a 2 end]
			if {[regexp {^[a-fA-F0-9]+$} $piece]} {
				lappend ip [scan $piece %x]
				if {[llength $ip] == 4} { break }
			} else {
				set flag 1 ; break
			}
		}
		if {![info exists flag]} {
			return [join $ip "."]
		} else {
			return ""
		}
	} else {
		return ""
	}
}

putlog "Whereis.tcl v1.7 ([llength $::whereisAccounts] Accounts) ... loaded."

# eof

