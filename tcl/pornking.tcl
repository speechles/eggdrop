#---------------------------------------------------------------#
# incith:pornking                                           v1.0 #
#---------------------------------------------------------------#
package require http 2.3
setudef flag porn

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
  namespace eval pornking {
    # set this to the command character you want to use for the binds
    variable command_char "!"

    # set these to your preferred binds ("one two")
    variable binds "porn pfo"

    # how many results do you wish to show?
    variable howmany 5

    # if you want to allow users to search via /msg, enable this
    variable private_messages 1

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
  namespace eval pornking {
    variable version "incith:pornking-1.0"
  }
}

# bind the public binds
foreach bind [split $incith::pornking::binds " "] {
  bind pub -|- "${incith::pornking::command_char}$bind" incith::pornking::public_message
}

# bind the private message binds, if wanted
if {$incith::pornking::private_messages >= 1} {
  foreach bind [split $incith::pornking::binds " "] {
    bind msg -|- "${incith::pornking::command_char}$bind" incith::pornking::private_message
  }
}

namespace eval incith {
  namespace eval pornking {
    proc pornkings {input} {
      set html [fetch_html $input]
      if {![string match "*$input*" "|-new|-top5|"] && [regexp -- {</h2><p>(.+?)\.</p>} $html - totals]} {
       regexp -nocase {^(.*?) releases} $totals - totalz
       if {$totalz > $incith::pornking::howmany} { set also ", showing first $incith::pornking::howmany" } { set also "" }
       set output [list "\002pornking\002: $totals for ${input}${also}"]
      } else { 
        switch -- [string tolower $input] {
         "-new" { set output [list "\002pornking\002: Newest Releases..."] ; set totals 1 }
         "-top5" { set output [list "\002pornking\002: Top 5 Releases last 7 days..."] ; set totals ZZ }
        }
      }
      set count 1 ; regsub -- {<tr>.*?</tr>} $html "" html
      if {[string equal "ZZ" $totals]} {
        while {[regexp -- {<tr style.*?<td height="[0-9]{2}"><a href="/nfo/(.*?)">(.*?)</a></td><td><a href="/group/.*?">(.*?)</a></td><td><a href=".*?">(.*?)</a></td>} $html - link name group date]} {
          regsub -- {<tr style.*?</tr>} $html "" html
          lappend output "\002$date\002 \[$group\] $name @ [make_tiny "http://www.pornkingz.org/nfo/$link"]"
          incr count
         if {$count > $incith::mp3king::howmany} { break }
        }
      } else {
        while {[regexp -- {<tr style.*?<td height="[0-9]{2}"><a href="/nfo/(.*?)">(.*?)</a></td><td><a href="/group/.*?">(.*?)</a></td><td><a href="/date/.*?">(.*?)</a></td>} $html - link name group date]} {
         regsub -- {<tr style.*?</tr>} $html "" html
         lappend output "\002$date\002 \[$group\] $name @ [make_tiny "http://www.pornkingz.org/nfo/$link"]"
         incr count
         if {$count > $incith::pornking::howmany} { break }
        }
      }
      if {![info exists totals]} { return [list "\002pornking\002: Nothing found. Try again."] }
      return $output
    }

    proc make_tiny {url} {
      set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
      set http [::http::config -useragent $ua -useragent "utf-8"]
      set token [http::geturl "http://tinyurl.com/api-create.php?[http::formatQuery url $url]" -timeout 3000]
      upvar #0 $token state
      if {[string length $state(body)]} { return $state(body) }
      return $url
    }

    # FETCH_HTML
    # fetches html
    #
    proc fetch_html {input} {
      set query "http://www.pornkingz.org/search/[string map {" " "+"} $input]"
      # stole this bit from rosc2112 on egghelp forums
      # borrowed is a better term, all procs eventually need this error handler.
      switch -- [string tolower $input] {
        "-new"   { catch {set http [::http::geturl "http://www.pornkingz.org/index.php" -timeout [expr 1000 * 15]]} error }
        "-top5" { catch {set http [::http::geturl "http://www.pornkingz.org/topten/" -timeout [expr 1000 * 15]]} error }
        default  { catch {set http [::http::geturl "$query" -timeout [expr 1000 * 15]]} error }
      }
	if {[string match -nocase "*couldn't open socket*" $error]} {
            return "socketerrorabort|${query}"
	}
	if { [::http::status $http] == "timeout" } {
		return "timeouterrorabort"
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
      regsub -all {(?:\n|\r|\t|\v)} $html "" html
      regsub -all {(?:<b>|</b>)} $html "" html
      regsub -all {(?:<font style="background-color: #ff0;">|</font>)} $html "\002" html
      # DEBUG DEBUG                    
      set junk [open "webby.txt" w]
      puts $junk $html
      close $junk
      return $html
    }

    # PUBLIC_MESSAGE
    # decides what to do with binds that get triggered
    #
    proc public_message {nick uhand hand chan input} {
      if {[lsearch -exact [channel info $chan] +porn] != -1} {
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
      if {$incith::pornking::private_messages >= 1} {
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
  namespace eval pornking {
    # SEND_OUTPUT
    # no point having two copies of this in public/private_message{}
    #
    proc send_output {input where} {
      foreach line [pornkings $input] {
        putquick "PRIVMSG $where :$line"
      }
    }

    # FLOOD_INIT
    # modified from bseen
    #
    variable flood_data
    variable flood_array
    proc flood_init {} {
      if {$incith::pornking::ignore < 1} {
        return 0
      }
      if {![string match *:* $incith::pornking::flood]} {
        putlog "$incith::pornking::version: variable flood not set correctly."
        return 1
      }
      set incith::pornking::flood_data(flood_num) [lindex [split $incith::pornking::flood :] 0]
      set incith::pornking::flood_data(flood_time) [lindex [split $incith::pornking::flood :] 1]
      set i [expr $incith::pornking::flood_data(flood_num) - 1]
      while {$i >= 0} {
        set incith::pornking::flood_array($i) 0
        incr i -1
      }
    }
    ; flood_init

    # FLOOD
    # updates a nd returns a users flood status
    #
    proc flood {nick uhand} {
      if {$incith::pornking::ignore < 1} {
        return 0
      }
      if {$incith::pornking::flood_data(flood_num) == 0} {
        return 0
      }
      set i [expr ${incith::pornking::flood_data(flood_num)} - 1]
      while {$i >= 1} {
        set incith::pornking::flood_array($i) $incith::pornking::flood_array([expr $i - 1])
        incr i -1
      }
      set incith::pornking::flood_array(0) [unixtime]
      if {[expr [unixtime] - $incith::pornking::flood_array([expr ${incith::pornking::flood_data(flood_num)} - 1])] <= ${incith::pornking::flood_data(flood_time)}} {
        putlog "$incith::pornking::version: flood detected from ${nick}."
        putserv "notice $nick :$incith::pornking::version: flood detected, placing you on ignore for $::incith::pornking::ignore minute(s)! :P"
        newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::pornking::version flooding $incith::pornking::ignore
        return 1
      } else {
        return 0
      }
    }
  }
}

putlog " - $incith::pornking::version loaded."

# EOF
