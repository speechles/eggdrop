proc oilme {args} {
        set agent "mozilla"
        set query "http://www.bloomberg.com/energy/"
        set http [::http::config -useragent $agent]
        set http [::http::geturl $query]
        set html [::http::data $http]
        regsub -all "\n" $html "" html
        if {[regexp -- {<td class='name'>TOCOM Crude Oil</td>.*?<td>(.*?)</td>.*?<td>(.*?)</td>} $html - 1 2]} {
        putserv "PRIVMSG speechl3s :$1 $2"
}
}