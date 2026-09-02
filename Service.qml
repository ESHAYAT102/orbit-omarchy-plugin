import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  visible: false

  readonly property string pluginId: "esh.orbit"
  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  readonly property string opencodeRunner: homeDir + "/.config/omarchy/plugins/" + pluginId + "/run-opencode.sh"
  readonly property string transcriptPath: runtimeDir + "/esh-orbit-transcript.txt"
  readonly property string workDir: homeDir + "/Work"
  property var shell: null
  property var manifest: null

  property string agent: "opencode"
  property string model: ""
  property string thinkingLevel: ""
  property var modelOptions: [{ value: "", label: "Agent default", description: "Use the agent's configured default" }]
  property bool modelsLoading: false
  property string modelStatus: ""
  property string modelOutput: ""
  property string modelError: ""
  property string modelRequestAgent: ""
  property string shape: "circle"
  readonly property string bodyColor: "#0A0A0C"
  property string expression: "neutral"
  property int blobSize: 132
  property bool motionEnabled: true
  property bool blobVisible: true
  property bool sleeping: false
  property bool drowsy: false
  property real lastInteractionTime: Date.now()
  property var positions: ({})
  property string positionPreset: "bottom-left"

  property string buddyState: "idle"
  property string lastHeard: ""
  property string lastReply: ""
  property string lastError: ""
  property bool replyVisible: false
  property var conversation: []
  property bool cancelRequested: false
  property string transcriptionOutput: ""
  property string transcriptionError: ""
  property string agentOutput: ""
  property string agentError: ""
  property string runningAgent: ""
  property int thinkingSeconds: 0
  property string agentSessionId: ""
  property bool capturingScreen: false
  property bool hideOverlayForCapture: false
  property string screenCaptureOutput: ""
  property string screenCaptureError: ""
  property string pendingScreenRequest: ""
  property string activeScreenshot: ""
  property string pendingQuestion: ""
  property var pendingOptions: []
  property real cursorX: 0
  property real cursorY: 0
  property bool cursorKnown: false

  readonly property string buddyMessage: {
    if (buddyState === "waiting") return pendingQuestion
    if (buddyState === "error") return lastError
    if (buddyState === "thinking") {
      if (capturingScreen) return "Capturing your screen..."
      var name = agentDisplayName(runningAgent || agent)
      if (thinkingSeconds < 2) return "Preparing request for " + name + "..."
      if (thinkingSeconds < 8) return name + " is analyzing your request..."
      if (thinkingSeconds < 20) return name + " is working on it..."
      return name + " is still working... " + thinkingSeconds + "s"
    }
    if (replyVisible) return lastReply
    return ""
  }

  readonly property var agentOptions: [
    { value: "agy", label: "Antigravity", description: "Google's agent harness" },
    { value: "claude", label: "Claude Code", description: "Anthropic's coding agent" },
    { value: "codex", label: "Codex CLI", description: "OpenAI's coding agent" },
    { value: "copilot", label: "GitHub Copilot", description: "GitHub's terminal agent" },
    { value: "crush", label: "Crush", description: "Charm's coding agent" },
    { value: "grok", label: "Grok", description: "xAI's coding agent" },
    { value: "hermes", label: "Hermes", description: "Nous Research's agent" },
    { value: "omp", label: "omp", description: "Terminal coding agent" },
    { value: "opencode", label: "OpenCode", description: "Open source coding agent" },
    { value: "ori", label: "Ori", description: "OpenRouter's agent harness" },
    { value: "pi", label: "Pi", description: "Minimal terminal coding agent" }
  ]
  readonly property var thinkingOptions: thinkingOptionsFor(agent, model)
  readonly property var shapeOptions: [
    { value: "circle", label: "Circle" },
    { value: "pebble", label: "Pebble" },
    { value: "squircle", label: "Squircle" },
    { value: "capsule", label: "Capsule" },
    { value: "triangle", label: "Triangle" },
    { value: "hexagon", label: "Hexagon" },
    { value: "cloud", label: "Cloud" },
    { value: "droplet", label: "Droplet" }
  ]
  readonly property var expressionOptions: [
    { value: "neutral", label: "Neutral" },
    { value: "attentive", label: "Attentive" },
    { value: "surprised", label: "Surprised" },
    { value: "excited", label: "Excited" },
    { value: "happy", label: "Happy" },
    { value: "laughing", label: "Laughing" },
    { value: "angry", label: "Angry" },
    { value: "sad", label: "Sad" },
    { value: "scared", label: "Scared" },
    { value: "suspicious", label: "Suspicious" },
    { value: "confused", label: "Confused" },
    { value: "curious", label: "Curious" },
    { value: "proud", label: "Proud" },
    { value: "shy", label: "Shy" },
    { value: "unimpressed", label: "Unimpressed" },
    { value: "sleepy", label: "Sleepy" }
  ]
  readonly property var positionOptions: [
    { value: "top-left", label: "Top Left" },
    { value: "top-center", label: "Top Center" },
    { value: "top-right", label: "Top Right" },
    { value: "middle-left", label: "Middle Left" },
    { value: "middle-center", label: "Middle Center" },
    { value: "middle-right", label: "Middle Right" },
    { value: "bottom-left", label: "Bottom Left" },
    { value: "bottom-center", label: "Bottom Center" },
    { value: "bottom-right", label: "Bottom Right" },
    { value: "custom", label: "Custom" }
  ]

  function hasOption(options, value) {
    for (var i = 0; i < options.length; i++)
      if (options[i].value === value) return true
    return false
  }

  function agentDisplayName(value) {
    for (var i = 0; i < root.agentOptions.length; i++)
      if (root.agentOptions[i].value === value) return root.agentOptions[i].label
    return "The agent"
  }

  function currentSettings() {
    return {
      agent: root.agent,
      model: root.model,
      thinkingLevel: root.thinkingLevel,
      blobSize: root.blobSize,
      blobVisible: root.blobVisible,
      positionPreset: root.positionPreset,
      positions: root.positions,
      conversation: root.conversation,
      pendingQuestion: root.pendingQuestion,
      pendingOptions: root.pendingOptions
    }
  }

  function applySettings(values) {
    var next = values || {}
    var nextAgent = String(next.agent || "opencode")
    var nextExpression = String(next.expression || "neutral")
    root.agent = hasOption(root.agentOptions, nextAgent) ? nextAgent : "opencode"
    root.model = String(next.model || "")
    var nextThinking = String(next.thinkingLevel || "")
    root.thinkingLevel = hasOption(root.thinkingOptions, nextThinking) ? nextThinking : ""
    root.blobSize = Math.max(88, Math.min(220, Math.round(Number(next.blobSize || 132))))
    root.blobVisible = next.blobVisible === undefined ? true : next.blobVisible === true
    var hasSavedPositions = next.positions && typeof next.positions === "object" && Object.keys(next.positions).length > 0
    var nextPosition = String(next.positionPreset || (hasSavedPositions ? "custom" : "bottom-left"))
    root.positionPreset = hasOption(root.positionOptions, nextPosition) ? nextPosition : "bottom-left"
    root.positions = next.positions && typeof next.positions === "object" ? next.positions : ({})
    root.conversation = Array.isArray(next.conversation) ? next.conversation : []
    root.pendingQuestion = String(next.pendingQuestion || "")
    root.pendingOptions = Array.isArray(next.pendingOptions) ? next.pendingOptions : []
    if (root.pendingQuestion !== "" && root.pendingOptions.length >= 2)
      root.buddyState = "waiting"
  }

  function configuredSettings() {
    if (!root.shell || !root.shell.shellConfig) return null
    var config = root.shell.shellConfig
    var layout = config.bar && config.bar.layout ? config.bar.layout : ({})
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
      for (var i = 0; i < entries.length; i++)
        if (entries[i] && String(entries[i].id) === root.pluginId) return entries[i]
    }
    var plugins = Array.isArray(config.plugins) ? config.plugins : []
    for (var p = 0; p < plugins.length; p++)
      if (plugins[p] && String(plugins[p].id) === root.pluginId) return plugins[p]
    return null
  }

  function hydrateFromShell() {
    var configured = configuredSettings()
    if (configured) applySettings(configured)
  }

  onShellChanged: hydrateFromShell()

  Connections {
    target: root.shell
    function onShellConfigChanged() { root.hydrateFromShell() }
  }

  function persist() {
    if (root.shell && typeof root.shell.updateEntryInline === "function")
      root.shell.updateEntryInline(root.pluginId, currentSettings())
  }

  function setSetting(key, value) {
    if (key === "agent" && hasOption(root.agentOptions, String(value))) {
      root.agent = String(value)
      root.model = ""
      root.modelOptions = fallbackModelOptions(root.agent)
      if (!hasOption(root.thinkingOptions, root.thinkingLevel)) root.thinkingLevel = ""
    }
    else if (key === "model" && hasOption(root.modelOptions, String(value))) root.model = String(value)
    else if (key === "thinkingLevel" && hasOption(root.thinkingOptions, String(value))) root.thinkingLevel = String(value)
    else if (key === "blobSize") root.blobSize = Math.max(88, Math.min(220, Math.round(Number(value))))
    else if (key === "blobVisible") root.blobVisible = value === true
    else return
    persist()
  }

  onModelChanged: {
    if (!hasOption(root.thinkingOptions, root.thinkingLevel)) root.thinkingLevel = ""
    root.agentSessionId = ""
  }

  onAgentChanged: {
    root.agentSessionId = ""
    modelRefreshTimer.restart()
  }

  function fallbackModelOptions(agentName) {
    var options = [{ value: "", label: "Agent default", description: "Use the agent's configured default" }]
    if (agentName === "claude") {
      options.push({ value: "sonnet", label: "Sonnet", description: "Latest Claude Sonnet" })
      options.push({ value: "opus", label: "Opus", description: "Latest Claude Opus" })
      options.push({ value: "haiku", label: "Haiku", description: "Latest Claude Haiku" })
      options.push({ value: "fable", label: "Fable", description: "Latest Claude Fable" })
    } else if (agentName === "copilot") {
      options.push({ value: "auto", label: "Auto", description: "Let Copilot choose the model" })
    }
    return options
  }

  function thinkingOptionsFor(agentName, modelName) {
    var options = [{ value: "", label: "Agent default" }]
    function add(value, label) { options.push({ value: value, label: label }) }
    if (agentName === "crush" || agentName === "hermes")
      return [{ value: "", label: "Agent default (fixed)" }]
    if (agentName === "agy") {
      add("low", "Low"); add("medium", "Medium"); add("high", "High")
      return options
    }
    if (agentName === "claude") {
      add("low", "Low"); add("medium", "Medium"); add("high", "High")
      add("xhigh", "Extra high"); add("max", "Maximum")
      return options
    }
    if (agentName === "opencode") {
      add("none", "No thinking"); add("low", "Low"); add("medium", "Medium")
      add("high", "High"); add("xhigh", "Extra high")
      if (String(modelName).indexOf("5.6") >= 0) add("max", "Maximum")
      return options
    }
    if (agentName === "omp") {
      add("none", "No thinking"); add("minimal", "Minimal"); add("low", "Low")
      add("medium", "Medium"); add("high", "High"); add("xhigh", "Extra high")
      add("max", "Maximum"); add("auto", "Automatic")
      return options
    }
    add("none", "No thinking"); add("minimal", "Minimal"); add("low", "Low")
    add("medium", "Medium"); add("high", "High"); add("xhigh", "Extra high")
    add("max", "Maximum")
    return options
  }

  function modelListCommand(agentName) {
    if (agentName === "agy") return ["agy", "models"]
    if (agentName === "codex")
      return ["jq", "-r", ".models[] | [.slug, .display_name] | @tsv", root.homeDir + "/.codex/models_cache.json"]
    if (agentName === "crush") return ["crush", "models"]
    if (agentName === "grok") return ["grok", "models"]
    if (agentName === "omp") return ["omp", "models", "--json"]
    if (agentName === "opencode") return ["opencode", "models"]
    if (agentName === "ori") return ["ori", "omp", "models", "--json"]
    if (agentName === "pi") return ["pi", "--list-models"]
    return []
  }

  function refreshModels() {
    if (modelProc.running) {
      modelProc.running = false
      modelRefreshTimer.restart()
      return
    }
    root.modelOptions = fallbackModelOptions(root.agent)
    root.modelOutput = ""
    root.modelError = ""
    root.modelRequestAgent = root.agent
    var command = modelListCommand(root.agent)
    if (command.length === 0) {
      root.modelsLoading = false
      root.modelStatus = root.agent === "claude"
        ? "Aliases provided by Claude Code"
        : "This agent does not expose model discovery"
      if (!hasOption(root.modelOptions, root.model)) root.model = ""
      return
    }
    root.modelsLoading = true
    root.modelStatus = "Finding available models..."
    modelProc.command = loginCommand(command)
    modelProc.running = true
  }

  function finishModelDiscovery(exitCode) {
    if (root.modelRequestAgent !== root.agent) return
    root.modelsLoading = false
    var options = fallbackModelOptions(root.agent)
    if (exitCode === 0) {
      var clean = cleanText(root.modelOutput)
      try {
        var data = JSON.parse(clean)
        var models = data && Array.isArray(data.models) ? data.models : []
        for (var j = 0; j < models.length; j++) {
          var selector = String(models[j].selector || models[j].id || "").trim()
          var name = String(models[j].name || models[j].display_name || selector).trim()
          if (selector !== "") options.push({ value: selector, label: name, description: selector })
        }
      } catch (error) {
        var lines = clean.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].replace(/^\s*[-*]\s*/, "").replace(/\s+\(default\)\s*$/, "").trim()
          if (line === "" || line.indexOf("Fetching available models") === 0
              || line.indexOf("Available models") === 0 || line.indexOf("Default model") === 0
              || line.indexOf("No models available") === 0 || line.indexOf("Use /login") === 0)
            continue
          var fields = line.split("\t")
          var value = String(fields[0] || "").trim()
          var label = String(fields.length > 1 ? fields[1] : value).trim()
          if (/^[A-Za-z0-9_.:/-]+$/.test(value))
            options.push({ value: value, label: label, description: fields.length > 1 ? value : "" })
        }
      }
    }
    var seen = ({ "": true })
    var unique = [options[0]]
    for (var k = 1; k < options.length; k++) {
      if (!seen[options[k].value]) {
        seen[options[k].value] = true
        unique.push(options[k])
      }
    }
    root.modelOptions = unique
    root.modelStatus = unique.length > 1
      ? (unique.length - 1) + " available model" + (unique.length === 2 ? "" : "s")
      : shortError(root.modelError, "No models reported; using the agent default")
    if (!hasOption(unique, root.model)) {
      root.model = ""
      persist()
    }
  }

  function positionFor(screenName, screenWidth, screenHeight, size) {
    var saved = root.positions ? root.positions[String(screenName)] : null
    if (root.positionPreset === "custom" && saved && isFinite(Number(saved.x)) && isFinite(Number(saved.y)))
      return { x: Number(saved.x), y: Number(saved.y) }
    var parts = root.positionPreset.split("-")
    var vertical = parts[0] || "bottom"
    var horizontal = parts[1] || "left"
    var width = Number(screenWidth)
    var height = Number(screenHeight)
    var blob = Number(size)
    var x = horizontal === "center" ? (width - blob) / 2 : horizontal === "right" ? width - blob - 8 : 8
    var y = vertical === "middle" ? (height - blob) / 2 : vertical === "bottom" ? height - blob - 8 : 8
    return { x: x, y: y }
  }

  function setPosition(screenName, x, y) {
    var next = ({})
    for (var key in root.positions) next[key] = root.positions[key]
    next[String(screenName)] = { x: Math.round(Number(x)), y: Math.round(Number(y)) }
    root.positions = next
    root.positionPreset = "custom"
    persist()
  }

  function setPositionPreset(preset) {
    if (!hasOption(root.positionOptions, preset) || preset === "custom") return
    root.positionPreset = preset
    root.positions = ({})
    persist()
  }

  function resetConversation() {
    cancelCurrent()
    root.conversation = []
    root.lastHeard = ""
    root.lastReply = ""
    root.replyVisible = false
    root.agentSessionId = ""
    clearQuestion()
    persist()
  }

  function loginCommand(args) {
    return ["bash", "-lc", "exec \"$@\"", "bash"].concat(args)
  }

  function cleanText(raw) {
    return String(raw || "")
      .replace(/\u001b\[[0-9;?]*[ -/]*[@-~]/g, "")
      .replace(/^[\s\n]+|[\s\n]+$/g, "")
  }

  function shortError(raw, fallback) {
    var text = cleanText(raw)
    if (text === "") return fallback
    var lines = text.split("\n")
    return lines[Math.max(0, lines.length - 1)].slice(0, 240)
  }

  function requestsScreenContext(request) {
    var text = String(request || "").toLowerCase()
    if (/\b(screen\s*shot|screenshot)\b/.test(text)) return true
    return /\b(look|see|check|inspect|view|analy[sz]e|read|show|tell|what)\b/.test(text)
      && /\b(screen|desktop|display|monitor)\b/.test(text)
  }

  function discardScreenshot() {
    var path = root.activeScreenshot
    root.activeScreenshot = ""
    if (path.indexOf(root.runtimeDir + "/screenshot-") === 0)
      Util.execArgv(["rm", "-f", "--", path])
  }

  function captureScreen(request) {
    discardScreenshot()
    root.capturingScreen = true
    root.hideOverlayForCapture = true
    root.pendingScreenRequest = request
    root.screenCaptureOutput = ""
    root.screenCaptureError = ""
    screenCaptureDelay.restart()
  }

  function beginScreenCapture() {
    if (!root.capturingScreen || root.pendingScreenRequest === "") return
    screenCaptureProc.command = loginCommand([
      "env", "OMARCHY_SCREENSHOT_DIR=" + root.runtimeDir,
      "omarchy", "capture", "screenshot", "fullscreen", "save"
    ])
    screenCaptureProc.running = true
    screenCaptureLimit.restart()
  }

  function finishScreenCapture(exitCode) {
    screenCaptureLimit.stop()
    root.capturingScreen = false
    root.hideOverlayForCapture = false
    if (root.cancelRequested || root.pendingScreenRequest === "") return
    var lines = cleanText(root.screenCaptureOutput).split("\n")
    var path = ""
    for (var i = lines.length - 1; i >= 0; i--) {
      var candidate = lines[i].trim()
      if (candidate.indexOf(root.runtimeDir + "/screenshot-") === 0 && /\.png$/i.test(candidate)) {
        path = candidate
        break
      }
    }
    if (exitCode !== 0 || path === "") {
      root.pendingScreenRequest = ""
      root.lastError = shortError(root.screenCaptureError, "I couldn't capture your screen.")
      root.buddyState = "error"
      return
    }
    var request = root.pendingScreenRequest
    root.pendingScreenRequest = ""
    root.activeScreenshot = path
    launchAgent(request, path)
  }

  function agentReply(raw) {
    return cleanText(raw)
  }

  function rememberAgentSession(raw) {
    if (root.runningAgent !== "opencode" || root.agentSessionId !== "") return
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      try {
        var event = JSON.parse(lines[i])
        if (event.sessionID) {
          root.agentSessionId = String(event.sessionID)
          return
        }
      } catch (error) {}
    }
  }

  function questionFromReply(reply) {
    var text = String(reply || "")
    var marker = text.indexOf("ORBIT_QUESTION:")
    if (marker < 0) return null
    var payload = text.slice(marker + 15)
    var firstBrace = payload.indexOf("{")
    var lastBrace = payload.lastIndexOf("}")
    if (firstBrace < 0 || lastBrace <= firstBrace) return null
    try {
      var parsed = JSON.parse(payload.slice(firstBrace, lastBrace + 1))
      var question = String(parsed.question || "").trim().slice(0, 280)
      var sourceOptions = Array.isArray(parsed.options) ? parsed.options : []
      var options = []
      for (var i = 0; i < sourceOptions.length && options.length < 5; i++) {
        var source = sourceOptions[i]
        var label = typeof source === "string" ? source : String(source.label || "")
        var value = typeof source === "string" ? source : String(source.value || source.label || "")
        label = label.trim().slice(0, 52)
        value = value.trim().slice(0, 240)
        if (label !== "" && value !== "") options.push({ label: label, value: value })
      }
      if (question === "" || options.length < 2) return null
      return { question: question, options: options }
    } catch (error) {
      return null
    }
  }

  function clearQuestion() {
    root.pendingQuestion = ""
    root.pendingOptions = []
  }

  function appendTurn(userText, replyText) {
    var next = root.conversation.slice()
    next.push({ user: String(userText), reply: String(replyText) })
    root.conversation = next
    persist()
  }

  function answerQuestion(value, label) {
    if (root.buddyState !== "waiting" || root.pendingQuestion === "") return
    var question = root.pendingQuestion
    var answer = String(value || label || "").trim()
    root.lastHeard = String(label || answer)
    clearQuestion()
    root.replyVisible = false
    persist()
    runAgent("Answer to your question, '" + question + "': " + answer)
  }

  function showReply() {
    root.buddyState = "idle"
    root.replyVisible = root.lastReply !== ""
    resetIdleTimer()
  }

  function dismissReply() {
    root.replyVisible = false
  }

  function wakeUp() {
    root.sleeping = false
    root.drowsy = true
    root.lastInteractionTime = Date.now()
    sleepTimer.stop()
    wakeExpressionTimer.restart()
  }

  function resetIdleTimer(clearDrowsy) {
    root.lastInteractionTime = Date.now()
    root.sleeping = false
    if (clearDrowsy !== false) {
      root.drowsy = false
      wakeExpressionTimer.stop()
    }
    idleTimer.restart()
    sleepTimer.restart()
  }

  function startListening() {
    if (root.buddyState === "thinking" || root.buddyState === "transcribing") return
    root.sleeping = false
    resetIdleTimer(false)
    var wasWaiting = root.buddyState === "waiting"
    root.cancelRequested = false
    root.lastError = ""
    root.lastHeard = ""
    root.lastReply = ""
    root.replyVisible = false
    clearQuestion()
    root.buddyState = "listening"
    if (wasWaiting) persist()
    recordProc.command = loginCommand([
      "bash", "-c",
      "rm -f \"$1\"; exec voxtype record start --file=\"$1\"",
      "bash", root.transcriptPath
    ])
    recordProc.running = true
    listeningLimit.restart()
  }

  function stopListening() {
    if (root.buddyState !== "listening") return
    listeningLimit.stop()
    root.buddyState = "transcribing"
    beginTranscription()
  }

  function toggleListening() {
    if (root.buddyState === "listening") stopListening()
    else if (root.buddyState === "idle" || root.buddyState === "error" || root.buddyState === "waiting") startListening()
  }

  function submitText(request) {
    var text = String(request || "").trim()
    if (text === "" || root.buddyState !== "idle") return false
    root.cancelRequested = false
    root.lastError = ""
    root.lastHeard = text
    root.lastReply = ""
    root.replyVisible = false
    clearQuestion()
    resetIdleTimer()
    runAgent(text)
    return true
  }

  function cancelCurrent() {
    var hadQuestion = root.pendingQuestion !== ""
    root.cancelRequested = true
    listeningLimit.stop()
    agentFinishTimer.stop()
    transcribeFinishTimer.stop()
    screenCaptureFinishTimer.stop()
    screenCaptureDelay.stop()
    screenCaptureLimit.stop()
    if (recordProc.running) recordProc.running = false
    if (transcribeProc.running) transcribeProc.running = false
    if (root.buddyState === "listening" || root.buddyState === "transcribing") {
      Util.execArgv(loginCommand([
        "bash", "-c", "voxtype record cancel; rm -f \"$1\"", "bash", root.transcriptPath
      ]))
    }
    if (screenCaptureProc.running) screenCaptureProc.running = false
    if (agentProc.running) agentProc.running = false
    root.buddyState = "idle"
    root.capturingScreen = false
    root.hideOverlayForCapture = false
    root.pendingScreenRequest = ""
    root.lastError = ""
    discardScreenshot()
    clearQuestion()
    resetIdleTimer()
    if (hadQuestion) persist()
  }

  function beginTranscription() {
    if (root.cancelRequested || root.buddyState !== "transcribing") return
    root.transcriptionOutput = ""
    root.transcriptionError = ""
    transcribeProc.command = loginCommand([
      "bash", "-c",
      "voxtype record stop || exit $?; for ((i = 0; i < 600; i++)); do if [[ $(voxtype status) == idle ]]; then if [[ -f \"$1\" ]]; then cat \"$1\"; rm -f \"$1\"; fi; exit 0; fi; sleep 0.1; done; exit 124",
      "bash", root.transcriptPath
    ])
    transcribeProc.running = true
  }

  function finishTranscription(exitCode) {
    if (root.cancelRequested) return
    var transcript = cleanText(root.transcriptionOutput).trim()
    if (exitCode !== 0 || transcript === "") {
      root.lastError = shortError(root.transcriptionError, "I couldn't hear that. Check Voxtype, then try again.")
      root.buddyState = "error"
      return
    }
    root.lastHeard = transcript
    runAgent(transcript)
  }

  function agentCommand(prompt, screenshotPath) {
    var selected = root.model === "" ? [] : ["--model", root.model]
    var thinking = root.thinkingLevel
    var effort = thinking === "" ? [] : ["--effort", thinking]
    var piThinking = thinking === "none" ? "off" : thinking
    var hasScreenshot = screenshotPath !== ""
    if (root.agent === "agy") return ["agy", "--dangerously-skip-permissions"].concat(hasScreenshot ? ["--add-dir", root.runtimeDir] : [], selected, effort, ["--print", prompt])
    if (root.agent === "claude") return ["claude", "--dangerously-skip-permissions"].concat(hasScreenshot ? ["--add-dir", root.runtimeDir] : [], selected, effort, ["--print", "--output-format", "text", "--no-session-persistence", "--", prompt])
    if (root.agent === "codex") return ["codex", "exec", "--dangerously-bypass-approvals-and-sandbox", "--ephemeral", "--color", "never", "--skip-git-repo-check"].concat(selected, thinking === "" ? [] : ["-c", "model_reasoning_effort=\"" + thinking + "\""], hasScreenshot ? ["--image", screenshotPath, "--", prompt] : [prompt])
    if (root.agent === "copilot") return ["copilot", "--allow-all", "--silent", "--no-color"].concat(selected, effort, hasScreenshot ? ["--attachment", screenshotPath] : [], ["--prompt", prompt])
    if (root.agent === "crush") return ["crush", "--yolo", "run"].concat(selected, [prompt])
    if (root.agent === "grok") return ["grok", "--permission-mode", "bypassPermissions", "--output-format", "plain"].concat(selected, thinking === "" ? [] : ["--reasoning-effort", thinking], ["--single", prompt])
    if (root.agent === "hermes") return ["hermes", "--yolo"].concat(selected, ["--oneshot", prompt])
    if (root.agent === "omp") return ["omp", "--print", "--auto-approve", "--no-session"].concat(selected, thinking === "" ? [] : ["--thinking", piThinking], hasScreenshot ? ["@" + screenshotPath] : [], [prompt])
    if (root.agent === "ori") return ["ori", "omp"].concat(thinking === "" ? [] : ["--reasoning-effort", thinking], ["--print", "--auto-approve", "--no-session"], selected, hasScreenshot ? ["@" + screenshotPath] : [], [prompt])
    if (root.agent === "pi") return ["pi", "--print", "--no-session"].concat(selected, thinking === "" ? [] : ["--thinking", piThinking], hasScreenshot ? ["@" + screenshotPath] : [], [prompt])
    return [root.opencodeRunner, prompt, root.model, thinking, screenshotPath]
  }

  function orbitPrompt(request) {
    var history = root.conversation.slice(-20)
    if (history.length === 0) return String(request)
    var lines = [
      "Continue this conversation naturally. Use the history when it is relevant, and do not claim you cannot remember it.",
      "",
      "Conversation history:"
    ]
    for (var i = 0; i < history.length; i++) {
      lines.push("User: " + String(history[i].user || ""))
      lines.push("Assistant: " + String(history[i].reply || ""))
    }
    lines.push("")
    lines.push("Current user message: " + String(request))
    return lines.join("\n")
  }

  function launchAgent(request, screenshotPath) {
    root.buddyState = "thinking"
    root.runningAgent = root.agent
    root.thinkingSeconds = 0
    root.agentOutput = ""
    root.agentError = ""
    var prompt = orbitPrompt(request)
    if (screenshotPath !== "")
      prompt += "\n\nA screenshot captured immediately before this request is attached at "
        + screenshotPath + ". Inspect the image itself before answering; do not take another screenshot."
    var command = agentCommand(prompt, screenshotPath)
    agentProc.command = root.agent === "opencode" ? command : loginCommand(command)
    agentProc.running = true
  }

  function runAgent(request) {
    root.buddyState = "thinking"
    root.runningAgent = root.agent
    root.thinkingSeconds = 0
    if (requestsScreenContext(request)) captureScreen(request)
    else launchAgent(request, "")
  }

  function finishAgent(exitCode) {
    if (root.cancelRequested) return
    var reply = agentReply(root.agentOutput)
    discardScreenshot()
    if (exitCode !== 0 || reply === "") {
      root.lastError = shortError(root.agentError, "The selected agent couldn't answer. Check its login and try again.")
      root.buddyState = "error"
      return
    }
    root.lastReply = reply
    var question = questionFromReply(reply)
    if (question) {
      root.pendingQuestion = question.question
      root.pendingOptions = question.options
      appendTurn(root.lastHeard, "Question: " + question.question + " Options: " + question.options.map(function(option) { return option.label }).join(", "))
      root.buddyState = "waiting"
      root.replyVisible = false
      return
    }
    appendTurn(root.lastHeard, reply)
    root.showReply()
  }

  function configureDictation() {
    Util.execArgv(["omarchy-voxtype-config"])
  }

  Component.onCompleted: modelRefreshTimer.restart()

  Timer {
    id: modelRefreshTimer
    interval: 180
    onTriggered: root.refreshModels()
  }

  Timer {
    id: listeningLimit
    interval: 20000
    onTriggered: root.stopListening()
  }

  Timer {
    id: transcribeFinishTimer
    interval: 80
    property int exitCode: 0
    onTriggered: root.finishTranscription(exitCode)
  }

  Timer {
    id: screenCaptureDelay
    interval: 250
    onTriggered: root.beginScreenCapture()
  }

  Timer {
    id: screenCaptureFinishTimer
    interval: 80
    property int exitCode: 0
    onTriggered: root.finishScreenCapture(exitCode)
  }

  Timer {
    id: screenCaptureLimit
    interval: 10000
    onTriggered: {
      root.pendingScreenRequest = ""
      root.capturingScreen = false
      root.hideOverlayForCapture = false
      if (screenCaptureProc.running) screenCaptureProc.running = false
      root.lastError = "Screen capture timed out."
      root.buddyState = "error"
    }
  }

  Timer {
    id: agentFinishTimer
    interval: 100
    property int exitCode: 0
    onTriggered: root.finishAgent(exitCode)
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.buddyState === "thinking"
    onTriggered: root.thinkingSeconds++
  }

  Timer {
    id: idleTimer
    interval: 30000
    repeat: false
    running: true
    onTriggered: {
      if (root.buddyState === "idle") root.drowsy = true
    }
  }

  Timer {
    id: wakeExpressionTimer
    interval: 10000
    repeat: false
    onTriggered: root.drowsy = false
  }

  Timer {
    id: sleepTimer
    interval: 60000
    repeat: false
    running: true
    onTriggered: {
      if (root.buddyState === "idle") {
        root.sleeping = true
        root.buddyState = "idle"
      }
    }
  }

  Timer {
    interval: 650
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!cursorProc.running) cursorProc.running = true
  }

  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var point = JSON.parse(text)
          root.cursorX = Number(point.x)
          root.cursorY = Number(point.y)
          root.cursorKnown = isFinite(root.cursorX) && isFinite(root.cursorY)
        } catch (error) {}
      }
    }
  }

  Process {
    id: modelProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.modelOutput = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.modelError = String(text || "")
    }
    onExited: function(exitCode) { root.finishModelDiscovery(exitCode) }
  }

  Process {
    id: screenCaptureProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.screenCaptureOutput = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.screenCaptureError = String(text || "")
    }
    onExited: function(exitCode) {
      screenCaptureFinishTimer.exitCode = exitCode
      screenCaptureFinishTimer.restart()
    }
  }

  Process {
    id: recordProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.transcriptionError = String(text || "")
    }
    onExited: function(exitCode) {
      if (root.cancelRequested) return
      if (root.buddyState === "listening" && exitCode !== 0) {
        root.lastError = root.shortError(root.transcriptionError, "The microphone couldn't start.")
        root.buddyState = "error"
      }
    }
  }

  Process {
    id: transcribeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.transcriptionOutput = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.transcriptionError = String(text || "")
    }
    onExited: function(exitCode) {
      transcribeFinishTimer.exitCode = exitCode
      transcribeFinishTimer.restart()
    }
  }

  Process {
    id: agentProc
    workingDirectory: root.workDir
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.agentOutput = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.agentError = String(text || "")
    }
    onExited: function(exitCode) {
      agentFinishTimer.exitCode = exitCode
      agentFinishTimer.restart()
    }
  }

}
