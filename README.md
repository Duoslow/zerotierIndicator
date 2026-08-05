# Zerotier KDE Widget

A KDE Plasma 6 widget that shows the Zerotier networks this machine joined and
the peers it is connected to.

## How it gets its data

The widget talks to the **local `zerotier-one` service** on
`http://localhost:9993`, not to Zerotier Central. Central's API needs an account
token that is not available on the free plan, while the local service is part of
the daemon you already run.

That trade is worth knowing about:

| | Zerotier Central API | Local service API (used here) |
|---|---|---|
| Cost | Paid plan | Free, no account involved |
| Scope | Every member of a network, from anywhere | What this machine sees |
| Member names | Yes, from Central | No -- node ids, plus your own labels |
| Member addresses | Yes, from the controller | Recovered from the neighbour table |

So the widget lists your joined networks and the peers currently reachable, not
the full membership roster of a network.

## Setup

The daemon's auth token is only readable by root. Give your user account a copy:

```bash
sudo install -m 600 -o $USER \
    /var/lib/zerotier-one/authtoken.secret ~/.zerotierOneAuthToken
```

The widget finds that file on its own -- there is nothing to paste into the
settings. If you keep the token somewhere else, paste it into the Auth token
field in the widget's settings instead.

## Features

- Connected peer count on the panel icon, as a theme-coloured symbolic icon
- Joined networks with their status and your assigned address
- Peers with their address on the virtual network, latency, and whether the
  link is direct or relayed
- Click any row to copy the address you would actually connect to
- Your own labels for peers, since the local service only knows node ids
- Filter down to specific networks, or hide peers that are not reachable
- Refresh interval from 2 seconds upwards, plus a Refresh action in the
  context menu

### How a peer's address is worked out

The address to connect to is the one on the virtual network -- `10.x.y.z`, not
the peer's public IP, which is only how the packets happen to travel today.

The local service does not know it: which address a network handed to which
member is the controller's business. The kernel does know, once a peer has been
talked to, and Zerotier derives a member's MAC deterministically from the
network id and the node id:

```
MAC[0] = (last byte of nwid & 0xfe) | 0x02
MAC[i] = node[i-1] XOR nwid[7-i]          for i = 1..5
```

So the widget computes the MAC each peer must have, then looks it up in the
neighbour table of the network's interface. A peer that has never exchanged IP
traffic has no entry yet and shows up without an address until something -- a
ping is enough -- puts it there.

## Installation

1. From the KDE Store: `Right click on the desktop, dock or panel -> Add
   Widgets -> Get New Widgets -> search for "Zerotier Indicator"`.
2. From the `zerotier.plasmoid` file in this repo's
   [releases](https://github.com/Hafikan/zerotierIndicator/releases/latest):
   `Right click on the desktop -> Add Widgets -> Install from local file`.
3. From a checkout:

```bash
./build.sh
kpackagetool6 -t Plasma/Applet --install zerotier.plasmoid   # or --upgrade
```

## Development

### Layout

| File | Role |
|---|---|
| `ui/main.qml` | The applet: panel icon, popup, refresh timers |
| `ui/zerotier.js` | Service API calls, online rules, MAC derivation |
| `ui/AuthToken.qml` | Finds the auth token |
| `ui/ShellCommand.qml` | Runs a command and returns its stdout |
| `ui/ConfigGeneral.qml` | Settings: interval, networks, token |
| `ui/ConfigPeers.qml` | Settings: peer labels |

### Two things that will bite you

**Qt 6 refuses to read local files over `XMLHttpRequest`** unless the process
was started with `QML_XHR_ALLOW_FILE_READ=1`, and it fails *silently* -- no
error, no `onerror`, the request simply never completes. That is why the auth
token is read through the executable data engine instead. The same trap applies
to anything else you might want to read off disk from QML.

**`console.log` output can be swallowed** depending on how the applet is
launched, which makes the above even harder to spot. Exercising a code path
under `qml6` and signalling results through `Qt.exit(code)` is a reliable way to
debug it:

```bash
QT_QPA_PLATFORM=offscreen qml6 test.qml; echo "exit=$?"
```

### Building

`./build.sh` packs `package/` into `zerotier.plasmoid`. To try a change without
touching the panel:

```bash
plasmawindowed org.github.hafikan.zerotierIndicator
```

Publishing an update: bump `Version` in `package/metadata.json`, run
`./build.sh`, and upload the new `zerotier.plasmoid` to the store listing. The
store compares that version string to decide who gets an update notification.

## Version history

- **v2.0** -- Ported to Plasma 6, rebuilt on the local service API, new flat UI
- **v1.1** -- Zerotier Central API, Plasma 5

## Credits

Originally written by [Duoslow](https://github.com/Duoslow/zerotierIndicator)
(Uğur Yavaş) for Plasma 5 and the Zerotier Central API. This fork carries the
Plasma 6 port and the move to the local service API, and is published under a
separate plugin id so both can be installed side by side.

## License

MIT -- see [LICENSE](LICENSE). The original copyright notice is retained.
