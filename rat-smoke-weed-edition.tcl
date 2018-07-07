# CONFIG STUFF
set bt(char) "."
set bt(ver) "11.0 (rat edition)"
set bt(trig) "$::nick"
set whoisinfo(port) 43
set whoisinfo(ripe) "whois.ripe.net"
set whoisinfo(arin) "whois.arin.net"
set whoisinfo(apnic) "whois.apnic.net"
set whoisinfo(lacnic) "whois.lacnic.net"
set whoisinfo(afrinic) "whois.afrinic.net"
set tg(all) ""
set bt(flood) 100:6
set bt(ignore) 1
set ::baseurl "http://justla.me"
set scripts [glob -nocomplain bm-*.tcl]
foreach line [split $scripts] {
	putlog "loading: $line ...";
	if {[catch {source $line} err]} { putlog "Error while loading $line: $err" } else { putlog "loaded: $line - complete" }
}
set bt(line_length) "300"
set bt(maxlines) "5"

# MAP COLORS AND MODES
proc bold {} { return "\002" }
proc b {} { return "\002" }
array set colors {blue \00302 green \00303 red \00304 purple \00306 orange \00307 yellow \00308 lightgreen \00309 lightblue \00312 pink \00313 grey \00314 lightgrey \00315 nocolor \003 bold \002 underline \037}
foreach {color code} [array get colors] { proc $color {} "return $code" } 

# WE NEED HTTP PACKAGE
package require http

# MASTERCHECK
proc mastercheck {n u h c t} {
	if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	global bt
	catch {set http [::http::geturl $::baseurl/boxinfo.tcl -timeout 15000]} error
	if {[string match "*error*" $error]} { putserv "PRIVMSG $c :connect error!" ; return 0 }
	if {[string match "*timeout*" $error]} { putserv "PRVMSG $c :timeout!"; return 0 }
	set html [::http::data $http]
	foreach line [split $html \n] {
		if {[string match "*set bt(ver) \"*" $line]} { string map -nocase { "\"" "" } $line; putserv "PRIVMSG $c :found version: boxinfo.tcl-v\002[lindex $line 2]\002, current version is: boxinfo.tcl-v\002$bt(ver)" }
	}
}

# COMMANDS
set tg(1) "io"
set tg(2) "glue"
set tg(3) "check"
set tg(4) "geo"
set tg(5) "speedtest"
set tg(6) "v6zone"
set tg(7) "ipv6"
set tg(10) "nmap"
set tg(11) "help"
set tg(13) "ip"
set tg(24) "sysinfo"
set tg(25) "bw"
set tg(26) "dns"
set tg(27) "country"
set tg(28) "trace"
set tg(29) "asn"
set tg(30) "ns"
set tg(31) "lagcheck"
set tg(35) "ping"
set tg(99) "update"
# BOT BINDS
bind pub - ${bt(char)}${bt(trig)}${tg(1)} pub:diskio
bind pub - ${bt(char)}${bt(trig)}${tg(2)} pub:glue
bind pub - ${bt(char)}${bt(trig)}${tg(3)} pc:scan_pub
bind pub - ${bt(char)}${bt(trig)}${tg(4)} bgeo
bind pub - ${bt(char)}${bt(trig)}${tg(5)} speedtest
bind pub - ${bt(char)}${bt(trig)}${tg(7)} v6ip
bind pub - ${bt(char)}${bt(trig)}${tg(10)} dns::port_scan
bind pub - ${bt(char)}${bt(trig)}${tg(11)} bhelp
bind pub - ${bt(char)}${bt(trig)}${tg(24)} dns::sysinfo
bind pub - ${bt(char)}${bt(trig)}${tg(25)} dns::bandwidth_pub
bind pub - ${bt(char)}${bt(trig)}${tg(26)} dns::host
bind pub - ${bt(char)}${bt(trig)}${tg(27)} pub:country
bind pub - ${bt(char)}${bt(trig)}${tg(28)} pub:trace
bind pub - ${bt(char)}${bt(trig)}${tg(29)} pub:asn
bind pub - ${bt(char)}${bt(trig)}${tg(30)} dns::ns
bind pub - ${bt(char)}${bt(trig)}${tg(31)} pub:lag:check
bind pub - ${bt(char)}${bt(trig)}${tg(35)} pub:ping
bind pub m ${bt(char)}${bt(trig)}${tg(99)} bmaster
# ALL BINDS
bind pub - ${bt(char)}${tg(all)}${tg(1)} pub:diskio
bind pub - ${bt(char)}${tg(all)}${tg(2)} pub:glue
bind pub - ${bt(char)}${tg(all)}${tg(3)} pc:scan_pub
bind pub - ${bt(char)}${tg(all)}${tg(4)} bgeo
bind pub - ${bt(char)}${tg(all)}${tg(5)} speedtest
bind pub - ${bt(char)}${tg(all)}${tg(7)} v6ip
bind pub - ${bt(char)}${tg(all)}${tg(10)} dns::port_scan
bind pub - ${bt(char)}${tg(all)}${tg(11)} bhelp
bind pub - ${bt(char)}${tg(all)}${tg(24)} dns::sysinfo
bind pub - ${bt(char)}${tg(all)}${tg(25)} dns::bandwidth_pub
bind pub - ${bt(char)}${tg(all)}${tg(26)} dns::host
bind pub - ${bt(char)}${tg(all)}${tg(27)} pub:country
bind pub - ${bt(char)}${tg(all)}${tg(28)} pub:trace
bind pub - ${bt(char)}${tg(all)}${tg(29)} pub:asn
bind pub - ${bt(char)}${tg(all)}${tg(30)} dns::ns
bind pub - ${bt(char)}${tg(all)}${tg(31)} pub:lag:check
bind pub - ${bt(char)}${tg(all)}${tg(35)} pub:ping
bind pub m ${bt(char)}${tg(all)}${tg(99)} bmaster
bind pub m .checkmaster mastercheck
bind raw - 391 raw:check:lag

