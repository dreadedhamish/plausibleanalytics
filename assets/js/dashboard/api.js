import { formatISO } from './util/date'

let abortController = new AbortController()
let SHARED_LINK_AUTH = null

class ApiError extends Error {
  constructor(message, payload) {
    super(message)
    this.name = "ApiError"
    this.payload = payload
  }
}

function serialize(obj) {
  var str = [];
  for (var p in obj)
    /* eslint-disable-next-line no-prototype-builtins */
    if (obj.hasOwnProperty(p)) {
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
    }
  return str.join("&");
}

export function setSharedLinkAuth(auth) {
  SHARED_LINK_AUTH = auth
}

export function cancelAll() {
  abortController.abort()
  abortController = new AbortController()
}

function serializeFilters(filters) {
  const cleaned = {}
  Object.entries(filters).forEach(([key, val]) => val ? cleaned[key] = val : null);
  return JSON.stringify(cleaned)
}

export function serializeQuery(query, extraQuery = []) {
  const queryObj = {}
  if (query.period) { queryObj.period = query.period }
  if (query.date) { queryObj.date = formatISO(query.date) }
  if (query.from) { queryObj.from = formatISO(query.from) }
  if (query.to) { queryObj.to = formatISO(query.to) }
  if (query.filters) { queryObj.filters = serializeFilters(query.filters) }
  if (query.experimental_session_count) { queryObj.experimental_session_count = query.experimental_session_count }
  if (query.with_imported) { queryObj.with_imported = query.with_imported }
  if (SHARED_LINK_AUTH) { queryObj.auth = SHARED_LINK_AUTH }

  if (query.comparison) {
    queryObj.comparison = query.comparison
    queryObj.compare_from = query.compare_from ? formatISO(query.compare_from) : undefined
    queryObj.compare_to = query.compare_to ? formatISO(query.compare_to) : undefined
    queryObj.match_day_of_week = query.match_day_of_week
  }

  Object.assign(queryObj, ...extraQuery)

  return '?' + serialize(queryObj)
}

export function get(url, query = {}, ...extraQuery) {
  const headers = SHARED_LINK_AUTH ? { 'X-Shared-Link-Auth': SHARED_LINK_AUTH } : {}
  const serializedUrl = url + serializeQuery(query, extraQuery)
  return fetch(serializedUrl, { signal: abortController.signal, headers: headers })
    .then(response => {
      logDebugHeaders(url, response.headers)
      if (!response.ok) {
        return response.json().then((msg) => {
          throw new ApiError(msg.error, msg)
        })
      }
      return response.json()
    })
}

function logDebugHeaders(url, headers) {
  const debugHeaders = Array.from(headers).filter(([h]) => h.startsWith("x-plausible"))
  if (debugHeaders.length > 0) {
    console.info(url, Object.fromEntries(debugHeaders))
  }
}

export function put(url, body) {
  return fetch(url, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  })
}
