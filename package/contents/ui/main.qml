import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "zerotier.js" as ZeroTier

PlasmoidItem {
    id: root

    readonly property string configuredToken: Plasmoid.configuration.authToken
    readonly property string selectedNetworks: Plasmoid.configuration.selectednetwork
    readonly property bool onlyConnected: Plasmoid.configuration.showOnlyConnected
    readonly property int refreshSeconds: Plasmoid.configuration.refreshSeconds
    readonly property string peerNames: Plasmoid.configuration.peerNames

    // Resolved from the token file at startup; empty means we cannot talk to
    // the local service at all.
    readonly property string authToken: tokenReader.token
    readonly property string authTokenSource: tokenReader.source
    readonly property bool authTokenResolved: tokenReader.resolved

    property int networkCount: 0
    property int peerCount: 0
    property int connectedPeerCount: 0
    property string lastError: ""
    property bool loading: false

    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 10
    preferredRepresentation: compactRepresentation

    toolTipMainText: "Zerotier"
    toolTipSubText: {
        if (lastError !== "") {
            return lastError;
        }
        if (!authTokenResolved) {
            return "Looking for the zerotier-one auth token...";
        }
        return connectedPeerCount + " of " + peerCount + " peers connected on "
             + networkCount + (networkCount === 1 ? " network" : " networks");
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Refresh Now"
            icon.name: "view-refresh"
            onTriggered: zerotierModel.reload()
        }
    ]

    AuthToken {
        id: tokenReader
        configuredToken: root.configuredToken
        // Both the token arriving and it turning out to be unreadable are
        // reasons to rebuild the list.
        onTokenChanged: zerotierModel.reload()
        onResolvedChanged: if (resolved) zerotierModel.reload()
    }

    function resolveToken() {
        tokenReader.resolve();
    }

    // Tells us which managed address belongs to which peer; see zerotier.js.
    ShellCommand {
        id: neighbourQuery
        command: "ip -4 neigh show"
    }

    ListModel {
        id: zerotierModel

        // Bumped on every reload. Replies carrying an older generation belong
        // to a run whose model was already cleared, so appending them would
        // duplicate the list -- they are dropped instead.
        property int generation: 0

        function reload() {
            generation++;
            const gen = generation;

            if (root.authToken.length === 0) {
                clear();
                root.loading = false;
                root.networkCount = 0;
                root.peerCount = 0;
                root.connectedPeerCount = 0;
                root.lastError = root.authTokenResolved ? "Cannot read the zerotier-one auth token" : "";
                return;
            }

            root.loading = true;

            // Both lists are fetched at once and the model is rebuilt only when
            // both are in, so networks always sort above peers no matter which
            // reply lands first.
            let networks = null;
            let peers = null;
            let neighbours = null;

            function rebuildWhenReady() {
                if (networks === null || peers === null || neighbours === null || gen !== generation) {
                    return;
                }
                rebuild(networks, peers, neighbours);
                root.loading = false;
            }

            function fail(error) {
                if (gen !== generation) {
                    return;
                }
                root.lastError = error.message;
                root.loading = false;
                if (!error.fatal) {
                    retryTimer.restart();
                }
            }

            ZeroTier.request(root.authToken, "/network", function (result) {
                if (gen !== generation) {
                    return;
                }
                networks = result;
                rebuildWhenReady();
            }, fail);

            ZeroTier.request(root.authToken, "/peer", function (result) {
                if (gen !== generation) {
                    return;
                }
                peers = result;
                rebuildWhenReady();
            }, fail);

            // A missing neighbour table only costs us the managed addresses,
            // so it must never block the rest of the list.
            neighbourQuery.callback = function (stdout) {
                if (gen !== generation) {
                    return;
                }
                neighbours = ZeroTier.parseNeighbours(stdout);
                rebuildWhenReady();
            };
            neighbourQuery.run();
        }

        function rebuild(networks, peers, neighbours) {
            clear();
            root.lastError = "";

            const wanted = ZeroTier.parseNetworkList(root.selectedNetworks);
            const shown = networks.filter(function (network) {
                // An empty selection means "every network this machine joined".
                return wanted.length === 0 || wanted.indexOf(network.id) >= 0;
            });
            root.networkCount = shown.length;

            shown.sort(function (a, b) {
                return ZeroTier.networkName(a).localeCompare(ZeroTier.networkName(b));
            });

            for (const network of shown) {
                append({
                    section: "Networks",
                    itemId: network.id,
                    primary: ZeroTier.networkName(network),
                    secondary: ZeroTier.networkAddress(network) !== ""
                               ? ZeroTier.networkAddress(network)
                               : ZeroTier.networkStatusText(network),
                    trailing: network.portDeviceName ? network.portDeviceName : "",
                    ok: ZeroTier.networkIsUp(network),
                    copyText: ZeroTier.networkAddress(network).split("/")[0],
                    tooltip: network.id + "  ·  " + ZeroTier.networkStatusText(network)
                });
            }

            // Only LEAF peers are other machines; the rest are Zerotier's own
            // root servers and would just be noise.
            const devices = peers.filter(ZeroTier.isDevicePeer);
            root.peerCount = devices.length;

            let connected = 0;
            const names = ZeroTier.parsePeerNames(root.peerNames);
            const rows = [];

            for (const peer of devices) {
                const isConnected = ZeroTier.peerIsConnected(peer);
                if (isConnected) {
                    connected++;
                }
                if (root.onlyConnected && !isConnected) {
                    continue;
                }

                const direct = ZeroTier.peerIsDirect(peer);
                // The address on the virtual network is what you actually
                // connect to, so it leads the line and is what gets copied.
                const managed = ZeroTier.findPeerAddress(peer.address, shown, neighbours);
                const link = ZeroTier.peerLatencyText(peer)
                           + (isConnected ? (direct ? "  ·  direct" : "  ·  relayed") : "");

                rows.push({
                    section: "Peers",
                    itemId: peer.address,
                    primary: ZeroTier.peerLabel(peer, names),
                    secondary: managed !== "" ? managed + "  ·  " + link : link,
                    trailing: peer.version ? peer.version : "",
                    ok: isConnected,
                    copyText: managed !== "" ? managed : peer.address,
                    tooltip: managed !== ""
                             ? "Click to copy " + managed + "  ·  node " + peer.address
                             : "No address seen yet  ·  node " + peer.address
                });
            }
            root.connectedPeerCount = connected;

            // Connected first, then by label.
            rows.sort(function (a, b) {
                if (a.ok !== b.ok) {
                    return a.ok ? -1 : 1;
                }
                return a.primary.localeCompare(b.primary);
            });

            for (const row of rows) {
                append(row);
            }
        }
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.authToken.length > 0
        onTriggered: zerotierModel.reload()
    }

    Timer {
        id: retryTimer
        interval: 30000
        repeat: false
        onTriggered: zerotierModel.reload()
    }

    onSelectedNetworksChanged: zerotierModel.reload()
    onOnlyConnectedChanged: zerotierModel.reload()
    onPeerNamesChanged: zerotierModel.reload()

    compactRepresentation: MouseArea {
        id: compactRoot

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        Layout.minimumWidth: vertical ? 0 : compactRow.implicitWidth
        Layout.minimumHeight: vertical ? compactRow.implicitHeight : 0
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight

        hoverEnabled: true
        activeFocusOnTab: true
        onClicked: root.expanded = !root.expanded

        GridLayout {
            id: compactRow
            anchors.centerIn: parent
            rowSpacing: 0
            columnSpacing: Kirigami.Units.smallSpacing
            flow: compactRoot.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight

            Kirigami.Icon {
                source: Qt.resolvedUrl("../images/zerotier-symbolic.svg")
                isMask: true
                color: root.lastError !== "" ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                // Dimmed when nothing is connected, so a glance is enough.
                opacity: root.connectedPeerCount > 0 ? 1.0 : 0.55

                readonly property int side: Math.max(Kirigami.Units.iconSizes.small,
                                                     Math.min(compactRoot.height, compactRoot.width,
                                                              Kirigami.Units.iconSizes.medium))
                Layout.preferredWidth: side
                Layout.preferredHeight: side
            }

            PlasmaComponents3.Label {
                text: root.connectedPeerCount
                visible: root.authToken.length > 0
                opacity: root.connectedPeerCount > 0 ? 1.0 : 0.55
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: fullRep

        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24

        // Which row just got copied, so we can flash a hint on it.
        property string copiedId: ""

        Timer {
            id: copyFeedback
            interval: 1200
            onTriggered: fullRep.copiedId = ""
        }

        // QML has no clipboard API, so copying goes through a hidden editor.
        TextEdit {
            id: clipboardHelper
            visible: false

            function copyText(text) {
                clipboardHelper.text = text;
                clipboardHelper.selectAll();
                clipboardHelper.copy();
                clipboardHelper.deselect();
            }
        }

        header: PlasmaExtras.PlasmoidHeading {
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 4
                    elide: Text.ElideRight
                    text: root.authToken.length > 0
                          ? root.connectedPeerCount + " peers connected"
                          : "Zerotier"
                }

                PlasmaComponents3.BusyIndicator {
                    visible: root.loading
                    running: visible
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Refresh"
                    enabled: !root.loading
                    onClicked: zerotierModel.reload()

                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "configure"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Configure"
                    onClicked: Plasmoid.internalAction("configure").trigger()

                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        contentItem: Item {

            PlasmaComponents3.ScrollView {
                anchors.fill: parent
                visible: zerotierModel.count > 0
                contentWidth: availableWidth

                ListView {
                    id: entryList
                    model: zerotierModel
                    currentIndex: -1
                    reuseItems: true
                    clip: true

                    section.property: "section"
                    section.criteria: ViewSection.FullString
                    section.delegate: PlasmaExtras.ListSectionHeader {
                        width: entryList.width
                        text: section
                    }

                    delegate: PlasmaComponents3.ItemDelegate {
                        id: entryDelegate

                        width: entryList.width
                        hoverEnabled: true
                        enabled: model.copyText !== ""

                        onClicked: {
                            clipboardHelper.copyText(model.copyText);
                            fullRep.copiedId = model.itemId;
                            copyFeedback.restart();
                        }

                        QQC2.ToolTip.text: model.tooltip
                        QQC2.ToolTip.visible: hovered && model.tooltip !== ""
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Rectangle {
                                implicitWidth: Kirigami.Units.smallSpacing * 1.5
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: model.ok ? Kirigami.Theme.positiveTextColor
                                                : Kirigami.Theme.disabledTextColor
                                opacity: model.ok ? 1.0 : 0.6
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: model.primary
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }

                                PlasmaExtras.DescriptiveLabel {
                                    Layout.fillWidth: true
                                    text: model.secondary
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    font: Kirigami.Theme.smallFont
                                }
                            }

                            PlasmaComponents3.Label {
                                text: "Copied"
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.positiveTextColor
                                opacity: fullRep.copiedId === model.itemId ? 1.0 : 0.0
                                Behavior on opacity {
                                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                                }
                            }

                            Kirigami.Icon {
                                source: "edit-copy-symbolic"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                opacity: entryDelegate.hovered && fullRep.copiedId !== model.itemId ? 0.7 : 0.0
                                Behavior on opacity {
                                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                                }
                            }
                        }
                    }
                }
            }

            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: zerotierModel.count === 0

                iconName: root.lastError !== "" ? "dialog-warning" : "network-disconnect"

                text: {
                    if (root.lastError !== "") {
                        return root.lastError;
                    }
                    if (root.loading || !root.authTokenResolved) {
                        return "Loading...";
                    }
                    return "No networks joined";
                }

                explanation: {
                    if (root.authToken.length === 0 && root.authTokenResolved) {
                        return "Give your user account a copy of the token:\n"
                             + "sudo install -m 600 -o $USER \\\n"
                             + "  /var/lib/zerotier-one/authtoken.secret ~/.zerotierOneAuthToken";
                    }
                    if (root.lastError === "" && !root.loading) {
                        return "Join a network with: zerotier-cli join <network id>";
                    }
                    return "";
                }

                helpfulAction: Kirigami.Action {
                    visible: root.lastError !== ""
                    icon.name: "view-refresh"
                    text: "Try again"
                    onTriggered: root.resolveToken()
                }
            }
        }
    }
}
