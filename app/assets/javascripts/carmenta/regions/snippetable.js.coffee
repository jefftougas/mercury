#= require_self
#= require ./snippetable.snippet

class Carmenta.Regions.Snippetable
  type = 'snippetable'

  constructor: (@element, @options = {}) ->
    Carmenta.log('building snippetable', @element)

    @window = @options.window
    @document = @window.document
    @type = @element.data('type')
    @history = new Carmenta.HistoryBuffer()
    @toolbar = new Carmenta.Regions.Snippetable.Toolbar(@element, @document)
    @build()
    @bindEvents()
    @pushHistory()
    @makeSortable()


  build: ->
    @element.css({minHeight: 20}) if @element.css('minHeight') == '0px'


  bindEvents: ->
    Carmenta.bind 'mode', (event, options) =>
      @togglePreview() if options.mode == 'preview'

    Carmenta.bind 'unfocus:regions', (event) =>
      if Carmenta.region == @
        @element.removeClass('focus')
        @element.sortable('destroy')
        Carmenta.trigger('region:blurred', {region: @})

    Carmenta.bind 'focus:window', (event) =>
      if Carmenta.region == @
        @element.removeClass('focus')
        @element.sortable('destroy')
        Carmenta.trigger('region:blurred', {region: @})

    Carmenta.bind 'focus:frame', =>
      return if @previewing
      return unless Carmenta.region == @
      @focus()

    Carmenta.bind 'action', (event, options) =>
      return if @previewing
      return unless Carmenta.region == @
      @execCommand(options.action, options) if options.action

    $(@document).keydown (event) =>
      return if @previewing
      return unless Carmenta.region == @
      Carmenta.changes = true
      switch event.keyCode

        when 90 # undo / redo
          return unless event.metaKey
          event.preventDefault()
          if event.shiftKey
            @execCommand('redo')
          else
            @execCommand('undo')

          return

    @element.mouseup =>
      return if @previewing
      @focus()
      Carmenta.trigger('region:focused', {region: @})

    @element.mousemove (event) =>
      return if @previewing
      return unless Carmenta.region == @
      @snippet = $(event.target).closest('.carmenta-snippet')
      if @snippet.length
        @snippet.mouseout => @toolbar.hide()
        @toolbar.show(@snippet)

    @element.mouseout (event) =>
      @toolbar.hide()


  makeSortable: ->
    @element.sortable('destroy').sortable {
      document: @document,
      #handle: @toolbar.element,
      scroll: false, #scrolling is buggy
      containment: 'parent',
      items: '.carmenta-snippet',
      opacity: .4,
      revert: 100,
      tolerance: 'pointer',
      connectWith: '.carmenta-region[data-type=snippetable]',
      beforeStop: =>
        @toolbar.hide(true)
        return true
      stop: =>
        setTimeout((=> @pushHistory()), 100)
        return true
    }


  togglePreview: ->
    if @previewing
      @previewing = false
      @makeSortable()
      @element.addClass('carmenta-region').removeClass('carmenta-region-preview')
      @element.focus() if Carmenta.region == @
    else
      @previewing = true
      @element.sortable('destroy')
      @element.addClass('carmenta-region-preview').removeClass('carmenta-region')
      @element.blur()
      Carmenta.trigger('region:blurred', {region: @})


  html: (value = null) ->
    if value != null
      @element.html(value)
    else
      # sanitizes the html before we return it
      container = $('<div>').appendTo(@document.createDocumentFragment())
      container.html(@element.html().replace(/^\s+|\s+$/g, ''))
      html = container.html()

      return html


  focus: ->
    Carmenta.region = @
    @makeSortable()
    @element.addClass('focus')


  pushHistory: ->
    @history.push(@html())


  execCommand: (action, options = {}) ->
    @focus()
    Carmenta.log('execCommand', action, options.value)

    if handler = Carmenta.Regions.Snippetable.actions[action]
      Carmenta.changes = true
      handler.call(@, options)
      @pushHistory() unless action == 'undo' || action == 'redo'



Carmenta.Regions.Snippetable.actions =

  undo: -> @html(@history.undo())

  redo: -> @html(@history.redo())

  removesnippet: ->
    @snippet.remove() if @snippet
    @toolbar.hide(true)