pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var service: null
  property var manifest: null

  Variants {
    model: Quickshell.screens.slice(0, 1)

    PanelWindow {
      id: window
       required property var modelData
       property bool textEntryOpen: false

       screen: modelData
      visible: root.service && root.service.blobVisible && !root.service.hideOverlayForCapture && !remapGuard.remapping
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      mask: Region {
         Region { item: blobHost }
         Region {
           item: speechBubble.visible ? bubbleInputRegion : null
           intersection: Intersection.Combine
         }
      }

      WlrLayershell.namespace: "esh-orbit"
      WlrLayershell.layer: WlrLayer.Overlay
       WlrLayershell.keyboardFocus: textEntryOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      ScreenMoveRemap {
        id: remapGuard
        window: window
      }

      function clampedX(value) {
        return Math.max(8, Math.min(window.width - blobHost.width - 8, Number(value)))
      }

      function clampedY(value) {
        return Math.max(8, Math.min(window.height - blobHost.height - 8, Number(value)))
      }

       function syncPosition() {
        if (!root.service || dragArea.drag.active) return
        var point = root.service.positionFor(window.screen.name, window.width, window.height, blobHost.width)
        blobHost.x = clampedX(point.x)
        blobHost.y = clampedY(point.y)
       }

       function openTextEntry() {
         textEntryOpen = true
         textEntry.text = ""
         Qt.callLater(function() { textEntry.forceActiveFocus() })
       }

       function closeTextEntry() {
         textEntryOpen = false
         textEntry.focus = false
       }

       function submitTextEntry() {
         if (!root.service || !root.service.submitText(textEntry.text)) return
         closeTextEntry()
       }

       function escapeHtml(value) {
         return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
       }

       function formatInline(value) {
          var code = []
          var tokenized = String(value).replace(/`([^`\n]+)`/g, function(match, contents) {
            var index = code.length
            code.push(contents)
            return "\uE000" + index + "\uE001"
          })
          var html = escapeHtml(tokenized)
            .replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
            .replace(/__(.+?)__/g, "<b>$1</b>")
            .replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<i>$2</i>")
          return html.replace(/\uE000(\d+)\uE001/g, function(match, index) {
            return "<span style=\"font-family:monospace; font-size:" + Style.font.bodySmall
              + "px; background-color:" + Qt.darker(Color.popups.background, 1.35)
              + "; border:1px solid " + Color.popups.border + "; padding:1px 3px\">"
              + escapeHtml(code[Number(index)]) + "</span>"
          })
       }

       function tableCells(line) {
         var text = String(line).trim().replace(/^\|/, "").replace(/\|$/, "")
         return text.split("|").map(function(cell) { return cell.trim() })
       }

       function isTableSeparator(line) {
         return /^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$/.test(String(line))
       }

       function formatMessage(value) {
         var lines = String(value || "").split("\n")
         var alignment = speechBubble.leftAligned ? "left" : "center"
         var html = []
         var code = []
         var inCode = false
         for (var i = 0; i < lines.length; i++) {
           if (/^\s*```/.test(lines[i])) {
             if (inCode) {
               html.push("<table width=\"100%\" cellspacing=\"0\" cellpadding=\"6\" border=\"1\" bordercolor=\""
                 + Color.popups.border + "\"><tr><td bgcolor=\"" + Qt.darker(Color.popups.background, 1.35)
                 + "\"><pre style=\"margin:0; white-space:pre-wrap; font-family:monospace; font-size:"
                 + Style.font.bodySmall + "px\">" + escapeHtml(code.join("\n")) + "</pre></td></tr></table>")
               code = []
             }
             inCode = !inCode
           } else if (inCode) {
             code.push(lines[i])
           } else if (i + 1 < lines.length && lines[i].indexOf("|") >= 0
             && isTableSeparator(lines[i + 1])) {
             var header = tableCells(lines[i])
             var table = "<table width=\"100%\" cellspacing=\"0\" cellpadding=\"5\" border=\"1\" bordercolor=\""
               + Color.popups.border + "\"><tr>"
             for (var h = 0; h < header.length; h++)
               table += "<th align=\"left\" bgcolor=\"" + Qt.darker(Color.popups.background, 1.25)
                 + "\">" + formatInline(header[h]) + "</th>"
             table += "</tr>"
             i += 2
             while (i < lines.length && lines[i].indexOf("|") >= 0 && lines[i].trim() !== "") {
               var cells = tableCells(lines[i])
               table += "<tr>"
               for (var c = 0; c < cells.length; c++)
                 table += "<td align=\"left\">" + formatInline(cells[c]) + "</td>"
               table += "</tr>"
               i++
             }
             table += "</table>"
             html.push(table)
             i--
           } else if (/^\s*[-*]\s+/.test(lines[i])) {
              html.push("<div align=\"left\">&#8226;&nbsp;" + formatInline(lines[i].replace(/^\s*[-*]\s+/, "")) + "</div>")
            } else if (/^\s*#{1,6}\s+/.test(lines[i])) {
              html.push("<div align=\"" + alignment + "\"><b>" + formatInline(lines[i].replace(/^\s*#{1,6}\s+/, "")) + "</b></div>")
           } else if (lines[i].trim() === "") {
             html.push("<br>")
            } else {
              html.push("<div align=\"" + alignment + "\">" + formatInline(lines[i]) + "</div>")
           }
         }
         if (code.length > 0) html.push("<pre style=\"font-family:monospace; font-size:"
           + Style.font.bodySmall + "px\">" + escapeHtml(code.join("\n")) + "</pre>")
         return html.join("")
       }

      function globalGazeX() {
        if (!root.service || !root.service.cursorKnown) return 0
        var target = root.service.cursorX - Number(window.screen.x || 0)
        return Math.max(-1, Math.min(1, (target - (blobHost.x + blobHost.width / 2)) / Math.max(1, window.width * 0.48)))
      }

      function globalGazeY() {
        if (!root.service || !root.service.cursorKnown) return 0
        var target = root.service.cursorY - Number(window.screen.y || 0)
        return Math.max(-1, Math.min(1, (target - (blobHost.y + blobHost.height / 2)) / Math.max(1, window.height * 0.48)))
      }

      onWidthChanged: Qt.callLater(syncPosition)
      onHeightChanged: Qt.callLater(syncPosition)
      Component.onCompleted: Qt.callLater(syncPosition)

      Connections {
        target: root.service
         function onPositionsChanged() { window.syncPosition() }
         function onPositionPresetChanged() { window.syncPosition() }
         function onBlobSizeChanged() { Qt.callLater(window.syncPosition) }
         function onBuddyStateChanged() {
           if (root.service.buddyState !== "idle") window.closeTextEntry()
         }
       }

       Item {
         id: bubbleInputRegion
         visible: speechBubble.visible
        x: speechBubble.x
        y: speechBubble.y
        width: speechBubble.width
        height: speechBubble.height
      }

      BorderSurface {
        id: speechBubble
        readonly property bool asking: root.service && root.service.buddyState === "waiting"
        readonly property bool leftAligned: root.service && /-left$/.test(root.service.positionPreset)
          || blobHost.x + blobHost.width / 2 <= window.width / 2
        readonly property string message: root.service ? root.service.buddyMessage : ""
        readonly property bool wideResponse: {
          var lines = message.split("\n")
          var longest = 0
          for (var i = 0; i < lines.length; i++) longest = Math.max(longest, lines[i].length)
          return !asking && (message.length > 360 || longest > 48 || /\|[^\n]+\|/.test(message))
        }
        visible: textEntryOpen || message !== ""
        width: Math.min(window.width - Style.space(16), Style.space(asking ? 360 : (wideResponse ? 520 : 300)))
        height: bubbleContent.implicitHeight + Style.space(20)
        x: Math.max(8, Math.min(window.width - width - 8, blobHost.x + blobHost.width / 2 - width / 2))
        y: Math.max(8, Math.min(window.height - height - 8, blobHost.y > height + Style.space(16)
          ? blobHost.y - height - Style.space(10)
          : blobHost.y + blobHost.height + Style.space(10)))
        color: Color.popups.background
        borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius + Style.space(4) : 0
        opacity: visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
         Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
         Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

         TapHandler {
           enabled: !speechBubble.asking && !window.textEntryOpen
           onTapped: if (root.service) root.service.dismissReply()
         }

         Column {
          id: bubbleContent
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(8)

           Text {
             id: bubbleText
             visible: !window.textEntryOpen
             width: parent.width
             text: window.formatMessage(root.service ? root.service.buddyMessage : "")
             textFormat: Text.RichText
             color: Color.popups.text
             font.family: Style.font.family
             font.pixelSize: Style.font.bodySmall
             wrapMode: Text.WordWrap
             horizontalAlignment: speechBubble.leftAligned ? Text.AlignLeft : Text.AlignHCenter
           }

           TextField {
             id: textEntry
             visible: window.textEntryOpen
             width: parent.width
             placeholderText: "Type a message..."
             foreground: Color.popups.text
             font.family: Style.font.family
             onAccepted: window.submitTextEntry()
             Keys.onEscapePressed: window.closeTextEntry()
           }

          Repeater {
            model: speechBubble.asking && root.service ? root.service.pendingOptions : []

            Button {
              property var option: modelData
              width: bubbleContent.width
              text: option.label
              bordered: true
              focusable: true
              foreground: Color.popups.text
              fontFamily: Style.font.family
              onClicked: if (root.service) root.service.answerQuestion(option.value, option.label)
            }
          }
        }
      }

      Item {
        id: blobHost
        width: root.service ? root.service.blobSize : 132
        height: width

        property real pressedX: 0
         property real pressedY: 0
         property bool moved: false
         property bool handledOnPress: false
         property real localGazeX: 0
        property real localGazeY: 0

        Blob {
          id: blob
          anchors.fill: parent
          shapeName: root.service ? root.service.shape : "circle"
           bodyColor: root.service ? root.service.bodyColor : "#0A0A0C"
          expressionName: root.service ? root.service.expression : "neutral"
          buddyState: root.service ? root.service.buddyState : "idle"
           sleeping: root.service ? root.service.sleeping : false
           drowsy: root.service ? root.service.drowsy : false
          motionEnabled: root.service ? root.service.motionEnabled : true
          hovered: dragArea.containsMouse
          dragging: dragArea.drag.active
          followTarget: root.service ? root.service.cursorKnown : false
          gazeX: dragArea.containsMouse ? blobHost.localGazeX : window.globalGazeX()
          gazeY: dragArea.containsMouse ? blobHost.localGazeY : window.globalGazeY()
        }

        MouseArea {
          id: dragArea
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
          drag.target: blobHost
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 8
          drag.maximumX: Math.max(8, window.width - blobHost.width - 8)
          drag.minimumY: 8
          drag.maximumY: Math.max(8, window.height - blobHost.height - 8)
          drag.threshold: 4

           onPressed: function(mouse) {
             blobHost.handledOnPress = mouse.button === Qt.RightButton && root.service
               && (root.service.buddyState === "thinking" || root.service.buddyState === "listening"
                 || root.service.buddyState === "idle")
             if (blobHost.handledOnPress) {
               if (root.service.buddyState === "idle") window.openTextEntry()
               else root.service.cancelCurrent()
             }
             blobHost.pressedX = blobHost.x
            blobHost.pressedY = blobHost.y
            blobHost.moved = false
            mouse.accepted = true
          }

          onPositionChanged: function(mouse) {
            blobHost.localGazeX = (mouse.x / Math.max(1, width) - 0.5) * 2
            blobHost.localGazeY = (mouse.y / Math.max(1, height) - 0.5) * 2
            if (Math.abs(blobHost.x - blobHost.pressedX) > 4 || Math.abs(blobHost.y - blobHost.pressedY) > 4)
              blobHost.moved = true
            if (blobHost.moved && root.service) root.service.resetIdleTimer()
          }

           onReleased: function(mouse) {
             if (blobHost.handledOnPress) {
               blobHost.handledOnPress = false
               return
             }
             if (root.service)
               root.service.setPosition(window.screen.name, window.clampedX(blobHost.x), window.clampedY(blobHost.y))
             if (blobHost.moved || !root.service) return
             if (mouse.button === Qt.LeftButton) {
               root.service.wakeUp()
              blob.celebrate()
              root.service.toggleListening()
            }
          }
        }
      }
    }
  }
}
