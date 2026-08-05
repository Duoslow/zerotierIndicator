import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "General"
        icon: "configure"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: "Peer Names"
        icon: "tag"
        source: "ConfigPeers.qml"
    }
}
