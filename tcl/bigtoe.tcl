bind pubm - "#testeggdropstuffs *" big_toe::track

namespace eval big_toe {
   proc track {nick uhost hand chan text} {
      set text [split $text \003]
      foreach sentence $text {
         if {[string match 4* $sentence]} {
            set addme [string range $sentence 1 end]
         } elseif {[string match 04* $sentence]} {
            set addme [string range $sentence 2 end]
         }
         if {[info exists addme]} {
            lappend result $addme
            unset addme
         }
      }
      if {[info exists result]} {
         putserv "privmsg #kangaroopocket :#Froglegs: <$nick> [join $result " "]"
      }
   }
}
#eof	