# FLOOD
proc flood {uhost} { global bt lastbind dns_f dns
	set a [lindex [split $bt(flood) :] 0] ; set b [lindex [split $bt(flood) :] 1]
	if {[info exists dns_f($uhost)]} { incr dns_f($uhost) 1; if {$dns_f($uhost) > $a} { newignore *!*@${uhost} BOXINFO "flooding with: ($lastbind)" $bt(ignore); return 1 } } {set dns_f($uhost) 1}
	if {![string match "*unset dns_f($uhost)*" [utimers]]} { utimer $b "catch {unset dns_f($uhost)}" } ; return 0
}

proc formatbytesize {kbytes {dec 2}} { if {$kbytes > 1073741824} { set result [expr ${kbytes}.0 / 1073741824.0]; set sz "GB" } elseif {$kbytes > 1048576} { set result [expr ${kbytes}.0 / 1048576.0] ; set sz "MB" } else { set result [expr $kbytes / 1024.0] ; set sz "KB" }; set result "[format %.${dec}f $result]${sz}"; return $result }

proc bhelp {n u h c t} { global bt botnick; putserv "PRIVMSG $c :All commands are in format yourchar then trigger, example .${botnick}speedtest"; putserv "PRIVMSG $c :sysinfo bw dns:: country ns asn trace lagcheck ping v6zone ipv6 check speedtest glue ip io" }

proc bmaster {n u h c t} { set delay [expr {10+round(rand()*60)}]; putserv "PRIVMSG $c :Performing a update in ${delay}/s"; utimer $delay [list bupdate $c] }

proc bupdate {chan} { catch {set http [::http::geturl $::baseurl/boxinfo.tcl -timeout 15000]} error; if {[string match "*error*" $error]} { putserv "PRIVMSG $chan :connect error!" ; return 0 } ; if {[string match "*timeout*" $error]} { putserv "PRVMSG $chan :timeout!"; return 0 } ; set html [::http::data $http]; set fileId [open "boxinfo.tcl" "w"]; foreach line [split $html \n] { incr lines }; puts -nonewline $fileId $html ;putserv "PRIVMSG $chan :\002(\002boxinfo.tcl\002)\002 updated boxinfo.tcl ($lines)..."; close $fileId ;::http::cleanup $http;rehash }

proc pub:diskio {n u h c t} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	set dd [exec which dd]; set io [lindex $t 0] ; if {[string length $io] < 2} { set io "512" }
	if {$io > 10240} { putserv "PRIVMSG $c :$io too large, max 10240";return }
	putserv "PRIVMSG $c :Testing disk with ${io}\MB ... "
	if {[catch {set data [exec $dd bs=1M count=${io} if=/dev/zero of=test conv=fdatasync]} error] == 1} { regexp -- {\d+ bytes \((\d+).*B\) copied, (\d+.\d+) s, (\d+.\d+) MB/s} $error -> size sec speed ; putserv "PRIVMSG $c :Testfile: ${io}\MB, I/O Speed: ${speed}\MB\s Took: ${sec}/s"; file delete test }
}

