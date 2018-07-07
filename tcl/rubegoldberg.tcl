proc RubeGoldbergMachine {min} {
  set values [list 0 0 0 0] ; set pos 0
  foreach subtract {512640 1440 60 1} {
    while {$min >= $subtract} {
      set values [lreplace $values $pos $pos [expr {[lindex $values $pos] + 1}]]
      set min [expr {$min - $subtract}]
    }
    incr pos
  }
  set pos 0 ; foreach index {y d h m} { if {[set value [lindex $values $pos]] > 0} { append new "$value$index " } ; incr pos }
  return [string trim $new]
}
