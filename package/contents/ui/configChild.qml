import QtQuick 2.9
import QtQuick.Window 2.2
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
ApplicationWindow{
    id:root
    width:400;height:400
    title:"Network Selector"
    property string zerotierToken: plasmoid.configuration.zerotierToken
    property string selected_network: plasmoid.configuration.selectednetwork
    RowLayout {
        anchors.fill: parent
        height: parent.height
        width: 1500
        ListModel {
            id: zmodel
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
                    console.log("no token provided")
                    return;
                } 
                requestUrl("GET", "https://my.zerotier.com/api/v1/"+endpoint, {
                    responseType: "json",
                    headers: {
                        "Authorization": "Bearer "+zerotierToken
                    }
                }, callback);
            }

            function getnetworks(){
                zeroRequest("network", function(res) {
                    for (let dat of res)
                    {
                        zmodel.append({
                                n_id:dat.id,
                                n_name:dat.config.name,
                                n_count:dat.totalMemberCount,
                                n_stat: (selected_network.split(',').indexOf(dat.id) >= 0) ? "✅" : "❌"
                            })
                    }
                    // console.log(res[0].id)
                });
            }
        }
        Timer {
            id: retryConnection
            interval: 30000
            repeat: false
            running: false
            onTriggered: zmodel.getnetworks()
        }

        ListView {
            
            id: zlist
            anchors.fill: parent
            model: zmodel
            
            function data_adder(a1,a2){
                // console.log("Selected: "+a1)
                // console.log("a2 data= ",a2)
                if(!plasmoid.configuration.selectednetwork){
                    // console.log("new data")
                    plasmoid.configuration.selectednetwork = a1
                    zmodel.setProperty(a2,"n_stat","✅")
                    return "Added"
                }else if(selected_network.split(',').indexOf(a1)== -1){
                        // console.log("data not found")
                        plasmoid.configuration.selectednetwork = a1 + "," + plasmoid.configuration.selectednetwork
                        // console.log("new data = ",plasmoid.configuration.selectednetwork )
                        zmodel.setProperty(a2,"n_stat","✅")
                        return "Added"
                    }else{
                        // console.log("data found")
                        return "Already Have"
                        // console.log("data = ",plasmoid.configuration.selectednetwork )
                    }                
            }
            function removeValue(mlist, value) {
                return mlist.replace(new RegExp(",?" + value + ",?"), function(match) {
                    var first_comma = match.charAt(0) === ',',
                        second_comma;

                    if (first_comma &&
                        (second_comma = match.charAt(match.length - 1) === ',')) {
                        return ',';
                    }
                    return '';
                    });
            }
            function data_remover(a1,a2){
                console.log("Removed",a1)
                plasmoid.configuration.selectednetwork = removeValue(plasmoid.configuration.selectednetwork,a1)
                zmodel.setProperty(a2,"n_stat","❌")
                return "Removed"
            }

            delegate: Component {
                Item {
                    width: parent.width
                    height: 90
                    Column {
                        padding: 8
                        Text { text: '<font color=\"#FFFFFF\">Name:</font> <font color=\"#FBBA40\">' + n_name +"</font>" }
                        Text { text: '<font color=\"#FFFFFF\">ID:</font> ' + n_id }
                        Text { text: '<font color=\"#FFFFFF\">Member Count:</font> ' + n_count }
                        Text { text: '<font color=\"#FFFFFF\">Selected:</font> ' + n_stat }

                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: zlist.currentIndex = index
                    }
                }
            }
            highlight: Rectangle {
                color: 'grey'
                // Text {
                //     anchors.centerIn: parent
                //     text: ' Selected ' //+ zmodel.get(zlist.currentIndex).name
                //     color: 'white'
                //     font.pointSize :10
                // }
            }
            focus: true
            // onCurrentItemChanged: test(zmodel.get(zlist.currentIndex).n_id)
            
        }
        Timer {
            id: timer
            function setTimeout(cb, delayTime) {
                timer.interval = delayTime;
                timer.repeat = false;
                timer.triggered.connect(cb);
                timer.triggered.connect(function release () {
                    timer.triggered.disconnect(cb); 
                    timer.triggered.disconnect(release); 
                });
                timer.start();
            }
        }
        RowLayout{
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            Button{
                id:"bt_add"
                text:"Add"
                onClicked:{
                    bt_add.text = zlist.data_adder(zmodel.get(zlist.currentIndex).n_id , zlist.currentIndex);
                    timer.setTimeout(function(){ bt_add.text = "Add"; }, 1000);
                }
            }
            Button{
                anchors.left:bt_add.right
                id:"bt_remove"
                text:"Remove"
                onClicked:{
                    bt_remove.text = zlist.data_remover(zmodel.get(zlist.currentIndex).n_id , zlist.currentIndex)
                    timer.setTimeout(function(){ bt_remove.text = "Remove"; }, 1000);
                }
            }
        }
        
    }
    Component.onCompleted: {
        console.log(zerotierToken);
        zmodel.getnetworks();
    }
}