proc speedtest {n u h c t} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	set delay [expr {10+round(rand()*60)}]
	if {[file exists speedtest-cli]} { putserv "PRIVMSG $c :[bold]([bold]Speedtest[bold])[bold] Running speed test in $delay seconds, please wait";utimer $delay [list sys:speedtest $c]
	} else { putserv "privmsg $c :[bold]([bold]Speedtest[bold])[bold] Missing speedtest-cli, please wait while i download it. Test will start in $delay seconds."; set useless [exec wget \-q http://justla.me/code/speedtest-cli \-\-no-check-certificate]; utimer $delay [list sys:speedtest $c] }
}

proc sys:speedtest {chan} {
	putserv "PRIVMSG $chan :[bold]([bold]Speedtest[bold])[bold]: Completed... "
	set start [clock clicks -milliseconds];	set python [exec which python]
	set data [exec $python speedtest-cli \-\-share \-\-simple]
	regexp -line -- {Ping: (.*)} $data -> ping; regexp -line -- {Upload: (.*)} $data -> upload
	regexp -line -- {Download: (.*)} $data -> download; regexp -line -- {Hosted by (.*)} $data -> server
	regexp -line -- {Share results: (.*)} $data -> url; set taken [expr [clock clicks -milliseconds] - $start]
	set runtime [expr $taken / 1000 % 60]; putserv "PRIVMSG $chan :[bold]([bold]Speedtest[bold])[bold]: Ping: [bold]$ping[bold], Upload: [bold]$upload[bold] Download: [bold]$download[bold] - [bold]([bold]runtime: $runtime/sec[bold])[bold] - URL:[bold] $url"
}

proc pc:scan_pub {nick uhost hand chan text} { if {[flood [string range $uhost [expr [string last @ $uhost]+1] e]]} {return 0}
	set host [lindex $text 0]; set port [lindex $text 1]
	if {$port == ""} { putquick "PRIVMSG $chan :Usage: $::lastbind <host> <port>"
	} else {
		if {[catch {set sock [socket -async $host $port]} error]} { putquick "PRIVMSG $chan :\002PORTCHECK:\002 $host:$port was refused."
		} else { set timerid [utimer 15 [list pc:timeout_pub $chan $sock $host $port]]; fileevent $sock writable [list pc:connected_pub $chan $sock $host $port $timerid] }
	}
}

proc pc:connected_pub {chan sock host port timerid} { killutimer $timerid
	if {[set error [fconfigure $sock -error]] != ""} {
		close $sock;putquick "PRIVMSG $chan :\002PORTCHECK:\002 $host:$port failed. \([string totitle $error]\)"
	} else {
		fileevent $sock writable {}
		fileevent $sock readable [list pc:read_pub $chan $sock $host $port]
		putquick "PRIVMSG $chan :\002PORTCHECK:\002 $host:$port accepted."
	}
}

proc pc:timeout_pub {chan sock host port} { close $sock; putquick "PRIVMSG $chan :$host:$port timed out." }

proc pc:timeout_join {sock} { close $sock }

proc pc:read_join {sock} { close $sock }

proc pc:read_pub {chan sock host port} { if {[gets $sock read] == -1} { putquick "PRIVMSG $chan :EOF $host:$port Socket Closed."; close $sock } else { close $sock } }

proc bgeo {n u h c t} {
	catch {set http [::http::geturl http://freegeoip.net/xml/[lindex $t 0] -timeout 6000]} error
	if {[string match "*error*" $error]} { putserv "PRIVMSG $c :connect error!" ; return 0 }
	if {[string match "*timeout*" $error]} { putserv "PRVMSG $c :timeout!"; return 0 }
	set html [::http::data $http]
	if {[string match "*Not Found*" $html]} { putserv "PRIVMSG $c :[bold]GeoIP[bold]: No data found." ; return }
	regexp -line -- {<Ip>(.*)</Ip>} $html -> ip
	regexp -line -- {<CountryCode>(.*)</CountryCode>} $html -> CC
	regexp -line -- {<CountryName>(.*)</CountryName>} $html -> CN
	regexp -line -- {<RegionCode>(.*)</RegionCode>} $html -> RC
	regexp -line -- {<RegionName>(.*)</RegionName>} $html -> RN
	regexp -line -- {<City>(.*)</City>} $html -> CITY
	regexp -line -- {<ZipCode>(.*)</ZipCode>} $html -> ZIPCODE
	regexp -line -- {<Latitude>(.*)</Latitude>} $html -> LAT
	regexp -line -- {<Longitude>(.*)</Longitude>} $html -> LONG
	regexp -line -- {<MetroCode>(.*)</MetroCode>} $html -> MC
	regexp -line -- {<AreaCode>(.*)</AreaCode>} $html -> AC
	putserv "PRIVMSG $c :[bold]GeoIP[bold] [bold]IP[bold]: $ip [bold]Country Code[bold]: $CC [bold]Country Name[bold]: $CN [bold]Region Code[bold]: $RC [bold]Region Name[bold]: $RN [bold]City[bold]: $CITY [bold]Zip[bold]: $ZIPCODE [bold]Latitude[bold]: $LAT [bold]Longitude[bold]: $LONG [bold]Metro Code[bold]: $MC [bold]Area Code[bold]: $AC"
	http::cleanup $http
}

proc pub:lag:check {nick host hand chan test} { if {[flood [string range $host [expr [string last @ $host]+1] e]]} {return 0}; set ::lag "[clock clicks]";set ::lagchan $chan; putquick "TIME" }

proc raw:check:lag {from key text} { putmsg $::lagchan "\273\273 Current Networklag: [expr (([clock clicks] - $::lag)/2)/1000.] ms"; unset ::lagchan;unset ::lag }

proc pub:ping {n u h c t} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	if {[string match "*:*" $t]} { set pingexec "/bin/ping6" } else { set pingexec "/bin/ping" }
	if {![catch {set data [exec $pingexec -c4 $t]} error]} { foreach line [split $data "\n"] { if {[string match "*64 bytes from*" $line]} { regexp -- {from (.*?): } $line -> ip; regexp -- {time=(.*?)ms} $line -> tim; if {[string match "*packets transmitted*" $line]} { set footer "$line" } } }
		putserv "PRIVMSG $c :\002(\002IP\002)\002: $ip \002${tim}\002ms"
	}
	foreach l [split $error "\n"] { if {[string match "*packet loss*" $l]} { putserv "PRIVMSG $c :\002(\002IP\002)\002: stats: $l" } }
}

proc pub:asn {n u h c txt} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	regsub -all { } $txt {} txt
	set host [string trim [lindex [split $txt] 0]]
	if {[regexp {^[a-zA-Z]} $host]} {
		putserv "PRIVMSG $c :\002(\002ASN\002)\002: Please use IP format." ; return 0
	} else {
		if {![catch {set tmp [exec whois -h whois.cymru.com $host]} error]} {
			foreach line [split $error "\n"] { if {[regexp -all {(\d+)\s+\|\s(.*?)\s+\|\s(.*?)\s-\s(.*?)} $line -> id ip x company]} { putserv "PRIVMSG $c :\002(\002ASN:$id\002)\002: IP: \002$ip\002. Company: \002$company\002." } else { putserv "PRIVMSG $c :\002ASN\002(raw) - $line" ) }
		} else { putserv "PRIVMSG $c :error: $error" }
	}
}

proc pub:trace {n u h c txt} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	regsub -all { } $txt {} txt
	if {![catch {set tmp [exec dig -x $txt +trace]} error]} {
		putserv "PRIVMSG $c :\002(\002TRACE\002)\002 Requestiong information, please wait..."
		set out ""
		foreach line [split $tmp "\n"] {
			if {[string match "*;;*" $line]} { continue }
			if {[string match "*servers.*." $line]} { continue }
			if {[string match "*PTR*" $line]} { continue }
			if {[string match "*arin.net." $line]} { continue }
			if {[string match "*authdns::*" $line]} { continue }
			if {[string match "sec*.*" $line]} { continue }
			if {[string match "*apnic.net." $line]} { continue }
			if {[string match "*lacnic.net." $line]} { continue }
			if {[string match "*be*reached*" $line]} { putserv "PRIVMSG $c :\002(\002TRACE\002)\002: No servers could be reached!" ; return 0 }
			if {[string match "*NS*" $line]} { append out "[lindex $line 4] " }
		}
		if {[string match "" $out]} { putserv "PRIVMSG $c :\002(\002TRACE\002)\002 Nothing found."; return }
		putserv "PRIVMSG $c :\002(\002TRACE\002)\002 IP: ($txt) $out"
	} else { putserv "PRIVMSG $c :\002(\002TRACE\002)\002 Timeout." }

}



