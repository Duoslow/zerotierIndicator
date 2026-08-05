.pragma library

// Helpers for the local zerotier-one service API (http://localhost:9993).
//
// This is deliberately not the Zerotier Central API: Central requires an
// account API token that is not available on the free plan. The local daemon
// exposes what this machine itself knows -- the networks it joined and the
// peers it is talking to -- with no account or plan involved.

var API = "http://localhost:9993";

// The auth token itself is read by AuthToken.qml: Qt 6 blocks local file reads
// over XMLHttpRequest, so that has to go through the executable data engine.

/**
 * GET an endpoint of the local service API.
 *
 * onError receives {message, status, fatal}. "fatal" marks errors that keep
 * failing until the user changes something, so callers know not to retry.
 */
function request(authToken, endpoint, onSuccess, onError) {
    if (!authToken) {
        onError({ message: "No zerotier-one auth token", status: 0, fatal: true });
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.open("GET", API + endpoint, true);
    xhr.setRequestHeader("X-ZT1-Auth", authToken);

    xhr.onload = function () {
        if (xhr.status === 200) {
            try {
                onSuccess(JSON.parse(xhr.responseText));
            } catch (e) {
                onError({ message: "Malformed reply from zerotier-one", status: xhr.status });
            }
        } else if (xhr.status === 401 || xhr.status === 403) {
            onError({ message: "zerotier-one rejected the auth token", status: xhr.status, fatal: true });
        } else {
            onError({ message: "zerotier-one error: HTTP " + xhr.status, status: xhr.status });
        }
    };

    xhr.onerror = function () {
        onError({ message: "zerotier-one is not running", status: 0 });
    };

    xhr.send();
}

// --- networks ---------------------------------------------------------------

function networkAddress(network) {
    var addresses = network.assignedAddresses;
    return (addresses && addresses.length > 0) ? addresses[0] : "";
}

function networkName(network) {
    return (network.name && network.name.length > 0) ? network.name : network.id;
}

/** Anything other than OK means the interface is not usable right now. */
function networkIsUp(network) {
    return network.status === "OK";
}

function networkStatusText(network) {
    switch (network.status) {
    case "OK":
        return "Connected";
    case "REQUESTING_CONFIGURATION":
        return "Requesting configuration";
    case "ACCESS_DENIED":
        return "Access denied - not authorized on this network";
    case "NOT_FOUND":
        return "Network not found";
    case "PORT_ERROR":
        return "Port error";
    case "CLIENT_TOO_OLD":
        return "Client too old";
    default:
        return network.status;
    }
}

// --- peers ------------------------------------------------------------------

/**
 * PLANET and MOON peers are Zerotier's own root servers, not the user's
 * devices; only LEAF peers are other machines on the networks.
 */
function isDevicePeer(peer) {
    return peer.role === "LEAF";
}

function activePath(peer) {
    var paths = peer.paths || [];
    var fallback = null;
    for (var i = 0; i < paths.length; i++) {
        var path = paths[i];
        if (!path.active || path.expired) {
            continue;
        }
        if (path.preferred) {
            return path;
        }
        if (!fallback) {
            fallback = path;
        }
    }
    return fallback;
}

/** A peer is reachable when at least one of its paths is still alive. */
function peerIsConnected(peer) {
    return activePath(peer) !== null;
}

/** Relayed traffic goes through Zerotier's infrastructure instead of directly. */
function peerIsDirect(peer) {
    return peerIsConnected(peer) && !peer.tunneled;
}

function peerLatencyText(peer) {
    if (!peerIsConnected(peer)) {
        return "unreachable";
    }
    if (typeof peer.latency !== "number" || peer.latency < 0) {
        return "latency unknown";
    }
    return peer.latency + " ms";
}

/** The remote endpoint currently in use, without the port. */
function peerEndpoint(peer) {
    var path = activePath(peer);
    if (!path || !path.address) {
        return "";
    }
    var separator = path.address.lastIndexOf("/");
    return separator > 0 ? path.address.substring(0, separator) : path.address;
}

// --- virtual addresses ------------------------------------------------------
//
// The local service knows a peer's node id and how packets reach it, but not
// which address the network assigned to it -- that lives on the controller.
// The kernel does know, though: once a peer has been talked to, its managed
// address sits in the neighbour table of the zerotier interface. Zerotier
// derives a member's MAC deterministically from the network id and the node
// id, which is enough to tell whose entry is whose.

function byteAt(hex, index) {
    return parseInt(hex.substr(index * 2, 2), 16);
}

function macForNode(nodeId, networkId) {
    var nwid = String(networkId).toLowerCase();
    var node = String(nodeId).toLowerCase();
    if (nwid.length !== 16 || node.length !== 10) {
        return "";
    }

    // First octet comes from the network id, forced to a locally administered
    // unicast address; 0x52 is remapped because it collides with a common
    // hypervisor prefix.
    var first = (byteAt(nwid, 7) & 0xfe) | 0x02;
    if (first === 0x52) {
        first = 0x32;
    }

    var octets = [first];
    for (var i = 0; i < 5; i++) {
        octets.push(byteAt(node, i) ^ byteAt(nwid, 6 - i));
    }

    return octets.map(function (octet) {
        return (octet < 16 ? "0" : "") + octet.toString(16);
    }).join(":");
}

/** Parses "ip -4 neigh show" output into {ip, dev, mac} entries. */
function parseNeighbours(stdout) {
    var entries = [];
    var lines = String(stdout).split("\n");

    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].trim().split(/\s+/);
        if (parts.length < 4) {
            continue;
        }

        var dev = "";
        var mac = "";
        for (var j = 1; j < parts.length - 1; j++) {
            if (parts[j] === "dev") {
                dev = parts[j + 1];
            } else if (parts[j] === "lladdr") {
                mac = parts[j + 1].toLowerCase();
            }
        }

        var state = parts[parts.length - 1];
        // Entries without a MAC never resolved, so they say nothing about who
        // is on the other end.
        if (dev === "" || mac === "" || state === "FAILED" || state === "INCOMPLETE") {
            continue;
        }

        entries.push({ ip: parts[0], dev: dev, mac: mac });
    }

    return entries;
}

/** The managed address of a peer on one of the joined networks, if known. */
function findPeerAddress(nodeId, networks, neighbours) {
    for (var i = 0; i < networks.length; i++) {
        var network = networks[i];
        var mac = macForNode(nodeId, network.id);
        if (mac === "" || !network.portDeviceName) {
            continue;
        }
        for (var j = 0; j < neighbours.length; j++) {
            if (neighbours[j].dev === network.portDeviceName && neighbours[j].mac === mac) {
                return neighbours[j].ip;
            }
        }
    }
    return "";
}

// --- configuration ----------------------------------------------------------

/** Node id -> user supplied label, stored in the config as a JSON object. */
function parsePeerNames(stored) {
    if (!stored || stored.length === 0) {
        return {};
    }
    try {
        var names = JSON.parse(stored);
        return (names && typeof names === "object") ? names : {};
    } catch (e) {
        return {};
    }
}

function peerLabel(peer, names) {
    var label = names[peer.address];
    return (label && label.length > 0) ? label : peer.address;
}

/** The selected network ids, stored in the config as a comma separated string. */
function parseNetworkList(stored) {
    return String(stored).split(",").filter(function (id) {
        return id.length > 0;
    });
}
