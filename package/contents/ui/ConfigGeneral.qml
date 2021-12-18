import QtQuick 2.0
import QtQuick.Window 2.2
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: generalSettings
    property alias cfg_updateInterval: updateTime.value
    property alias cfg_zerotierToken: ztoken.text
    property string cfg_zerotierToken: ""
    property string selectednetwork: plasmoid.configuration.selectednetwork
    

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
                focus:true
                Layout.preferredWidth: 250
                onTextChanged:{
                    netbutton.enabled = true
                    plasmoid.configuration.zerotierToken = ztoken.text
                    }
            }
            Button{
                text:"Get Here!"
                onClicked:{
                    Qt.openUrlExternally("https://my.zerotier.com/account")
                }
            }
        }
        RowLayout{
            Label{
                text:"Current Networks       "
            }
            TextField {
			    id: znid
                enabled:false
                placeholderText: "There is currently no network id"
                textColor:"white"
                Layout.preferredWidth: 350
		    }
        }
        RowLayout {
		    Label {
			    text: "Network Selection      "
		    }
            Button {
                id:"netbutton"
                text:"Select Network"
                enabled:false
                onClicked:{
                    var component = Qt.createComponent("configChild.qml")
                    if( component.status != Component.Ready )
                    {
                        if( component.status == Component.Error )
                            console.debug("Error:"+ component.errorString() );
                        return; // or maybe throw
                    }
                    var window    = component.createObject(root)
                    window.show()
                    
                }
            }
            // Button { #TODO:select all function
            //     id:"selectall"
            //     text:"Select All"
            //     enabled:false
            //     onClicked:{
            //         console.log("Select all")
            //     }
            // }
		    
	    }
        RowLayout{
            Label{
                text: "Show Only Online Members"
            }
            CheckBox{
                id: showonly
                checked: plasmoid.configuration.show
                onCheckedChanged: plasmoid.configuration.show = checked
            }
            // Button{ //TEST BUTTON
            //     // property string myString: plasmoid.configuration.selectednetwork
            //     // property variant stringList: myString.split(',')
            //     text:"test"
            //     onClicked:{
            //         console.log(plasmoid.configuration.show)
            //         // for(let data of stringList){
            //         //     console.log("hehe: ",data)
            //         // }
            //         // console.log(stringList[0]); 
            //     }
            // }
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
    onSelectednetworkChanged:{
        console.log("selected networks changed");
        znid.text = plasmoid.configuration.selectednetwork
    }
    
    
}
