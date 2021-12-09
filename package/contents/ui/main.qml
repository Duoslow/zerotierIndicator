import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQuick.Window 2.1
import QtGraphicalEffects 1.0
import QtQuick.Controls 2.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: root
    Plasmoid.switchWidth: units.gridUnit * 10
    Plasmoid.switchHeight: units.gridUnit * 5
    property int updateInterval: plasmoid.configuration.updateInterval
    property string zerotierToken: plasmoid.configuration.zerotierToken
    property string zerotiernid: plasmoid.configuration.zerotiernid
    property string nembers: ""
    property string isonline: ""

    function requestUrl(method, url, options, callback) {
        let xhr = new XMLHttpRequest();
		xhr.open(method, url, true);
		xhr.onload = function (e) {
            console.log(xhr.status);
            // console.log(xhr.responseText);
		    if (xhr.status == 200) {
				let body = JSON.parse(xhr.responseText);
				callback(body);
			}
			else {
				console.log("Failed to execure the request: status code is not 200");
			}
		}
		xhr.onerror = function(e) {
			console.log("Error executing the request: network error"); 
            retryConnection.restart();
		}
		if (options.responseType) xhr.responseType = options.responseType;
		if (options.headers) {
		    let headers = Object.keys(options.headers);
		    for (let i = 0; i < headers.length; i++) {
                xhr.setRequestHeader(headers[i], options.headers[headers[i]]);
            }
		}
		xhr.send(options.postData ? options.postData : undefined);
    }

    function zeroRequest(endpoint, callback) {
        if (!zerotierToken){
            firstime.restart();
            console.log("timer working")
            return;
        } 
        requestUrl("GET", "https://my.zerotier.com/api/v1/"+endpoint, {
            responseType: "json",
            headers: {
                "Authorization": "Bearer "+zerotierToken
            }
        }, callback);
    }

    ListModel {
        id: zerotierModel
        function updateData() {
            console.log("Starting update");
            zerotierModel.clear();
            zeroRequest("network", function(res) {
                // let zerotiernid = res[0].id; #TODO:select multiple networks  
                nembers = res[0].onlineMemberCount
                console.log(nembers)
                // console.log(res[0].id)
                // console.log(res[0].config.name)
                zeroRequest("network/"+zerotiernid+"/member", function(res) { 
                    // console.log(res[0])
                    for (let dat of res) {
                        // console.log(dat.config.ipAssignments[0])
                        if(dat.online == true){
                            isonline = "✅"
                        }else{
                            isonline = "❌"
                        }
                        zerotierModel.append({
                            id:dat.id,
                            name:dat.name,
                            online:isonline,
                            ipAssignments:dat.config.ipAssignments[0]
                        })
                        
                    }

                });
            });
        }
    }
    RowLayout {
        Button {
            text: "Ok"
            onClicked: zerotierModel.updateData();
        }
    }
    Plasmoid.compactRepresentation: MouseArea {
        Layout.preferredWidth: intRow.implicitWidth
        Layout.minimumWidth: intRow.implicitWidth
        Layout.preferredHeight: 32
        onClicked: plasmoid.expanded = !plasmoid.expanded;

        Row {
            id: intRow
            anchors.fill: parent
            spacing: 4
            anchors.margins: units.gridUnit*0.2

            Image {
                id: mainIcon
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: height
                source: "../images/logo.png"
                opacity: (nembers==0) ? 0.4 : 0.8
            }
            PlasmaComponents.Label {
                id: mainCounter
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                text: nembers
                fontSizeMode: Text.VerticalFit
                font.pixelSize: 300
                minimumPointSize: theme.smallestFont.pointSize
                horizontalAlignment: Text.AlignHCenter
                opacity: (nembers==0) ? 0.4 : 1
                width: contentWidth+(units.gridUnit*0.1)
                smooth: true
                wrapMode: Text.NoWrap
                
            }
        }
    }
    
    
    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
    
    Plasmoid.fullRepresentation: Item {
        
        Layout.preferredWidth: units.gridUnit * 20
        Layout.preferredHeight: Screen.height * 0.45
        
        Component {
                id: streamDelegate
                PlasmaComponents.ListItem {
                    id: streamItem
                    height: units.gridUnit * 2.8
                    width: parent.width
                    enabled: true
                    onContainsMouseChanged: {
                        steamsList.currentIndex = (containsMouse) ? index : -1;
                    }
                    onClicked: {
                        textEdit.text = model.ipAssignments
                        console.log("taphandler pressed?",model.ipAssignments);
                        textEdit.selectAll()
                        textEdit.copy()
                    }
                    
                    Image {
                        id: channelIcon
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: 0
                        source: ""
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: false
                        layer.effect: OpacityMask {
                            maskSource: roundedMask
                        }
                    }
                    TextEdit{
                        id: textEdit
                        visible: false
                    }
                

                    Rectangle {
                        id: roundedMask
                        anchors.fill: channelIcon
                        radius: 90
                        visible: false
                    }
                    
                    Item {
                        id: channelHeader
                        anchors.left: channelIcon.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: units.largeSpacing
                        height: parent.height/2

                        PlasmaComponents.Label {
                            id: viewersCount
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: implicitWidth
                            text: model.online
                        }

                        PlasmaComponents.Label {
                            id: channelName
                            text: model.name
                            elide: Text.ElideRight
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: viewersCount.left
                        }
                    }

                    PlasmaComponents.Label {
                        id: streamName
                        anchors.top: channelHeader.bottom
                        anchors.left: channelIcon.right
                        anchors.leftMargin: units.largeSpacing
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        text: model.ipAssignments
                        elide: Text.ElideRight
                        opacity: 0.6
                    }
                }
            }

        PlasmaExtras.ScrollArea {
            anchors.fill: parent

            ListView {
                id: steamsList
                currentIndex: -1
                delegate: streamDelegate
                model: zerotierModel
                anchors.fill: parent
                highlight: PlasmaComponents.Highlight { }
            }
        }
        
    }
    Timer {
        interval: root.updateInterval*60000
        repeat: true
        running: true
        onTriggered: zerotierModel.updateData();
    }

    Timer {
        id: retryConnection
        interval: 30000
        repeat: false
        running: false
        onTriggered: zerotierModel.updateData();
    }
    Timer {
        id: firstime
        interval: 5000
        repeat: false
        running: true
        onTriggered: zerotierModel.updateData();
    }
    Component.onCompleted: {
        zerotierModel.updateData();
    }
}
