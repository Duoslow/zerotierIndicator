import QtQuick
import org.kde.plasma.plasma5support as P5Support

/**
 * Finds the zerotier-one auth token.
 *
 * Qt 6 refuses to read local files over XMLHttpRequest unless the process was
 * started with QML_XHR_ALLOW_FILE_READ=1 -- and it fails silently, the request
 * simply never completes. We cannot set that for plasmashell, so the file is
 * read through the executable data engine instead.
 */
Item {
    id: reader

    /** An explicitly configured token wins over anything on disk. */
    property string configuredToken: ""

    readonly property alias token: internal.token
    readonly property alias source: internal.source
    readonly property alias resolved: internal.resolved

    // The daemon's own file is root only, so the per-user copy is normally the
    // one that works. Echoing the path first tells the UI where it came from.
    readonly property string command:
        'for f in "$HOME/.zerotierOneAuthToken" /var/lib/zerotier-one/authtoken.secret; do'
        + ' [ -r "$f" ] && { echo "$f"; cat "$f"; break; }; done'

    function resolve() {
        if (configuredToken.length > 0) {
            internal.token = configuredToken;
            internal.source = "widget settings";
            internal.resolved = true;
            return;
        }
        internal.resolved = false;
        executable.connectSource(command);
    }

    QtObject {
        id: internal
        property string token: ""
        property string source: ""
        property bool resolved: false
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);

            const lines = String(data["stdout"] || "").split("\n").filter(function (line) {
                return line.trim().length > 0;
            });

            internal.source = lines.length > 0 ? lines[0].trim() : "";
            internal.token = lines.length > 1 ? lines[1].trim() : "";
            internal.resolved = true;
        }
    }

    Component.onCompleted: resolve()
    onConfiguredTokenChanged: resolve()
}
