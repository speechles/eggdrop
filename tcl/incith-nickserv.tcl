#---------------------------------------------------------------------#
# incith:nickserv                                        $Rev:: 130 $ #
# $Id:: incith-nickserv.tcl 130 2009-11-08 00:09:18Z incith         $ #
#                                                                     #
# watches for notices from NickServ and authenticates when necessary. #
# tested on Eggdrop 1.6.19 & Windrop v1.6.17                          #
#                                                                     #
# Usage:                                                              #
#   Just set the below variables appropriately.                       #
#                                                                     #
# ChangeLog (m/d/y):                                                  #
#   1/19/09: script released to svn.                                  #
#                                                                     #
# TODO:                                                               #
#   - Suggestions/Thanks/Bugs/Ideas, e-mail at bottom of header.      #
#                                                                     #
# LICENSE (GPLv3):                                                    #
#   This program is free software: you can redistribute it and/or     #
#   modify it under the terms of the GNU General Public License as    #
#   published by the Free Software Foundation, either version 3 of    #
#   the License, or (at your option) any later version.               #
#                                                                     #
#   This program is distributed in the hope that it will be useful,   #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of    #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.              #
#                                                                     #
#   See the GNU General Public License for more details.              #
#   (http://www.gnu.org/licenses/gpl-3.0.txt)                         #
#                                                                     #
# Copyright (C) 2009, Jordan                                          #
# http://incith.com ~ incith@gmail.com ~ irc.freenode.net/#incith     #
#---------------------------------------------------------------------#
#
# 0 (zero) will disable an optional variable, 1 or above enables.
# {} will disable identify or modess.
#
namespace eval incith::nickserv {
  # the string you want to send to nickserv for identifying.
  variable identify {IDENTIFY password-goes-here}

  # the name of nickserv, proper case.  incoming notices are checked against this.
  variable nickserv {NickServ}

  # the user@host of nickserv (/whois nickserv), also proper case.  also checked.
  variable uhost {services@irc.network}

  # if your server has a /NS or /NICKSERV command for authenticating, enable this.
  # 0: disabled (will use private messages instead)
  # 1: /NS
  # 2: /NICKSERV
  variable use_ns 0

  # any modes you want to set on yourself after authentication.
  variable modes { }

  # these are set to freenodes by default, adjust to the notices your nickserv sends.
  # separate with |, * will match anything.
  variable auth_strings {This nickname is registered and protected*}
}

# script begings
namespace eval incith::nickserv {
  variable version "incith:nickserv-SVN"
}

# bind the binds
namespace eval incith::nickserv {
  foreach auth_string [split $incith::nickserv::auth_strings |] {
    bind notc - [string trim $auth_string] incith::nickserv::message_handler
  }
}


namespace eval incith::nickserv {
  # [message_handler] : handles the notices received from NickServ
  #
  proc message_handler {nick uhost hand text {dest ""}} {
    # only accept messages from NickServ
    if {![string match "${incith::nickserv::nickserv}" $nick] || ![string match "${incith::nickserv::uhost}" $uhost]} {
      return
    }
    global botnick

    # bunch of ifs in case you want to disable things.
    if {[info exists incith::nickserv::identify]} {
      if {[string trim $incith::nickserv::identify] != ""} {
        if {$incith::nickserv::use_ns == 1} {
          putquick "NS :${incith::nickserv::identify}"
        } elseif {$incith::nickserv::use_ns == 2} {
          putquick "NICKSERV :${incith::nickserv::identify}"
        } else {
          if {[info exists incith::nickserv::nickserv]} {
            if {[string trim $incith::nickserv::nickserv] != ""} {
              putquick "PRIVMSG ${incith::nickserv::nickserv} :${incith::nickserv::identify}"
            }
          }
        }
      }
    }
    # set modes
    if {[info exists incith::nickserv::modes]} {
      if {[string trim $incith::nickserv::modes] != ""} {
        putquick "MODE ${botnick} ${incith::nickserv::modes}"
      }
    }
  }
}

# the script has loaded.
putlog "${incith::nickserv::version} loaded."

# EOF