namespace eval dns {
	variable api "/proc/net/dev"
	# %IFN% : example eth0 # %IFA% : example WAN # %INC% : Incomming traffic # %OUT% : Outgoing traffic
	variable template "Incoming: \(\002%INC%\002\) Outgoing: \(\002%OUT%\002\)."
	# 0: privmsg to channel # 1: privmsg to nick # 2: notice to nick
	variable msgtype "0"; variable version 0.2



	proc host {n u h c txt} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
		regsub -all { } $txt {} txt
		set nickhost [lindex $txt 0]
		set host [string trim [lindex [split $txt] 0]]
		if {[string length $host] < 2} { putserv "PRIVMSG $c :try a valid host" ; return }
		if {[string length $host] > 65} { putserv "PRIVMSG $c :domain too long..less then 63 letters and numbers..idiot. example: 63lettersornumbers.com"; return }
		if {![catch {set tmp [exec host -tA $nickhost]} error]} { v4 $nickhost $c } else { putserv "PRIVMSG $c :\002(\002dns\002)\002 No A Record." }
		if {![catch {set tmp [exec host -tAAAA $nickhost]} error]} { v6 $nickhost $c } else { putserv "PRIVMSG $c :\002(\002dns\002)\002 No AAAA Record." }
	}
	proc v6 {host chan} {
		if {![catch {set data [exec host -tAAAA $host]} error]} {
			foreach line [split $data "\n"] { if {[string match "*has no*" $line]} { putserv "PRIVMSG $chan :\002(\002dns\002)\002 No AAAA record found."; return }
				if {[regexp {(.*) has IPv6 address (.*)} $line match rHost6 output]} { putserv "PRIVMSG $chan :\002(\002dns\002)\002: \002$rHost6\002 resolves to: \002$output\002, reverse: \002[rv6 $output]"  }
				if {[regexp {(.*) domain name pointer (.*)} $line match rHost6 output]} { putserv "PRIVMSG $chan :\002(\002dns\002)\002: \002$rHost6\002 resolves to: \002$output\002" }
			}
		}
	}
	proc rv6 {host} {
		if {![catch {set result [exec host -tAAAA $host]} error]} {
			foreach line [split $result "\n"] { if {[regexp {(.*) domain name pointer (.*)} $line found host result]} { return $result }
			}
		} else { return "\002none!" }
	}
	proc ns {n u h c t} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
		regsub -all { } $t {} t
		set host [lindex $t 0]
		if {![catch {set data [exec host -tNS $host]} error]} {
			foreach line [split $data "\n"] { if {[regexp {(.*) name server (.*)} $line match rHost4 output]} { putserv "PRIVMSG $c :\002(\002NS\002)\002: \002$rHost4\002 NS->: \002$output\002" } }
		}
		if {[string match "*NXDOMAIN*" $error]} { putserv "PRIVMSG $c :\002(\002NS\002)\002 No NS record found."; return }
	}
	proc v4 {host chan} {
		if {![catch {set data [exec host -tA $host]} error]} {
			foreach line [split $data "\n"] {
				if {[string match "*has no*" $line]} { putserv "PRIVMSG $chan :\002(\002\002)\002 No A record found."; return }
				if {[regexp {(.*) has address (.*)} $line match rHost4 output]} { putserv "PRIVMSG $chan :\002(\002dns\002)\002: \002$rHost4\002 resolves to: \002$output\002, reverse: \002[rv4 $output]" }
			}
		}
	}
	proc rv4 {host} {
		if {![catch {set result [exec host -tPTR $host]} error]} {
			foreach line [split $result "\n"] {
				if {[regexp {(.*) domain name pointer (.*)} $line found host result]} { return $result }
			}
		} else { return "\002none!" }
	}

	switch -regexp [string tolower $::tcl_platform(platform)] {
		"win" { variable switch 1 }
		"unix" { variable switch 2 }
		".*" { variable switch 0 }
	}
	switch  -exact $msgtype {
		"0" { variable msg "PRIVMSG %CHAN%" }
		"1" { variable msg "PRIVMSG %NICK%" }
		"2" { variable msg "NOTICE %NICK%" }
	}
	proc f {value} {
		set test $value ; set unit 0
		while {[set test [expr {$test / 1024}]] > 0} { incr unit }
		return [format "%.2f %s" [expr {$value / pow(1024,$unit)}] [lindex [list B KB MB GB TB PB EB ZB YB] $unit]]
	}
	proc totals {n u h c t} {
		set ifacelist [exec cat /proc/net/dev]
		foreach line [split $ifacelist "\n"] {
			if {[string match "*:*" $line]} {
				regsub -all {:} $line { } line; set iface "[lindex $line 0]"; set network "$iface:NET"
				catch {exec cut \-d. \-f1 /proc/uptime} reply; set secs [expr $reply % 60]; set mins [expr $reply / 60 % 60]; set hours [expr $reply / 3600 % 24]; set days [expr $reply / 86400]
				set uptime "${days}d ${hours}h ${mins}m ${secs}s"
				if {![catch {set data [exec /sbin/ifconfig $iface]} error]} {
					foreach line [split $data "\n"] {
						if {[string match "*RX bytes*" $line]} { set rxb [lindex [split [lindex $line 1] ":"] 1] ;set txb [lindex [split [lindex $line 5] ":"] 1]
							if {![string match "0" $rxb] && ![string match "0" $txb]} {
								if {[string match "*lo*" $$network]} { continue }
								putserv "PRIVMSG $c :\002\[\002$network\002\]\002: total of [f $rxb] incoming, total of [f $txb] outgoing in $uptime."
							}
						}
					}
				}
			}
		}
	}
	proc bandwidth_pub {nick host hand chan arg} {
		if {[string match "-t" $arg]} { totals $nick $host $hand $chan $arg ; return 1 } else {
			variable switch; variable template; variable ::interface; variable msg; variable api
			array set s_inc {}; array set s_out {}; array set e_inc {}; array set e_out {}
			set ifacelist [exec cat /proc/net/dev]
			foreach line [split $ifacelist "\n"] {
				if {[string match "*:*" $line]} {
					regsub -all {:} $line { } line
					set ::interface "[lindex $line 0]"
					set ifl "\002\[\002${::interface}:BW\002\]\002"
					if {[string equal 0 $switch]} {
						putlog "Error unknown operating system."
					} elseif {[string equal "1" $switch]} {
						if {[regexp -nocase {^(win):([a-zA-Z0-9\-]{1,100})$} $::interface -> ifn ifa]} {
							foreach {x} [split [exec netstat -e] \n] { if {[string equal -nocase -length 4 byte $x]} { set sinc [lindex $x 1];set sout [lindex $x 2] } }
							after 500
							foreach {x} [split [exec netstat -e] \n] { if {[string equal -nocase -length 4 byte $x]} { set einc [lindex $x 1]; set eout [lindex $x 2] } }
							putserv "[string map [list %NICK% $nick %CHAN% $chan] $msg] :$ifn [string map [list %IFN% $ifn %IFA% $ifa %INC% [format %.2f [expr ($einc - $sinc) / 512.0]] %OUT% [format %.2f [expr ($eout - $sout) / 512.0]]] $template]"
						} else { putlog "Script misconfiguration, check your settings." }
					} elseif {[string equal "2" $switch]} {
						if {[file exists $api]} {
							if {[file readable $api]} {
								if {[regexp {win:} $::interface]} {
									putlog "Script misconfiguration, check your settings."
								} else {
									if {[catch {open $api} rf]} {
										putlog "Error couldn't open $api for an unknown reason."
									} else {
										while {![eof $rf]} {
											gets $rf x
											foreach {ifn ifa} [split $::interface \x3a\x2c] {
												regexp "$ifn:\[\x20\t\]{0,100}(\[0-9\]{1,100})\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}(\[0-9\]{1,100})\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}" $x -> s_inc($ifn) s_out($ifn)
											}
										}
										close $rf
									}
									after 1000
									if {[catch {open $api} rf]} {
										putlog "Error couldn't open $api for an unknown reason."
									} else {
										while {![eof $rf]} {
											gets $rf x
											foreach {ifn ifa} [split $::interface \x3a\x2c] {
												if {[regexp "$ifn:\[\x20\t\]{0,100}(\[0-9\]{1,100})\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}(\[0-9\]{1,100})\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}\[\x20\t\]{1,100}\[0-9\]{1,100}" $x -> e_inc($ifn) e_out($ifn)]} {
													if {![string match "0.00" [format %.2f [expr ($e_inc($ifn) - $s_inc($ifn)) / 512.0]]] && ![string match "0.00" [format %.2f [expr ($e_inc($ifn) - $s_inc($ifn)) / 512.0]]]} {
														set testin [formatbytesize [expr $e_inc($ifn) - $s_inc($ifn)]]
														set testout [formatbytesize [expr $e_out($ifn) - $s_out($ifn)]]
														putserv "[string map [list %NICK% $nick %CHAN% $chan] $msg] :$ifl [string map [list %IFN% $ifn %IFA% $ifa %INC% $testin %OUT% $testout] $template]"
													}
												}
											}
										}
										close $rf
									}
								}
							} else { putlog "Error $api is not readable."  }
						} else { putlog "Error $api does not exist." }
					} else { putlog "Error unknown operating system." }
				}
			}
		}
	}

	proc sysinfo {n u h c t} {
		global bt
		if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
		set output "Hostname: \002[hostname]\002, Distribution: \002[distrib]\002, OS: \002$::tcl_platform(os) $::tcl_platform(osVersion)/$::tcl_platform(machine)\002, CPU: \002[cpu]\002, Load Average: \002[loadavg]\002, Processes: \002[processes]\002, Memory Used: \002[memory]\002, Disk: \002[disk]\002, Uptime: \002[uptime]\002, Users: \002[users]\002."
		set lines [split_line $bt(line_length) $output $c]
	}

	proc cpu {{default {Unknown}}} {
		if {[set cpuinfo [readfile /proc/cpuinfo]] ne {} && [regexp -line -- {model name\s*:\s*(.*)} $cpuinfo -> modelname] && [regexp -line -- {cpu MHz\s*:\s*(.*)} $cpuinfo -> cpumhz] && [set processors [regexp -all -line -- {processor\s*:.*} $cpuinfo]]} {
			return "${processors}x [string map [list {(R)} "\u00AE" {(TM)} "\u2122" {(C)} "\u00A9" {     } { } {  } { } {   } { } {    } { }] $modelname] ([format %.0f $cpumhz]MHz)"
		} else {
			return $default
		}
	}
	proc loadavg {{default {0}}} {
		if {[set loadavg [readfile /proc/loadavg]] ne {}} {
			if {[string match "0.*" [lindex $loadavg 0]]} { return "[green] [lindex $loadavg 0][nocolor]" }
			if {[string match "*1.*" [lindex $loadavg 0]]} { return "[green] [lindex $loadavg 0][nocolor]" }
			if {[string match "*2.*" [lindex $loadavg 0]]} { return "[green] [lindex $loadavg 0][nocolor]" }
			if {[string match "*3.*" [lindex $loadavg 0]]} { return "[green] [lindex $loadavg 0][nocolor]" }
			if {[string match "*4.*" [lindex $loadavg 0]]} { return "[yellow] [lindex $loadavg 0][nocolor]" }
			if {[string match "*5.*" [lindex $loadavg 0]]} { return "[yellow] [lindex $loadavg 0][nocolor]" }
			if {[string match "*6.*" [lindex $loadavg 0]]} { return "[red] [lindex $loadavg 0][nocolor]" }
			if {[string match "*7.*" [lindex $loadavg 0]]} { return "[red] [lindex $loadavg 0][nocolor]" }
			if {[string match "*8.*" [lindex $loadavg 0]]} { return "[red] [lindex $loadavg 0][nocolor]" }
			return [lindex $loadavg 0]
		} else { return $default }
	}
	proc uptime {{default {Unknown}}} { if {[set uptime [readfile /proc/uptime]] ne {}} { secstodays [lindex $uptime 0] } else { return $default } }
	proc distrib {{default {Linux}}} {
		if {[file exist /etc/debian_version] && [file exist /etc/os-release]} { regexp -line -- {NAME="(.*)"} [readfile /etc/os-release] -> distro;regexp -line -- {VERSION="(.*)"} [readfile /etc/os-release] -> version;return "[blue]$distro $version[nocolor]"
		} elseif {[file exist /etc/debian_version]} { return "[blue]Debian [readfile /etc/debian_version][nocolor]"
		} elseif {[file exist /etc/os-release]} { regexp -line -- {NAME="(.*)"} [readfile /etc/os-release] -> distro; regexp -line -- {VERSION="(.*)"} [readfile /etc/os-release] -> version; return "[lightgreen]$distro $version[nocolor]"
		} elseif {[file exist /etc/centos-release]} { return [yellow][readfile /etc/centos-release][nocolor]
		} else { return $default
		}
	}
	proc distrib2 {{default {Linux}}} {
		if {[set lsbinfo [readfile /etc/lsb-release]] ne {}} { set lsbdesc $default; regexp -line -- {DISTRIB_DESCRIPTION="(.*)"} $lsbinfo -> lsbdesc; return $lsbdesc
		} elseif {[set lsbdesc [readfile /etc/debian_version]] ne {}} { return "Debian $lsbdesc"
		} elseif {[file exist /etc/centos-release]} { return [readfile /etc/centos-release]
		} else { return $default }
	}
	proc memory {{default {?}}} {
		if {[set meminfo [readfile /proc/meminfo]] ne {} && [regexp -line -- {Buffers:\s*(\d+) kB} $meminfo -> membuff] && [regexp -line -- {MemTotal:\s*(\d+) kB} $meminfo -> memtotal] && [regexp -line -- {MemFree:\s*(\d+) kB} $meminfo -> memfree] && [regexp -line -- {Cached:\s*(\d+) kB} $meminfo -> cached]} {
			set memused [expr { $memtotal - $memfree - $cached - $membuff }]; return "[format %.0f [expr { $memused / 1024.0 }]]MB/[format %.0f [expr { $memtotal / 1024.0 }]]MB"
		} else {
			if {[set meminfo [readfile /proc/meminfo]] ne {} && [regexp -line -- {MemTotal:\s*(\d+) kB} $meminfo -> memtotal] && [regexp -line -- {MemFree:\s*(\d+) kB} $meminfo -> memfree] && [regexp -line -- {Cached:\s*(\d+) kB} $meminfo -> cached]} {
				set memused [expr { $memtotal - $memfree - $cached }]; return "[format %.0f [expr { $memused / 1024.0 }]]MB/[format %.0f [expr { $memtotal / 1024.0 }]]MB"
			} else { return $default }
		}
	}

	proc disk {} {
		set data [exec df \-h \-x tmpfs \-x udev]
		foreach line [split $data "\n"] {
			if {[string match "*/*" $line] && ![string match "*uuid*" $line]} {
				set mount [lrange $line end end]
				if {![string match "*dev*" $mount]} {
					set per [lrange $line end-1 end-1]
					set unused [lrange $line end-2 end-2]
					set used [lrange $line end-3 end-3]
					set total [lrange $line end-4 end-4]
					append out "\002\[\002M\002\]\002: $mount \002\[\002U%\002\]\002: $per \002\[\002F\002\]\002: $unused \002\[\002U\002\]\002: $used \002\[\002T\002\]\002: $total - "
				}
			}
		}
		return $out
	}
	proc disk2 {} {
		if {![catch {set data [exec df \-h \-x udev \-x tmpfs \-x udev]} error]} {
			foreach line [split $data "\n"] {
				if {![string match "*Mounted*" $line]} {
					regsub -all {    } $line {} line; regsub -all {/dev/sd[a-z][0-9]} $line {} line
					regsub -all {/dev/simfs} $line {} line; regsub -all {/dev/xvd[a-z][0-9]} $line {} line
					regsub -all {udev} $line {} line
					if {[string match "*boot*" $line]} { continue }
					if {[string match "*/disk/*" $line]} { continue }
					set location [lrange $line end end-0]; set percent [lindex $line 3]; set free [lindex $line 2]; set used [lindex $line 1]; set total [lindex $line 0]
					if {[string length $used]>1 && [string length $total]>1} { append out "\002\[\002$location\002\]\002: \002Used\002: $used \002Free\002: $free \002Total\002: $total " }
				}
			}
		}
		if {[info exists out]} { return $out } else { return "error" }
	}
	proc users {{default {?}}} { if {[file exists /proc/consoles]} { llength [split [readfile /proc/consoles] \n] } elseif {![catch { llength [split [exec w -h] \n] } count]} { return $count } else { return $default } }
	proc processes {{default {0}}} { llength [glob -directory /proc/ -tails -nocomplain 1* 2* 3* 4* 5* 6* 7* 8* 9*] }
	proc hostname {{default {?}}} { return [exec hostname] }
	proc os {{default {?}}} { return $::tcl_platform(os) }
	proc osver {{default {?}}} { return $::tcl_platform(osVersion) }
	proc machine {{default {?}}} { return $::tcl_platform(machine) }
	proc readfile {file {default {}}} { if {![catch { read -nonewline [set fid [open $file r]] } out]} { close $fid; return $out } else { return $default } }
	proc secstodays {seconds args} { return "[expr { [format %.0f $seconds] / 86400 }] days" }

	proc port_scan {nick uhost handle chan text} { if {[flood [string range $uhost [expr [string last @ $uhost]+1] e]]} {return 0}
		set h [lindex $text 0]; set flags [lrange $text 1 end]; set nmap [exec which nmap]; set f ""
		if {![catch {set data [exec $nmap \-sT ${h}]} error]} { foreach line [split $data "\n"] { regexp -all {(\d+)/tcp.*open} $line -> found; if {[info exists found]} { if {![string match "*$found*" $f]} { append f "$found " } } } }
		putserv "PRIVMSG $chan :[b]([b]nmap[b])[b]: $h: ([b]TCP[b]) $f"
	}

}


