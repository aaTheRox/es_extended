# es_extended LEGACY / BROKEN / WONTFIX

### Things hapenning here now https://github.com/MYX-Org/es_extended/tree/develop (WIP)

es_extended is a roleplay framework for FiveM. The to-go framework for creating an economy based roleplay server on FiveM and most popular on the platform, too!

Featuring many extra resources to fit roleplaying servers, here's a taste of what's available:

- myx_ambulancejob: play as a medic to revive players who are bleeding out. Complete with garages and respawn & bleedout system
- myx_policejob: patrol the city and arrest players commiting crime, with armory, outfit room and garages
- myx_vehicleshop: roleplay working in an vehicle dealership where you sell cars to players

MYX was initially developed by Gizz back in 2017 for his friend as the were creating an FiveM server and there wasn't any economy roleplaying frameworks available. The original code was written within a week or two and later open sourced, it has ever since been improved and parts been rewritten to further improve on it.

## Links & Read more

- [MYX Forum](https://forum.myx-framework.org/)
- [MYX Documentation](https://wiki.myx-framework.org/)
- [MYX Development Discord](https://discord.me/myx)
- [FiveM Native Reference](https://runtime.fivem.net/doc/reference.html)

## Features

- Weight based inventory system
- Weapons support, including support for attachments and tints
- Supports different money accounts (defaulted with cash, bank and black money)
- Many official resources available in our GitHub
- Job system, with grades and clothes support
- Supports multiple languages, most strings are localized
- Easy to use API for developers to easily integrate MYX to their projects
- Register your own commands easily, with argument validation, chat suggestion and using FXServer ACL

## Requirements

- [mysql-async](https://github.com/brouznouf/fivem-mysql-async)
- [async](https://github.com/MYX-Org/async)


## Download & Installation


### Using Git

```
cd resources
git clone https://github.com/MYX-Org/es_extended [essential]/es_extended
git clone https://github.com/MYX-Org/myx_menu_default [myx]/[ui]/myx_menu_default
git clone https://github.com/MYX-Org/myx_menu_dialog [myx]/[ui]/myx_menu_dialog
git clone https://github.com/MYX-Org/myx_menu_list [myx]/[ui]/myx_menu_list
```

### Manually

- Download https://github.com/MYX-Org/es_extended/releases/latest
- Put it in the `resource/[essential]` directory
- Download https://github.com/MYX-Org/myx_menu_default/releases/latest
- Put it in the `resource/[myx]/[ui]` directory
- Download https://github.com/MYX-Org/myx_menu_dialog/releases/latest
- Put it in the `resource/[myx]/[ui]` directory
- Download https://github.com/MYX-Org/myx_menu_list/releases/latest
- Put it in the `resource/[myx]/[ui]` directory

### Installation

- Import `es_extended.sql` in your database
- Configure your `server.cfg` to look like this

```
add_principal group.admin group.user
add_ace resource.es_extended command.add_ace allow
add_ace resource.es_extended command.add_principal allow
add_ace resource.es_extended command.remove_principal allow
add_ace resource.es_extended command.stop allow

start mysql-async
start es_extended

start myx_menu_default
start myx_menu_list
start myx_menu_dialog
```

## Legal

### License

es_extended - MYX framework for FiveM

Copyright (C) 2015-2020 Jérémie N'gadi

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.
