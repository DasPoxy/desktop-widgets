import QtQuick

// ---------------------------------------------------------------------------
// 👀 Abyss Eyes -- one eye, or a pair set like a face (left eye mirrored,
// about half an eye-width apart). Both share gaze, blinks and pupils, so a
// pair always moves as one.
// ---------------------------------------------------------------------------
Item {
  id: eyes

  property bool pair: false
  property string styleId: "classic"
  property string irisStyle: "auto"
  property var theme: ({})
  property real gazeX: 0
  property real gazeY: 0
  property real openness: 1
  property real pupilScale: 1
  property real glow: 1

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
    glow: eyes.glow
  }

  AbyssEye {
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
    glow: eyes.glow
  }
}
