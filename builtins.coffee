window.navigator =
  geolocation: {}


class Event
  initEvent: (type) ->
    throw "type required" unless type?
    @type = type

document.createEvent = (type) ->
  throw "type must be 'Events'" unless type == 'Events'
  new Event


documentEventHandler = new window.Listenable

document.addEventListener = (type, listener) ->
  documentEventHandler.addEventListener(type, listener)

document.removeEventListener = (type, listener) ->
  documentEventHandler.removeEventListener(type, listener)

document.dispatchEvent = (event) ->
  documentEventHandler.fireEvent(event.type)
