import QtQuick
import org.kde.plasma.plasma5support as P5Support

/** Runs a shell command and hands its stdout to a callback. */
Item {
    id: runner

    property string command: ""
    /** Set before calling run(); invoked with the command's stdout. */
    property var callback: null

    function run() {
        if (command.length === 0) {
            return;
        }
        executable.connectSource(command);
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            if (runner.callback) {
                runner.callback(String(data["stdout"] || ""));
            }
        }
    }
}
