import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "esh.orbit"
  manageIpc: false

  readonly property var blobService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property color foreground: root.barForeground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function voiceActionLabel() {
    if (!root.blobService) return "Start talking"
    if (root.blobService.buddyState === "listening") return "Stop and ask"
    if (root.blobService.buddyState === "transcribing") return "Transcribing..."
    if (root.blobService.buddyState === "thinking") return "Thinking..."
    return "Start talking"
  }

  function syncService() {
    if (root.blobService) root.blobService.applySettings(root.settings)
  }

  function setSetting(key, value) {
    if (root.blobService) root.blobService.setSetting(key, value)
  }

  onSettingsChanged: syncService()
  onBlobServiceChanged: syncService()
  Component.onCompleted: Qt.callLater(syncService)
  onOpenedChanged: if (opened) Qt.callLater(function() {
    panelFlick.contentY = 0
    keyCatcher.forceActiveFocus()
    if (root.blobService && root.blobService.modelOptions.length <= 1)
      root.blobService.refreshModels()
  })

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Orbit"
    active: root.blobService && root.blobService.buddyState !== "idle"
    iconComponent: Component {
      Blob {
        shapeName: root.blobService ? root.blobService.shape : "circle"
        bodyColor: root.blobService ? root.blobService.bodyColor : "#0A0A0C"
        expressionName: root.blobService ? root.blobService.expression : "neutral"
        buddyState: root.blobService ? root.blobService.buddyState : "idle"
        motionEnabled: false
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (root.blobService) root.blobService.setSetting("blobVisible", !root.blobService.blobVisible)
      } else if (buttonCode === Qt.MiddleButton) {
        if (root.blobService) root.blobService.cancelCurrent()
      } else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(Math.min(content.implicitHeight, Style.space(650)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: agentPicker.popupOpen || modelPicker.popupOpen || thinkingPicker.popupOpen
      onCloseRequested: root.close()

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        Column {
          id: content
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Orbit"
            meta: root.blobService ? (root.blobService.agent + " · " + root.blobService.buddyState) : "OpenCode"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Blob {
                width: Style.space(48)
                height: width
                shapeName: root.blobService ? root.blobService.shape : "circle"
                bodyColor: root.blobService ? root.blobService.bodyColor : "#0A0A0C"
                expressionName: root.blobService ? root.blobService.expression : "neutral"
                buddyState: root.blobService ? root.blobService.buddyState : "idle"
                motionEnabled: root.blobService ? root.blobService.motionEnabled : true
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                id: blobSwitch
                checked: root.blobService ? root.blobService.blobVisible : true
                foreground: hero.foreground
                onToggled: root.setSetting("blobVisible", !blobSwitch.checked)

                PanelToolTip {
                  visible: blobSwitch.containsMouse
                  text: blobSwitch.checked ? "Hide Orbit" : "Show Orbit"
                  fontFamily: hero.fontFamily
                }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              id: voiceButton
              width: parent.width - clearChatButton.width - parent.spacing
                - (cancelVoice.visible ? cancelVoice.width + parent.spacing : 0)
              text: root.voiceActionLabel()
              iconText: root.blobService && root.blobService.buddyState === "listening" ? "󰍭" : "󰍬"
              bordered: true
              focusable: true
              enabled: !root.blobService || root.blobService.buddyState !== "transcribing"
                && root.blobService.buddyState !== "thinking"
              opacity: enabled ? 1 : 0.55
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.blobService) root.blobService.toggleListening()
            }

            Button {
              id: clearChatButton
              width: height
              height: voiceButton.height
              iconText: "󰆴"
              bordered: true
              focusable: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.blobService) root.blobService.resetConversation()

              PanelToolTip {
                visible: clearChatButton.hot
                text: "Clear chat"
                fontFamily: root.fontFamily
              }
            }

            Button {
              id: cancelVoice
              visible: root.blobService && root.blobService.buddyState !== "idle"
              text: "Cancel"
              bordered: true
              focusable: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.blobService) root.blobService.cancelCurrent()
            }
          }

          BorderSurface {
            visible: root.blobService && root.blobService.buddyMessage !== ""
            width: parent.width
            height: panelMessage.implicitHeight + Style.space(20)
            color: Util.alpha(root.foreground, 0.06)
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
            radius: Style.cornerRadius

            Text {
              id: panelMessage
              anchors.fill: parent
              anchors.margins: Style.space(10)
              text: root.blobService ? root.blobService.buddyMessage : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              maximumLineCount: 5
              elide: Text.ElideRight
            }
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }
          PanelSectionHeader { text: "BRAIN"; foreground: root.foreground; fontFamily: root.fontFamily }

          SearchableDropdown {
            id: agentPicker
            width: parent.width
            label: "AI agent"
            value: root.blobService ? root.blobService.agent : "opencode"
            options: root.blobService ? root.blobService.agentOptions : []
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function(next) { root.setSetting("agent", next) }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            SearchableDropdown {
              id: modelPicker
              width: parent.width - refreshModelsButton.width - parent.spacing
              label: "Model"
              value: root.blobService ? root.blobService.model : ""
              options: root.blobService ? root.blobService.modelOptions : []
              placeholderText: root.blobService && root.blobService.modelsLoading ? "Finding models..." : "Agent default"
              emptyText: root.blobService && root.blobService.modelsLoading ? "Finding models..." : "No models reported"
              enabled: !root.blobService || !root.blobService.modelsLoading
              opacity: enabled ? 1 : 0.62
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(next) { root.setSetting("model", next) }
            }

            Button {
              id: refreshModelsButton
              height: modelPicker.rowHeight
              width: height
              anchors.bottom: modelPicker.bottom
              iconText: "󰑐"
              bordered: true
              focusable: true
              enabled: !root.blobService || !root.blobService.modelsLoading
              opacity: enabled ? 1 : 0.62
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.blobService) root.blobService.refreshModels()
            }
          }

          Dropdown {
            id: thinkingPicker
            width: parent.width
            label: "Thinking level"
            value: root.blobService ? root.blobService.thinkingLevel : ""
            options: root.blobService ? root.blobService.thinkingOptions : []
            enabled: !root.blobService || root.blobService.thinkingOptions.length > 1
            opacity: enabled ? 1 : 0.62
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function(next) { root.setSetting("thinkingLevel", next) }
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }
          PanelSectionHeader { text: "PERSONALITY"; foreground: root.foreground; fontFamily: root.fontFamily }

          Row {
            width: parent.width

            Text {
              width: parent.width - sizeValue.width
              text: "SIZE"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Text {
              id: sizeValue
              text: (root.blobService ? root.blobService.blobSize : 132) + " px"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.features: { "tnum": 1 }
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 88
            maximum: 220
            step: 4
            integer: true
            value: root.blobService ? root.blobService.blobSize : 132
            onReleased: function(next) { root.setSetting("blobSize", next) }
          }

          Text {
            text: "POSITION"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Grid {
            id: positionGrid
            width: parent.width
            height: Style.space(38) * 3 + rowSpacing * 2
            columns: 3
            columnSpacing: Style.space(6)
            rowSpacing: Style.space(6)

            Repeater {
              model: root.blobService ? root.blobService.positionOptions.slice(0, 9) : []

              BorderSurface {
                id: positionCell
                required property var modelData
                readonly property bool selected: root.blobService
                  && root.blobService.positionPreset === modelData.value
                width: (positionGrid.width - positionGrid.columnSpacing * 2) / 3
                height: Style.space(38)
                color: selected ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
                borderSpec: Border.controlSpec(selected ? "selected" : "normal", root.foreground, Color.accent)
                radius: Style.cornerRadius

                Text {
                  anchors.centerIn: parent
                  text: positionCell.modelData.label
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (root.blobService)
                    root.blobService.setPositionPreset(positionCell.modelData.value)
                }
              }
            }
          }

        }
      }
    }
  }
}
