import QtQuick

// "Grid Mode" lines: continues a widget's header divider down between its
// cells. xs are vertical lines (running vTop..vBottom), ys horizontal ones
// (running hLeft..hRight), all in this item's parent's coordinates.
Item {
  id: lines
  property var xs: []
  property var ys: []
  property real vTop: 0
  property real vBottom: 0
  property real hLeft: 0
  property real hRight: 0
  property color color: Qt.rgba(1, 1, 1, 0.08)
  property real thickness: 1

  Repeater {
    model: lines.xs
    Rectangle {
      required property var modelData
      x: Math.round(modelData - lines.thickness / 2)
      y: lines.vTop
      width: lines.thickness
      height: Math.max(0, lines.vBottom - lines.vTop)
      color: lines.color
    }
  }

  Repeater {
    model: lines.ys
    Rectangle {
      required property var modelData
      x: lines.hLeft
      y: Math.round(modelData - lines.thickness / 2)
      width: Math.max(0, lines.hRight - lines.hLeft)
      height: lines.thickness
      color: lines.color
    }
  }
}
