import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "zerotier.js" as ZeroTier

// The local service only knows a peer's 10 digit node id -- member names live
// in Zerotier Central, which needs a paid API token. This page lets the user
// attach their own labels instead.
KCM.SimpleKCM {
    id: page

    // Not an alias: edited row by row below, saved with the page on Apply.
    property string cfg_peerNames: "{}"

    readonly property string authToken: tokenReader.token
    property string peerError: ""
    property bool peersLoading: false

    AuthToken {
        id: tokenReader
        configuredToken: Plasmoid.configuration.authToken
        onResolvedChanged: {
            if (!resolved) {
                return;
            }
            if (token.length > 0) {
                page.loadPeers();
            } else {
                page.peerError = "Cannot read the zerotier-one auth token";
            }
        }
    }

    function labelFor(nodeId) {
        const names = ZeroTier.parsePeerNames(cfg_peerNames);
        return names[nodeId] !== undefined ? names[nodeId] : "";
    }

    function setLabel(nodeId, label) {
        const names = ZeroTier.parsePeerNames(cfg_peerNames);
        if (label.length > 0) {
            names[nodeId] = label;
        } else {
            delete names[nodeId];
        }
        cfg_peerNames = JSON.stringify(names);
    }

    function loadPeers() {
        peersLoading = true;
        peerError = "";
        ZeroTier.request(authToken, "/peer", function (peers) {
            // Rebuilt from scratch so a second refresh cannot duplicate rows.
            peerModel.clear();
            const devices = peers.filter(ZeroTier.isDevicePeer);
            devices.sort(function (a, b) {
                return a.address.localeCompare(b.address);
            });
            for (const peer of devices) {
                peerModel.append({
                    nodeId: peer.address,
                    connected: ZeroTier.peerIsConnected(peer),
                    details: ZeroTier.peerLatencyText(peer)
                             + (peer.version ? "  ·  v" + peer.version : "")
                });
            }
            peersLoading = false;
        }, function (error) {
            peerModel.clear();
            peerError = error.message;
            peersLoading = false;
        });
    }

    ListModel {
        id: peerModel
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.fillWidth: true
                text: "Give the peers on your networks a readable name."
                wrapMode: Text.Wrap
            }

            QQC2.BusyIndicator {
                visible: page.peersLoading
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }

            QQC2.Button {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                text: "Refresh"
                flat: true
                enabled: page.authToken.length > 0 && !page.peersLoading
                onClicked: page.loadPeers()

                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        QQC2.Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 18

            ListView {
                id: peerList
                anchors.fill: parent
                model: peerModel
                clip: true
                spacing: Kirigami.Units.smallSpacing

                delegate: RowLayout {
                    width: peerList.width
                    spacing: Kirigami.Units.largeSpacing

                    Rectangle {
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        implicitWidth: Kirigami.Units.smallSpacing * 1.5
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: model.connected ? Kirigami.Theme.positiveTextColor
                                               : Kirigami.Theme.disabledTextColor
                    }

                    ColumnLayout {
                        spacing: 0

                        QQC2.Label {
                            text: model.nodeId
                            font.family: "monospace"
                            textFormat: Text.PlainText
                        }

                        QQC2.Label {
                            text: model.details
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            textFormat: Text.PlainText
                        }
                    }

                    QQC2.TextField {
                        Layout.fillWidth: true
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        placeholderText: "Name for this peer"
                        text: page.labelFor(model.nodeId)
                        onEditingFinished: page.setLabel(model.nodeId, text)
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: peerModel.count === 0 && !page.peersLoading

                    icon.name: page.peerError !== "" ? "dialog-warning" : "network-connect"
                    text: page.peerError !== "" ? page.peerError : "No peers seen yet"
                    explanation: page.peerError === ""
                                 ? "Peers appear once another device on your networks comes online."
                                 : ""
                }
            }
        }
    }
}
