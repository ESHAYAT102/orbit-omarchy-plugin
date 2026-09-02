pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
  id: root

  property string shapeName: "circle"
  property string bodyColor: "#0A0A0C"
  property string expressionName: "neutral"
  property string buddyState: "idle"
  property bool motionEnabled: true
  property bool hovered: false
  property bool dragging: false
  property real gazeX: 0
  property real gazeY: 0
  property bool followTarget: true
  property string previousShape: shapeName
  property string renderedShape: shapeName
  property real morphProgress: 1
  property real phase: 0
  property real popScale: 1
  property string previousExpression: expressionName
  property string renderedExpression: expressionName
  property real expressionMix: 1
  property string thinkingExpression: "suspicious"
  property bool sleeping: false
  property bool drowsy: false
  property real blinkLevel: 0
  property bool doubleBlink: false
  property real wakeJoltX: 0
  readonly property string activeExpression: {
    if (buddyState === "listening") return "attentive"
    if (buddyState === "transcribing") return "confused"
    if (buddyState === "thinking") return thinkingExpression
    if (buddyState === "speaking") return "excited"
    if (buddyState === "waiting") return "curious"
    if (buddyState === "error") return "sad"
    if (sleeping || drowsy) return "sleepy"
    return expressionName
  }
  readonly property color eyeColor: contrastColor(bodyColor)
  readonly property real blinkAmount:
    motionEnabled && activeExpression !== "surprised" && activeExpression !== "scared"
      ? blinkLevel : 0
  readonly property real eyeOffsetX: {
    var wander = motionEnabled ? Math.sin(phase * 0.82) * 0.22 : 0
    var target = followTarget ? Math.max(-1, Math.min(1, gazeX)) * 0.78 + wander : wander * 2.1
    return target * width * 0.045
  }
  readonly property real eyeOffsetY: {
    var wander = motionEnabled ? Math.sin(phase * 0.57 + 1.4) * 0.15 : 0
    var target = followTarget ? Math.max(-1, Math.min(1, gazeY)) * 0.78 + wander : wander * 2.1
    return target * height * 0.035
  }

  function celebrate() { pop.restart() }

  function transitionExpression() {
    if (root.activeExpression === root.renderedExpression) return
    root.previousExpression = root.renderedExpression
    root.renderedExpression = root.activeExpression
    root.expressionMix = 0
    expressionMorph.restart()
  }

  function randomizeThinkingExpression() {
    var faces = ["attentive", "curious", "confused", "suspicious", "unimpressed"]
    var next = root.thinkingExpression
    while (next === root.thinkingExpression)
      next = faces[Math.floor(Math.random() * faces.length)]
    root.thinkingExpression = next
    thinkingFaceTimer.interval = 900 + Math.floor(Math.random() * 1300)
  }

  function contrastColor(hex) {
    var text = String(hex || "#000000").replace("#", "")
    if (text.length !== 6) return "#ffffff"
    var r = parseInt(text.slice(0, 2), 16)
    var g = parseInt(text.slice(2, 4), 16)
    var b = parseInt(text.slice(4, 6), 16)
    return (r * 0.299 + g * 0.587 + b * 0.114) > 170 ? "#15151a" : "#ffffff"
  }

  function eyeCenterY(expression) {
    var centers = {
      angry: 472.5, attentive: 308.5, confused: 467.5, curious: 578,
      excited: 605, happy: 448.5, laughing: 415, neutral: 505,
      proud: 396.5, sad: 590.5, scared: 643, shy: 588,
      sleepy: 559.5, surprised: 533.5, suspicious: 503.5, unimpressed: 495
    }
    return (centers[expression] || 512) / 1024
  }

  function eyeMetrics(expression) {
    var metrics = {
      angry: [421.3, 473.6, 127, 98, 660.2, 471.2, 121, 99],
      attentive: [591.2, 326.1, 115, 147, 765.1, 287.7, 100, 142],
      confused: [280.1, 467.0, 79, 177, 498.4, 498.7, 112, 87],
      curious: [521.2, 602.4, 130, 132, 737.7, 540.9, 93, 109],
      excited: [429.3, 606.7, 172, 224, 700.1, 602.7, 157, 224],
      happy: [423.1, 447.0, 107, 77, 661.8, 449.0, 103, 77],
      laughing: [386.8, 414.9, 129, 75, 639.8, 414.1, 128, 75],
      neutral: [397.2, 512.8, 91, 181, 622.4, 496.5, 90, 182],
      proud: [395.9, 395.4, 116, 73, 635.3, 397.2, 116, 73],
      sad: [427.4, 590.9, 106, 164, 652.5, 587.9, 106, 163],
      scared: [397.5, 641.0, 162, 233, 683.4, 643.8, 154, 233],
      shy: [308.0, 600.5, 71, 120, 494.8, 574.9, 80, 121],
      sleepy: [455.9, 565.3, 85, 78, 679.2, 553.1, 79, 79],
      surprised: [404.5, 528.9, 178, 193, 670.4, 536.5, 170, 194],
      suspicious: [462.4, 503.1, 96, 163, 683.7, 478.0, 83, 65],
      unimpressed: [251.9, 492.3, 97, 51, 459.8, 496.7, 123, 52]
    }
    return metrics[expression] || metrics.neutral
  }

  onShapeNameChanged: {
    previousShape = renderedShape
    renderedShape = shapeName
    morphProgress = 0
    morph.restart()
  }
  onActiveExpressionChanged: transitionExpression()
  onSleepingChanged: {
    if (sleeping) {
      blinkTimer.stop()
      blinkAnimation.stop()
      fallingAsleep.running = true
    } else {
      startWakeAnimation()
    }
  }
  onBodyColorChanged: canvas.requestPaint()
  onExpressionNameChanged: canvas.requestPaint()
  onBuddyStateChanged: canvas.requestPaint()
  onGazeXChanged: canvas.requestPaint()
  onGazeYChanged: canvas.requestPaint()
  onPhaseChanged: canvas.requestPaint()
  onMorphProgressChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Behavior on gazeX { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
  Behavior on gazeY { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

  NumberAnimation {
    target: root
    property: "phase"
    from: 0
    to: Math.PI * 2
    duration: root.buddyState === "listening" ? 2200 : 5200
    loops: Animation.Infinite
    running: root.motionEnabled
  }

  Timer {
    id: thinkingFaceTimer
    interval: 1200
    repeat: true
    running: root.buddyState === "thinking"
    triggeredOnStart: true
    onTriggered: root.randomizeThinkingExpression()
  }

  Timer {
    id: blinkTimer
    interval: 1800
    repeat: true
    running: root.motionEnabled && !root.sleeping
    onTriggered: {
      interval = 2200 + Math.floor(Math.random() * 4300)
      root.doubleBlink = Math.random() < 0.22
      blinkAnimation.restart()
    }
  }

  SequentialAnimation {
    id: blinkAnimation
    NumberAnimation { target: root; property: "blinkLevel"; from: 0; to: 1; duration: 70; easing.type: Easing.InCubic }
    NumberAnimation { target: root; property: "blinkLevel"; from: 1; to: 0; duration: 110; easing.type: Easing.OutCubic }
    PauseAnimation { duration: root.doubleBlink ? 90 : 0 }
    NumberAnimation { target: root; property: "blinkLevel"; from: 0; to: 1; duration: root.doubleBlink ? 65 : 0; easing.type: Easing.InCubic }
    NumberAnimation { target: root; property: "blinkLevel"; from: 1; to: 0; duration: root.doubleBlink ? 105 : 0; easing.type: Easing.OutCubic }
  }

  SequentialAnimation {
    id: fallingAsleep
    ScriptAction { script: blinkTimer.stop() }
    NumberAnimation { target: root; property: "blinkLevel"; from: 0; to: 1; duration: 100; easing.type: Easing.InCubic }
    NumberAnimation { target: root; property: "blinkLevel"; from: 1; to: 0; duration: 160; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 250 }
    NumberAnimation { target: root; property: "blinkLevel"; from: 0; to: 1; duration: 120; easing.type: Easing.InCubic }
    NumberAnimation { target: root; property: "blinkLevel"; from: 1; to: 0; duration: 180; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 350 }
    NumberAnimation { target: root; property: "blinkLevel"; from: 0; to: 1; duration: 150; easing.type: Easing.InCubic }
    NumberAnimation { target: root; property: "blinkLevel"; from: 1; to: 0; duration: 200; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 450 }
    NumberAnimation { target: root; property: "blinkLevel"; from: 0; to: 1; duration: 200; easing.type: Easing.InCubic }
    ScriptAction { script: root.sleepReady = true }
  }
  property int wakeStepsLeft: 0
  property int wakeBlinksLeft: 0
  property real wakeTargetX: 0
  property bool sleepReady: false

  function randomWakeStep() {
    if (wakeStepsLeft <= 0) {
      wakeMoveAnim.stop()
      wakeBlinkAnim.stop()
      root.blinkLevel = 0
      root.wakeTargetX = 0
      root.wakeJoltX = 0
      blinkTimer.restart()
      return
    }

    wakeStepsLeft--

    var dir = Math.random() < 0.5 ? 1 : -1
    var dist = (0.02 + Math.random() * 0.04) * root.width * dir
    root.wakeTargetX = dist
    var moveDur = 60 + Math.floor(Math.random() * 90)
    var blinkDur = Math.floor(Math.random() * 160) + 80

    var shouldBlink = wakeBlinksLeft > 0 || Math.random() < 0.65
    if (shouldBlink && wakeBlinksLeft > 0) wakeBlinksLeft--

    if (shouldBlink) {
      wakeBlinkAnim.from = root.blinkLevel < 0.5 ? 0 : 1
      wakeBlinkAnim.to = root.blinkLevel < 0.5 ? 1 : 0
      wakeBlinkAnim.duration = blinkDur
      wakeBlinkAnim.start()
    }

    wakeMoveAnim.to = dist
    wakeMoveAnim.duration = moveDur
    wakeMoveAnim.start()

    wakeStepTimer.interval = moveDur + 20 + Math.floor(Math.random() * 80)
    wakeStepTimer.restart()
  }

  NumberAnimation {
    id: wakeMoveAnim
    target: root
    property: "wakeJoltX"
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: wakeBlinkAnim
    target: root
    property: "blinkLevel"
    easing.type: Easing.InOutCubic
  }

  Timer {
    id: wakeStepTimer
    interval: 100
    repeat: false
    onTriggered: root.randomWakeStep()
  }

  function startWakeAnimation() {
    blinkTimer.stop()
    wakeBlinkAnim.stop()
    wakeMoveAnim.stop()
    root.sleepReady = false
    wakeStepsLeft = 5 + Math.floor(Math.random() * 3)
    wakeBlinksLeft = 3
    randomWakeStep()
  }

  NumberAnimation {
    id: morph
    target: root
    property: "morphProgress"
    to: 1
    duration: 420
    easing.type: Easing.OutQuint
  }

  SequentialAnimation {
    id: pop
    NumberAnimation { target: root; property: "popScale"; to: 0.90; duration: 90; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "popScale"; to: 1.10; duration: 150; easing.type: Easing.OutBack }
    NumberAnimation { target: root; property: "popScale"; to: 1.00; duration: 180; easing.type: Easing.OutCubic }
  }

  NumberAnimation {
    id: expressionMorph
    target: root
    property: "expressionMix"
    to: 1
    duration: 420
    easing.type: Easing.InOutCubic
    onFinished: root.previousExpression = root.renderedExpression
  }

  Item {
    id: character
    anchors.centerIn: parent
    width: parent.width
    height: parent.height
    scale: root.popScale * (root.dragging ? 1.06 : (root.hovered ? 1.035 : 1.0))
      * (root.buddyState === "listening" ? 1 + Math.sin(root.phase * 2) * 0.018 : 1)
    rotation: root.dragging ? -3 : 0

    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Canvas {
      id: canvas
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative
      antialiasing: true

      function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value))
      }

      function easeOutQuint(value) {
        return 1 - Math.pow(1 - clamp(value, 0, 1), 5)
      }

      function polygonFactor(sides, angle, rotation, scale) {
        var sector = Math.PI * 2 / sides
        var local = ((angle - rotation + sector / 2) % sector + sector) % sector - sector / 2
        return scale * Math.cos(Math.PI / sides) / Math.cos(local)
      }

      function radialFactor(shape, angle, time) {
        var breathe = root.motionEnabled ? Math.sin(time * 2 + angle * 3) * 0.008 : 0
        if (shape === "pebble")
          return 0.96 + Math.cos(angle * 2 - 0.65) * 0.075 + Math.sin(angle * 3 + 0.8) * 0.03 + breathe
        if (shape === "squircle") {
          var squareX = Math.abs(Math.cos(angle))
          var squareY = Math.abs(Math.sin(angle))
          return Math.pow(Math.pow(squareX, 4) + Math.pow(squareY, 4), -0.25) * 0.86 + breathe
        }
        if (shape === "capsule") {
          var capsuleX = Math.abs(Math.cos(angle)) / 1.20
          var capsuleY = Math.abs(Math.sin(angle)) / 0.67
          return Math.pow(Math.pow(capsuleX, 6) + Math.pow(capsuleY, 6), -1 / 6) * 0.88 + breathe
        }
        if (shape === "triangle") return polygonFactor(3, angle, -Math.PI / 2, 0.98) + breathe
        if (shape === "hexagon") return polygonFactor(6, angle, 0, 0.96) + breathe
        if (shape === "cloud")
          return 0.93 + Math.cos(angle * 6 + 0.3) * 0.09 + Math.sin(angle * 3) * 0.03 + breathe
        if (shape === "droplet")
          return 0.96 - Math.max(0, -Math.sin(angle)) * 0.24 + Math.max(0, Math.sin(angle)) * 0.10 + breathe
        return 0.96 + breathe
      }

      function profile(shape, count, radius, centerX, centerY) {
        var points = []
        for (var i = 0; i < count; i++) {
          var angle = -Math.PI / 2 + i * Math.PI * 2 / count
          var oldFactor = radialFactor(root.previousShape, angle, root.phase)
          var nextFactor = radialFactor(shape, angle, root.phase)
          var factor = oldFactor + (nextFactor - oldFactor) * easeOutQuint(root.morphProgress)
          var driftX = root.motionEnabled ? Math.sin(root.phase * 1.4) * radius * 0.008 : 0
          var driftY = root.motionEnabled ? Math.cos(root.phase * 1.1) * radius * 0.007 : 0
          points.push({
            x: centerX + driftX + Math.cos(angle) * radius * factor,
            y: centerY + driftY + Math.sin(angle) * radius * factor
          })
        }
        return points
      }

      function traceSmooth(context, points) {
        var count = points.length
        context.beginPath()
        context.moveTo(points[0].x, points[0].y)
        for (var i = 0; i < count; i++) {
          var p0 = points[(i - 1 + count) % count]
          var p1 = points[i]
          var p2 = points[(i + 1) % count]
          var p3 = points[(i + 2) % count]
          context.bezierCurveTo(
            p1.x + (p2.x - p0.x) / 6,
            p1.y + (p2.y - p0.y) / 6,
            p2.x - (p3.x - p1.x) / 6,
            p2.y - (p3.y - p1.y) / 6,
            p2.x,
            p2.y
          )
        }
        context.closePath()
      }

      onPaint: {
        var context = getContext("2d")
        context.reset()
        context.clearRect(0, 0, width, height)
        var centerX = width / 2
        var centerY = height / 2
        var radius = Math.min(width, height) * 0.417
        var points = profile(root.renderedShape, 48, radius, centerX, centerY)

        context.save()
        context.translate(0, Math.max(2, radius * 0.07))
        traceSmooth(context, points)
        context.fillStyle = "rgba(0,0,0,0.22)"
        context.fill()
        context.restore()

        traceSmooth(context, points)
        context.fillStyle = root.bodyColor
        context.fill()
        context.save()
        context.globalAlpha = 0.13
        context.strokeStyle = root.eyeColor
        context.lineWidth = Math.max(1, radius * 0.018)
        context.stroke()
        context.restore()

        if (root.buddyState === "listening") {
          context.beginPath()
          context.arc(centerX, centerY, radius * (1.09 + Math.sin(root.phase * 2) * 0.035), 0, Math.PI * 2)
          context.lineWidth = Math.max(2, radius * 0.035)
          context.strokeStyle = root.eyeColor
          context.globalAlpha = 0.48
          context.stroke()
        }
      }
    }

    Item {
      id: expressionLayer
      anchors.fill: parent
      readonly property var fromEyes: root.eyeMetrics(root.previousExpression)
      readonly property var toEyes: root.eyeMetrics(root.renderedExpression)

      transform: [
        Scale {
          origin.x: expressionLayer.width / 2
          origin.y: expressionLayer.height * (root.eyeCenterY(root.previousExpression) * (1 - root.expressionMix)
            + root.eyeCenterY(root.renderedExpression) * root.expressionMix)
          yScale: 1 - root.blinkAmount * 0.90
        },
        Translate {
          x: root.eyeOffsetX + root.wakeJoltX
          y: root.eyeOffsetY
        }
      ]

      Image {
        anchors.fill: parent
        source: "expressions/eyes/" + root.previousExpression + "-left.png"
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect {
          colorization: 1
          colorizationColor: root.eyeColor
        }
        transform: [
          Scale {
            origin.x: expressionLayer.width * expressionLayer.fromEyes[0] / 1024
            origin.y: expressionLayer.height * expressionLayer.fromEyes[1] / 1024
            xScale: 1 + (expressionLayer.toEyes[2] / expressionLayer.fromEyes[2] - 1) * root.expressionMix
            yScale: 1 + (expressionLayer.toEyes[3] / expressionLayer.fromEyes[3] - 1) * root.expressionMix
          },
          Translate {
            x: expressionLayer.width * (expressionLayer.toEyes[0] - expressionLayer.fromEyes[0]) / 1024 * root.expressionMix
            y: expressionLayer.height * (expressionLayer.toEyes[1] - expressionLayer.fromEyes[1]) / 1024 * root.expressionMix
          }
        ]
      }

      Image {
        anchors.fill: parent
        source: "expressions/eyes/" + root.previousExpression + "-right.png"
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect {
          colorization: 1
          colorizationColor: root.eyeColor
        }
        transform: [
          Scale {
            origin.x: expressionLayer.width * expressionLayer.fromEyes[4] / 1024
            origin.y: expressionLayer.height * expressionLayer.fromEyes[5] / 1024
            xScale: 1 + (expressionLayer.toEyes[6] / expressionLayer.fromEyes[6] - 1) * root.expressionMix
            yScale: 1 + (expressionLayer.toEyes[7] / expressionLayer.fromEyes[7] - 1) * root.expressionMix
          },
          Translate {
            x: expressionLayer.width * (expressionLayer.toEyes[4] - expressionLayer.fromEyes[4]) / 1024 * root.expressionMix
            y: expressionLayer.height * (expressionLayer.toEyes[5] - expressionLayer.fromEyes[5]) / 1024 * root.expressionMix
          }
        ]
      }
    }

    Item {
      id: sleepZs
      anchors.fill: parent
      opacity: root.sleepReady ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 300 } }

      Repeater {
        model: root.sleepReady ? 3 : 0

        Text {
          id: zChar
          required property int index
          property real progress: 0
          property int launchDelay: 200 + Math.floor(Math.random() * 1300)
          property int travelDuration: 900 + Math.floor(Math.random() * 500)
          property real originJitter: (Math.random() - 0.5) * 0.04
          property real drift: 0.04 + Math.random() * 0.07
          property real rise: 0.32 + Math.random() * 0.10

          function randomizeFlight() {
            launchDelay = 200 + Math.floor(Math.random() * 1300)
            travelDuration = 900 + Math.floor(Math.random() * 500)
            originJitter = (Math.random() - 0.5) * 0.04
            drift = 0.04 + Math.random() * 0.07
            rise = 0.32 + Math.random() * 0.10
          }

          text: "Z"
          color: root.eyeColor
          font.family: "sans-serif"
          font.pixelSize: Math.max(12, root.width * 0.11)
          font.bold: true
          x: root.width * (0.12 + originJitter + progress * drift)
          y: root.height * (0.20 - progress * rise)
          opacity: Math.sin(progress * Math.PI) * 0.8
          scale: 0.8 + Math.min(1, progress * 5) * 0.2

          SequentialAnimation on progress {
            loops: Animation.Infinite
            running: root.sleeping
            ScriptAction { script: zChar.randomizeFlight() }
            PauseAnimation { duration: zChar.launchDelay }
            NumberAnimation { from: 0; to: 1; duration: zChar.travelDuration; easing.type: Easing.OutCubic }
            PropertyAction { value: 0 }
          }
        }
      }
    }

    opacity: 1
  }
}
