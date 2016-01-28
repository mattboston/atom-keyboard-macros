AtomKeyboardMacrosView = require './atom-keyboard-macros-view'
{CompositeDisposable} = require 'atom'
{normalizeKeystrokes, keystrokeForKeyboardEvent, isAtomModifier, keydownEvent, characterForKeyboardEvent} = require './helpers'
{InputTextCommand, KeydownCommand, DispatchCommand} = require './macro-command'

module.exports =
class Compiler
  result = []
  seq = []
  isTextMode = true
  hasNextStroke = false
  keystroke = ''

  compile: (keySequence) ->
    @result = []
    @seq = []
    @isTextMode = true
    @hasNextStroke = false
    @keystroke = ''

    for e in keySequence
      if @isKeyEvent(e)
        @parseKeyEvent(e)

      else
        @parseFindAndReplaceEvent(e)

    index = @result.length - 1
    console.log('index', index)
    while index >= 0
      e = @result[index--]
      if e.constructor.name == 'KeydownCommand'
        @result.pop()
      else
        break

    @result

  parseFindAndReplaceEvent: (e) ->
    @result.push(e)

  parseKeyEvent: (e) ->
    if(e.keyIdentifier?.match(/Control|Shift|Alt|Meta|Cmd/)) # skip meta keys
      return

    if e.altKey || e.ctrlKey || e.metaKey || hasNextStroke
      if @isTextMode and @seq.length != 0
        @result.push(new InputTextCommand(@seq))

      stroke = keystrokeForKeyboardEvent(e)
      if keystroke.length == 0
        @keystroke = stroke
      else
        @keystroke = @keystroke + ' ' + stroke

      bindings = atom.keymaps.findKeyBindings({keystrokes: @keystroke})
      if bindings.length == 0 || @notTextEditorCommand(bindings)
        @isTextMode = false
        @hasNextStroke = true
        @seq = [e]

      else
        @isTextMode = true
        @seq = []
        @hasNextStroke = false
        keystroke = ''
        if not @isAtomKeyboardMacrosCommand(bindings)
          @result.push(new DispatchCommand(stroke))

    else if @isNotCharKey(e)
      if @isTextMode
        @isTextMode = false
        if @seq.length > 0
          @result.push(new InputTextCommand(@seq))
        @result.push(new KeydownCommand([e]))
        @seq = []

      else
        @seq.push(e)

    else
      if @isTextMode
        @seq.push(e)
      else
        if not @isAtomKeyboardMacrosCommandSequence(@seq)
          @result.push(new KeydownCommand(@seq))
        @isTextMode = true
        @seq = [e]

  isKeyEvent: (e) ->
    e.keyIdentifier

  isNotCharKey: (e) ->
    e.keyIdentifier.match(/Enter|Up|Down|Left|Right|PageUp|PageDown|Escape|Backspace|Delete|Tab|Home|End/) ||
    e.keyCode < 32

  isAtomKeyboardMacrosCommand: (bindings) ->
    for keybind in bindings
      cmd = keybind.command
      if cmd.match( /^atom-keyboard-macros:/ )
        return true
    false

  isAtomKeyboardMacrosCommandSequence: (events) ->
    keystroke = ''
    for e in events
      s = keystrokeForKeyboardEvent(e)
      if keystroke.length == 0
        keystroke = s
      else
        keystroke = keystroke + ' ' + s
    bindings = atom.keymaps.findKeyBindings({keystrokes: keystroke})
    @isAtomKeyboardMacrosCommand(bindings)

  notTextEditorCommand: (bindings) ->
    for cmd in bindings
      if cmd.selector.match(/atom-text-editor|atom-workspace|body \.native-key-bindings/)
        return false
    true
