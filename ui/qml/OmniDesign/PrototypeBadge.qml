import QtQuick

// Etichetta obbligatoria per ogni funzione NON ancora operativa nel sistema reale.
Rectangle {
    id: root
    property string text: qsTr("Prototipo")
    property bool inverted: false   // su superfici colorate con l'accento
    implicitWidth: label.implicitWidth + Theme.s3
    implicitHeight: label.implicitHeight + Theme.s1 + 2
    radius: height / 2
    color: inverted ? Qt.rgba(0, 0, 0, 0.12) : Theme.prototypeSoft
    border.color: inverted ? Theme.textOnAccent : Theme.prototype
    border.width: 1
    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.inverted ? Theme.textOnAccent : Theme.prototype
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
    }
}
