import QtQuick 2.0
import QtQuick.Window 2.2
import QtQuick.Controls 1.0
import QtQuick.Layouts 1.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: generalSettings
    property alias cfg_updateInterval: updateTime.value
    property alias cfg_zerotierToken: ztoken.text
    property alias cfg_zerotiernid: znid.text
    property string cfg_zerotierToken: ""
    property string cfg_zerotiernid: ""

    ColumnLayout {
        anchors.right: parent.right
        anchors.left: parent.left

        RowLayout {
            Label {
                text: "Zerotier Access Token"
            }
            TextField {
                id: ztoken
                placeholderText: "Enter Token Here"
                Layout.preferredWidth: 250
            }
            Text {
                text: '<html><a href="https://my.zerotier.com/account">get here</a></html>'
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
        RowLayout {
		    Label {
			    text: "Zerotier Network ID"
		    }
		    TextField {
			    id: znid
                placeholderText: "Enter Network ID Here"
                Layout.preferredWidth: 250
			    
		    }
	    }
        RowLayout {
		    Label {
			    text: "Update every"
		    }
		    SpinBox {
			    id: updateTime
			    minimumValue: 1
			    stepSize: 1
			    maximumValue: 60
			    suffix: "min"
                Layout.preferredWidth: 100
		    }
	    }

        

    }
    
    
}