proc pub:glue {n u h c t} {
	if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	set tld [lrange [split $t "."] end end]
	set returned ""
	set dig [lindex [split [exec which dig]] 0]; set whois [lindex [split [exec which whois]] 0]; set host [lindex $t 0]; set flags "NS $tld"
	if {[catch {set lookup [read [set cid [open "|$dig $flags" r]]];close $cid} open_error] != 0} { return -code error "Error opening command pipe: $open_error" }
	foreach l [split $lookup "\r\n"] {
		if {[string match "*;*" $l]} { continue }
		if {[string match "*IN\tNS*" $l]} { append server "[lrange [string range $l 0 end-1] end end] " }
	}
	set rootserver [lindex $server [expr {int(rand()*[llength $server])}]]
	set flags "@$rootserver $t NS"
	if {[catch {set lookup [read [set cid [open "|$dig $flags" r]]];close $cid} open_error] != 0} {
		return -code error "Error opening command pipe: $open_error"
	} else {
		foreach line [split $lookup "\r\n"] {
			if {[string match ";*" $line]} { continue }
			if {[string match "*IN*A*" $line]} {
				append returned "[b]NS[b] [lrange $line 0 0] [b]IP[b] [lrange $line end end] "
			}
		}
	}
	if {[string length $returned] > 2} { putserv "PRIVMSG $c :[b]G[b]lue Results: $returned" } else { putserv "PRIVMSG $c :Glue Results: [b]failed[b]." }
}

