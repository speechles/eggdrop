#---------------------------------------------------------------#
# incith:mp3king                                           v1.0 #
#---------------------------------------------------------------#
package require http 2.3
setudef flag mp3

# 0 will typically disable an option, otherwise a value 1 or
# above will enable it.
#
namespace eval incith {
  namespace eval mp3king {
    # set this to the command character you want to use for the binds
    variable command_char "!"

    # set these to your preferred binds ("one two")
    variable binds "mp3 king nfo"

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
  namespace eval mp3king {
    variable version "incith:mp3king-1.0"
  }
}

# bind the public binds
foreach bind [split $incith::mp3king::binds " "] {
  bind pub -|- "${incith::mp3king::command_char}$bind" incith::mp3king::public_message
}

# bind the private message binds, if wanted
if {$incith::mp3king::private_messages >= 1} {
  foreach bind [split $incith::mp3king::binds " "] {
    bind msg -|- "${incith::mp3king::command_char}$bind" incith::mp3king::private_message
  }
}

namespace eval incith {
  namespace eval mp3king {
    proc mp3kings {input} {
      set html [fetch_html $input]
      if {![string match "*$input*" "|-new|-top5|"] && [regexp -- {</h2><p>(.+?)\.</p>} $html - totals]} {
       regexp -nocase {^(.*?) releases} $totals - totalz
       if {$totalz > $incith::mp3king::howmany} { set also ", showing first $incith::mp3king::howmany" } { set also "" }
       set output [list "\002mp3king\002: $totals for ${input}${also}"]
      } else { 
        switch -- [string tolower $input] {
         "-new" { set output [list "\002mp3king\002: Newest Releases..."] ; set totals 1 }
         "-top5" { set output [list "\002mp3king\002: Top 5 Releases last 7 days..."] ; set totals 1 }
        }
      }
      set count 1 ; regsub -- {<tr>.*?</tr>} $html "" html
      while {[regexp -- {<tr style.*?<td height="[0-9]{2}"><a href="/genre/.*?">(.*?)</a></td><td><a href="/nfo/(.*?)">(.*?)</a></td><td><a href="/group/.*?">(.*?)</a></td><td><a href=".*?">(.*?)</a></td>} $html - genre link name group date]} {
       regsub -- {<tr style.*?</tr>} $html "" html
       lappend output "\002$date\002 \[$genre\] $name \[$group\] @ [make_tiny "http://www.mp3kingz.org/nfo/$link"]"
       incr count
       if {$count > $incith::mp3king::howmany} { break }
      }
      if {![info exists totals]} { return [list "\002mp3king\002: Nothing found. Try again."] }
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
      set query "http://www.mp3kingz.org/search/[string map {" " "+"} $input]"
      # stole this bit from rosc2112 on egghelp forums
      # borrowed is a better term, all procs eventually need this error handler.
      switch -- [string tolower $input] {
        "-new"   { catch {set http [::http::geturl "http://www.mp3kingz.org/index.php" -timeout [expr 1000 * 15]]} error }
        "-top5" { catch {set http [::http::geturl "http://www.mp3kingz.org/topten/" -timeout [expr 1000 * 15]]} error }
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
      if {[lsearch -exact [channel info $chan] +mp3] != -1} {
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
      if {$incith::mp3king::private_messages >= 1} {
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
  namespace eval mp3king {
    # SEND_OUTPUT
    # no point having two copies of this in public/private_message{}
    #
    proc send_output {input where} {
      foreach line [mp3kings $input] {
        putquick "PRIVMSG $where :$line"
      }
    }

    # FLOOD_INIT
    # modified from bseen
    #
    variable flood_data
    variable flood_array
    proc flood_init {} {
      if {$incith::mp3king::ignore < 1} {
        return 0
      }
      if {![string match *:* $incith::mp3king::flood]} {
        putlog "$incith::mp3king::version: variable flood not set correctly."
        return 1
      }
      set incith::mp3king::flood_data(flood_num) [lindex [split $incith::mp3king::flood :] 0]
      set incith::mp3king::flood_data(flood_time) [lindex [split $incith::mp3king::flood :] 1]
      set i [expr $incith::mp3king::flood_data(flood_num) - 1]
      while {$i >= 0} {
        set incith::mp3king::flood_array($i) 0
        incr i -1
      }
    }
    ; flood_init

    # FLOOD
    # updates a nd returns a users flood status
    #
    proc flood {nick uhand} {
      if {$incith::mp3king::ignore < 1} {
        return 0
      }
      if {$incith::mp3king::flood_data(flood_num) == 0} {
        return 0
      }
      set i [expr ${incith::mp3king::flood_data(flood_num)} - 1]
      while {$i >= 1} {
        set incith::mp3king::flood_array($i) $incith::mp3king::flood_array([expr $i - 1])
        incr i -1
      }
      set incith::mp3king::flood_array(0) [unixtime]
      if {[expr [unixtime] - $incith::mp3king::flood_array([expr ${incith::mp3king::flood_data(flood_num)} - 1])] <= ${incith::mp3king::flood_data(flood_time)}} {
        putlog "$incith::mp3king::version: flood detected from ${nick}."
        putserv "notice $nick :$incith::mp3king::version: flood detected, placing you on ignore for $::incith::mp3king::ignore minute(s)! :P"
        newignore [join [maskhost *!*[string trimleft $uhand ~]]] $incith::mp3king::version flooding $incith::mp3king::ignore
        return 1
      } else {
        return 0
      }
    }
  }
}

putlog " - $incith::mp3king::version loaded."

# EOF
