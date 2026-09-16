import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "omarchy.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var players: mediaService ? mediaService.sourcePlayers : []
  readonly property var activePlayer: {
    for (var i = 0; i < players.length; i++) {
      var player = players[i]
      var identity = String(player.identity || player.desktopEntry || player.dbusName || "").toLowerCase()
      if (identity.indexOf("degen radio") >= 0 || identity.indexOf("degen-radio") >= 0 || identity.indexOf("degen_radio") >= 0) return player
    }
    return null
  }

  readonly property bool hasPlayer: activePlayer !== null
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string nowPlaying: title + (artist ? " — " + artist : "")
  readonly property int volumePercent: {
    if (!activePlayer) return 0
    var value = Number(activePlayer.volume)
    if (!isFinite(value)) return 0
    return Math.round(Math.max(0, Math.min(1, value)) * 100)
  }

  property bool popupOpen: false
  property var stations: []
  property string stationError: ""
  property string pendingStationUrl: ""
  readonly property int activeStationIndex: {
    for (var i = 0; i < stations.length; i++) {
      if (String(stations[i].name || "") === title) return i
    }
    return -1
  }
  readonly property bool isSavedRadio: activeStationIndex >= 0
  readonly property bool opened: popupOpen

  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { popupOpen = !popupOpen }
  function playerKey() {
    return mediaService && activePlayer ? mediaService.playerKey(activePlayer) : ""
  }
  function refreshStations() {
    if (stationListProcess.running) return
    stationListProcess.command = ["degen-radio", "radio", "list", "--json"]
    stationListProcess.running = true
  }
  function applyStations(raw) {
    try {
      var parsed = JSON.parse(String(raw || "[]"))
      if (!Array.isArray(parsed)) throw new Error("station list is not an array")
      stations = parsed
      stationError = ""
    } catch (error) {
      stations = []
      stationError = "Could not read Degen Radio stations"
      console.warn("ethereumdegen.spotatui", error)
    }
  }
  function playStation(url) {
    if (!url || stationPlayProcess.running) return
    pendingStationUrl = String(url)
    stationError = ""
    stationPlayProcess.command = ["degen-radio", "radio", "play", pendingStationUrl]
    stationPlayProcess.running = true
  }
  function cycleStation(delta) {
    if (stations.length === 0) return
    var index = activeStationIndex
    if (index < 0) index = delta > 0 ? -1 : 0
    index = (index + delta + stations.length) % stations.length
    playStation(stations[index].url)
  }
  function adjustVolume(delta) {
    if (!activePlayer) return
    var step = Number(delta)
    if (!isFinite(step)) return
    var current = Number(activePlayer.volume)
    if (!isFinite(current)) current = 0
    activePlayer.volume = Math.max(0, Math.min(1, current + step))
  }

  onPopupOpenChanged: if (popupOpen) refreshStations()

  Process {
    id: stationListProcess
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStations(text)
    }
    stderr: StdioCollector {
      id: stationListStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.stations = []
        root.stationError = "Radio controls require degen-radio"
        var detail = String(stationListStderr.text || "").trim()
        if (detail) console.warn("ethereumdegen.spotatui", detail)
      }
    }
  }

  Process {
    id: stationPlayProcess
    running: false
    command: []
    stderr: StdioCollector {
      id: stationPlayStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.pendingStationUrl = ""
      if (exitCode !== 0) {
        root.stationError = "Could not switch radio station"
        var detail = String(stationPlayStderr.text || "").trim()
        if (detail) console.warn("ethereumdegen.spotatui", detail)
      } else {
        root.refreshStations()
      }
    }
  }

  Timer {
    interval: 15000
    repeat: true
    running: root.popupOpen
    onTriggered: root.refreshStations()
  }

  visible: hasPlayer
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓇"
    foreground: root.activePlayer && root.activePlayer.isPlaying ? "#1db954" : root.bar.barForeground
    active: root.popupOpen
    tooltipText: root.nowPlaying || "Degen Radio"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        if (root.bar) root.bar.run("omarchy-launch-or-focus-tui degen-radio")
      } else if (mouseButton === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("playPause", false, root.playerKey())
      } else {
        root.popupOpen = !root.popupOpen
      }
    }

    onWheelMoved: function(delta) {
      if (root.isSavedRadio) root.cycleStation(delta > 0 ? -1 : 1)
      else if (root.mediaService) root.mediaService.runAction(delta > 0 ? "previous" : "next", false, root.playerKey())
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            textFormat: Text.PlainText
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.isSavedRadio ? root.stations.length > 1 : (root.activePlayer && root.activePlayer.canGoPrevious)
          opacity: enabled ? 1.0 : 0.4
          onClicked: {
            if (root.isSavedRadio) root.cycleStation(-1)
            else if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
          }
        }

        Button {
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.isSavedRadio ? root.stations.length > 1 : (root.activePlayer && root.activePlayer.canGoNext)
          opacity: enabled ? 1.0 : 0.4
          onClicked: {
            if (root.isSavedRadio) root.cycleStation(1)
            else if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)

        Text {
          text: "Volume"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }

        Button {
          text: "−"
          tooltipText: "Volume down"
          foreground: root.bar.foreground
          enabled: root.hasPlayer && root.volumePercent > 0
          opacity: enabled ? 1.0 : 0.4
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.space(4)
          onClicked: root.adjustVolume(-0.05)
        }

        Text {
          text: root.volumePercent + "%"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          width: Style.space(42)
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter
        }

        Button {
          text: "+"
          tooltipText: "Volume up"
          foreground: root.bar.foreground
          enabled: root.hasPlayer && root.volumePercent < 100
          opacity: enabled ? 1.0 : 0.4
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.space(4)
          onClicked: root.adjustVolume(0.05)
        }
      }
      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.16)
      }

      Text {
        text: root.isSavedRadio ? "Radio stations · LIVE" : "Radio stations"
        color: root.isSavedRadio ? "#1db954" : root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }

      ListView {
        id: stationListView
        width: parent.width
        height: visible ? Math.min(contentHeight, Style.space(180)) : 0
        visible: root.stations.length > 0
        clip: true
        spacing: Style.space(2)
        model: root.stations

        delegate: Button {
          required property var modelData
          width: stationListView.width
          text: {
            var label = String(modelData.name || modelData.url || "Unnamed station")
            return label.length > 38 ? label.slice(0, 37) + "…" : label
          }
          tooltipText: String(modelData.name || "") + "\n" + String(modelData.url || "")
          foreground: root.bar.foreground
          leftAlign: true
          focusable: true
          selected: root.title === String(modelData.name || "")
          enabled: !stationPlayProcess.running
          opacity: root.pendingStationUrl === String(modelData.url || "") ? 0.55 : 1.0
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.space(5)
          onClicked: root.playStation(modelData.url)
        }
      }

      Text {
        width: parent.width
        visible: root.stationError !== ""
        text: root.stationError
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Qt.darker(root.bar.foreground, 1.3)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        visible: root.stations.length === 0 && root.stationError === ""
        text: stationListProcess.running ? "Loading stations…" : "No saved radio stations"
        textFormat: Text.PlainText
        color: Qt.darker(root.bar.foreground, 1.3)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }


    }
  }
}
