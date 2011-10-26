pluginID = 'com.gojotter.http'

nextRequestID = 0
allocateRequestID = ->
  allocatedID = nextRequestID
  nextRequestID++
  "#{allocatedID}"

window.HTTP =
  fetch: (options) ->
    url = options?.url
    throw "URL required" unless url

    verb = options?.verb ? 'GET'
    throw "Invalid verb '#{verb}'" unless _(['GET', 'POST']).include(verb)

    requestID = allocateRequestID()

    # Convert all values to strings before passing along.
    params = options?.params
    if params
      params[key] = value.toString() for key,value of params

    PhoneGap.exec(
      options?.successHandler, options?.errorHandler, pluginID, "fetch",
      [
        requestID: requestID
        url: url
        verb: verb
        params: params
        data: options?.data
        timeout: options?.timeout
      ]
    )

    requestID

  abort: (requestID) ->
    PhoneGap.exec(null, null, pluginID, 'abort', [requestID: requestID])