proc v6ip {n u h c t} { if {[flood [string range $u [expr [string last @ $u]+1] e]]} {return 0}
	putserv "PRIVMSG $c : settings for $t (\002[vhost:expandipv6 $t]\002)"
	putserv "PRIVMSG $c :something 300 IN AAAA \002$t"
	set expanded "[string map {: ""} [string reverse [vhost:expandipv6 $t]]]"
	set rev "[join [split $expanded ""] "."]"
	putserv "PRIVMSG $c :\002[string range $rev 0 30]\002 IN PTR \002something.here.com."
}

proc vhost:expandipv6 {ip} {
	if {[string match *:* $ip] == 0} { return $ip }
	set newip ""
	set ip [string map {{::} {:ZZZZ:}} $ip]
	foreach x [split $ip {:}] {
		lappend newip [string range "0000$x" end-3 end]
	}
	set newip [join $newip {:}]
	set i 0
	while {[llength [split $newip {:}]] < 8} {
		incr i
		if {$i > 10} { return 0 }
		set newip [string map {{:ZZZZ:} {:0000:ZZZZ:}} $newip]
	}
	return [string map {{Z} {0}} $newip]
}
proc whoisinfo_setarray {} { global query; set query(netname) "(none)"; set query(country) "(none)"; set query(orgname) "(none)"; set query(orgid) "(none)"; set query(range) "(none)" }
proc whoisinfo_display { chan } { global query; puthelp "PRIVMSG $chan :Range: $query(range), Netname: $query(netname), Organisation: $query(orgname), Country: $query(country)" }
proc whoisinfo {nick uhost handle chan search} {
	global whoisinfo query
	whoisinfo_setarray
	if {[pub:whoisinfo $whoisinfo(arin) $search $chan]==1} {
		if {[string compare [string toupper $query(orgid)] "RIPE"]==0} { if {[pub:whoisinfo $whoisinfo(ripe) $search $chan]==1} { whoisinfo_display $chan }
		} elseif {[string compare [string toupper $query(orgid)] "APNIC"]==0} { if {[pub:whoisinfo $whoisinfo(apnic) $search $chan]==1} { whoisinfo_display $chan }
		} elseif {[string compare [string toupper $query(orgid)] "LACNIC"]==0} { if {[pub:whoisinfo $whoisinfo(lacnic) $search $chan]==1} { whoisinfo_display $chan }
		} elseif {[string compare [string toupper $query(orgid)] "AFRINIC"]==0} { if {[pub:whoisinfo $whoisinfo(afrinic) $search $chan]==1} { whoisinfo_display $chan }
		} else { whoisinfo_display $chan }
	} else {
		if { [info exist query(firstline)] } {
			puthelp "PRIVMSG $chan :Firstline: $query(firstline)"; puthelp "PRIVMSG $chan :Secondline: $query(secondline)"
		} else { puthelp "PRIVMSG $chan :Error?" }
	}
}

