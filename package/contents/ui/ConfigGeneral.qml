import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "zerotier.js" as ZeroTier

KCM.SimpleKCM {
    id: page

    property alias cfg_refreshSeconds: refreshInterval.value
    property alias cfg_showOnlyConnected: onlyConnected.checked
    property alias cfg_authToken: tokenField.text
    // Not an alias: the checkboxes below edit it, and it is saved with the
    // rest of the page when the user hits Apply.
    property string cfg_selectednetwork: ""

    readonly property string authToken: tokenReader.token
    readonly property string authTokenSource: tokenReader.source
    readonly property bool authTokenResolved: tokenReader.resolved
    property string networkError: ""
    property bool networksLoading: false

    AuthToken {
        id: tokenReader
        configuredToken: tokenField.text
        onResolvedChanged: if (resolved) page.loadNetworks()
        onTokenChanged: page.loadNetworks()
    }

    function resolveToken() {
        tokenReader.resolve();
    }

    function loadNetworks() {
        if (authToken.length === 0) {
            networkModel.clear();
            return;
        }
        networksLoading = true;
        networkError = "";
        ZeroTier.request(authToken, "/network", function (networks) {
            // Rebuilt from scratch so a second refresh cannot duplicate rows.
            networkModel.clear();
            for (const network of networks) {
                networkModel.append({
                    networkId: network.id,
                    networkName: ZeroTier.networkName(network),
                    address: ZeroTier.networkAddress(network),
                    statusText: ZeroTier.networkStatusText(network)
                });
            }
            networksLoading = false;
        }, function (error) {
            networkModel.clear();
            networkError = error.message;
            networksLoading = false;
        });
    }

    function isSelected(networkId) {
        return ZeroTier.parseNetworkList(cfg_selectednetwork).indexOf(networkId) >= 0;
    }

    function setSelected(networkId, selected) {
        const list = ZeroTier.parseNetworkList(cfg_selectednetwork).filter(function (id) {
            return id !== networkId;
        });
        if (selected) {
            list.push(networkId);
        }
        cfg_selectednetwork = list.join(",");
    }

    ListModel {
        id: networkModel
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.authTokenResolved && page.authToken.length === 0
            type: Kirigami.MessageType.Warning
            text: "Cannot read the zerotier-one auth token. Give your user account a copy:\n"
                + "sudo install -m 600 -o $USER /var/lib/zerotier-one/authtoken.secret ~/.zerotierOneAuthToken"
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.authToken.length > 0
            type: Kirigami.MessageType.Positive
            text: "Reading the local zerotier-one service, token from " + page.authTokenSource + "."
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.SpinBox {
                id: refreshInterval
                Kirigami.FormData.label: "Refresh every:"
                from: 2
                to: 3600
                stepSize: 5
                textFromValue: function (value) { return value + " s"; }
                valueFromText: function (text) { return parseInt(text, 10); }
            }

            QQC2.CheckBox {
                id: onlyConnected
                Kirigami.FormData.label: "Peers:"
                text: "Show connected peers only"
            }

            RowLayout {
                Kirigami.FormData.label: "Auth token:"
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    id: tokenField
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                    placeholderText: "Detected automatically"
                    echoMode: TextInput.Password
                }

                QQC2.Button {
                    text: "Reload"
                    icon.name: "view-refresh"
                    onClicked: page.resolveToken()
                }
            }

            QQC2.Label {
                text: "Only needed when the token file cannot be read."
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            Item {
                Kirigami.FormData.isSection: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 4
                text: "Networks"
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: page.cfg_selectednetwork.length === 0 ? "showing all joined networks" : ""
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                elide: Text.ElideRight
            }

            QQC2.BusyIndicator {
                visible: page.networksLoading
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }

            QQC2.Button {
                text: "Show all"
                flat: true
                enabled: page.cfg_selectednetwork.length > 0
                onClicked: page.cfg_selectednetwork = ""
            }
        }

        QQC2.Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 12

            ListView {
                id: networkList
                anchors.fill: parent
                model: networkModel
                clip: true
                currentIndex: -1

                delegate: QQC2.CheckDelegate {
                    width: networkList.width
                    // With nothing selected every network is shown, so every
                    // box reads as ticked until the user narrows it down.
                    checked: page.cfg_selectednetwork.length === 0 || page.isSelected(model.networkId)

                    onToggled: {
                        if (page.cfg_selectednetwork.length === 0) {
                            // First tick turns "all" into an explicit list of
                            // everything except the row just unticked.
                            const all = [];
                            for (let i = 0; i < networkModel.count; i++) {
                                const id = networkModel.get(i).networkId;
                                if (id !== model.networkId) {
                                    all.push(id);
                                }
                            }
                            page.cfg_selectednetwork = all.join(",");
                        } else {
                            page.setSelected(model.networkId, checked);
                        }
                        // Clicking breaks the declarative binding above; put it
                        // back so the buttons keep updating this row.
                        checked = Qt.binding(function () {
                            return page.cfg_selectednetwork.length === 0 || page.isSelected(model.networkId);
                        });
                    }

                    contentItem: ColumnLayout {
                        spacing: 0

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: model.networkName
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: model.networkId + "  ·  "
                                  + (model.address !== "" ? model.address : model.statusText)
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: networkModel.count === 0 && !page.networksLoading

                    icon.name: page.networkError !== "" ? "dialog-warning" : "network-server"
                    text: {
                        if (page.networkError !== "") {
                            return page.networkError;
                        }
                        if (page.authToken.length === 0) {
                            return "No auth token";
                        }
                        return "No networks joined";
                    }
                    explanation: page.authToken.length > 0 && page.networkError === ""
                                 ? "zerotier-cli join <network id>" : ""
                }
            }
        }
    }
}
