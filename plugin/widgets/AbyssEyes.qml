import QtQuick

// ---------------------------------------------------------------------------
// 👀 Abyss Eyes -- one eye, a pair set like a face (left eye mirrored,
// about half an eye-width apart), or the Beholder (AbyssBeholder.qml). All
// share gaze, blinks and pupils, so a group always moves as one.
// ---------------------------------------------------------------------------
Item {
  id: eyes

  property string form: "one"   // one | pair | beholder
  readonly property bool pair: form === "pair"
  property string styleId: "classic"
  property string irisStyle: "auto"
  property var theme: ({})
  property real gazeX: 0
  property real gazeY: 0
  property real openness: 1
  property real pupilScale: 1
  property real glow: 1
  property real irisGlow: 0

  AbyssEye {
    visible: eyes.pair
    x: eyes.width * 0.29 - width / 2
    width: eyes.width * 0.42
    height: eyes.height
    mirrored: true
    styleId: eyes.styleId
    irisStyle: eyes.irisStyle
    theme: eyes.theme
    gazeX: eyes.gazeX
    gazeY: eyes.gazeY
    openness: eyes.openness
    pupilScale: eyes.pupilScale
    irisGlow: eyes.irisGlow
    glow: eyes.glow
  }

  AbyssEye {
    visible: eyes.form !== "beholder"
    x: eyes.pair ? eyes.width * 0.71 - width / 2 : 0
    width: eyes.pair ? eyes.width * 0.42 : eyes.width
    height: eyes.height
    styleId: eyes.styleId
    irisStyle: eyes.irisStyle
    theme: eyes.theme
    gazeX: eyes.gazeX
    gazeY: eyes.gazeY
    openness: eyes.openness
    pupilScale: eyes.pupilScale
    irisGlow: eyes.irisGlow
    glow: eyes.glow
  }

  AbyssBeholder {
    anchors.fill: parent
    visible: eyes.form === "beholder"
    styleId: eyes.styleId
    irisStyle: eyes.irisStyle
    theme: eyes.theme
    gazeX: eyes.gazeX
    gazeY: eyes.gazeY
    openness: eyes.openness
    pupilScale: eyes.pupilScale
    irisGlow: eyes.irisGlow
    glow: eyes.glow
  }
}