proc pub:whoisinfo {server search chan} {
	global whoisinfo query
	set desccount 0; set firstline 0
	set secondline 0; set reply 0
	if {[catch {set sock [socket -async $server $whoisinfo(port)]} sockerr]} { puthelp "PRIVMSG $chan :Error: $sockerr. Try again later."; close $sock; return 0 }
	puts $sock $search
	flush $sock
	while {[gets $sock whoisline]>=0} {
		if {[string index $whoisline 0]!="#" && [string index $whoisline 0]!="%" && $firstline==0} {
			if {[string trim $whoisline]!=""} { set query(firstline) [string trim $whoisline];set firstline 1 }
		}
		if {[string index $whoisline 0]!="#" && [string index $whoisline 0]!="%" && $secondline==0} {
			if {[string trim $whoisline]!="" && ![string match "$query(firstline)" $whoisline]} { set query(secondline) [string trim $whoisline];set secondline 1 }
		}
		if {[regexp -nocase {netname:(.*)} $whoisline all item]} { set query(netname) [string trim $item];set reply 1
		} elseif {[regexp -nocase {owner-c:(.*)} $whoisline all item]} { set query(netname) [string trim $item];set reply 1
		} elseif {[regexp -nocase {country:(.*)} $whoisline all item]} { set query(country) [string trim $item];set reply 1
		} elseif {[regexp -nocase {descr:(.*)} $whoisline all item] && $desccount==0} { set query(orgname) [string trim $item];	set desccount 1;set reply 1
		} elseif {[regexp -nocase {orgname:(.*)} $whoisline all item]} { set query(orgname) [string trim $item];set reply 1
		} elseif {[regexp -nocase {owner:(.*)} $whoisline all item]} { set query(orgname) [string trim $item];set reply 1
		} elseif {[regexp -nocase {orgid:(.*)} $whoisline all item]} { set query(orgid) [string trim $item];set reply 1
		} elseif {[regexp -nocase {inetnum:(.*)} $whoisline all item]} { set query(range) [string trim $item];set reply 1
		} elseif {[regexp -nocase {netrange:(.*)} $whoisline all item]} { set query(range) [string trim $item];set reply 1
		}
	}
	close $sock
	return $reply
}
proc split_line {max str c} {
	global bt
	set last [expr {[string length $str] -1}]; set start 0; set end [expr {$max -1}]; set lines []
	while {$start <= $last} {
		if {$last >= $end} { set end [string last { } $str $end] }
		lappend lines "[string trim [string range $str $start $end]]"
		set start $end; set end [expr {$start + $max}]
	}
	foreach line $lines { putserv "PRIVMSG $c :$line" }
}

putlog "boxinfo.tcl-v$bt(ver) black@blackmajic.org - loaded..."
set try [catch {unbind ctcp - VERSION *ctcp:VERSION} return]
if {$try} { putlog "CTCP Version already unbinded! (rehash)" }

