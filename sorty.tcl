set handle [open "movies.txt" r]
set data [split [read $handle] \n]
set sorteddata [lsort -increasing $data] ; putlog "there are [llength $sorteddata] titles bro."
close $handle
set handle [open "movies-sorted.txt" w]
puts $handle [join $sorteddata \r\n]
close $handle