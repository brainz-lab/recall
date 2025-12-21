import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["container", "empty", "input"]
  static values = { projectId: String }

  toggle(e) {
    e.target.checked ? this.start() : this.stop()
  }

  start() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "LogsChannel", project_id: this.projectIdValue },
      { received: (log) => this.handleLog(log) }
    )
  }

  stop() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  handleLog(log) {
    // Get current query from the search input
    const query = this.hasInputTarget ? this.inputTarget.value.trim() : ""

    // If no query, show all logs
    if (!query || this.matchesQuery(log, query)) {
      this.prepend(log)
    }
  }

  matchesQuery(log, query) {
    // Parse the query into filters
    const filters = this.parseQuery(query)

    // Check level filter
    if (filters.level) {
      const levels = filters.level.split(',')
      if (filters.levelNegated) {
        if (levels.includes(log.level)) return false
      } else {
        if (!levels.includes(log.level)) return false
      }
    }

    // Check environment
    if (filters.env && log.environment !== filters.env) return false

    // Check service
    if (filters.service && log.service !== filters.service) return false

    // Check host
    if (filters.host && log.host !== filters.host) return false

    // Check branch
    if (filters.branch && log.branch !== filters.branch) return false

    // Check commit
    if (filters.commit && log.commit !== filters.commit) return false

    // Check session
    if (filters.session && log.session_id !== filters.session) return false

    // Check request
    if (filters.request && log.request_id !== filters.request) return false

    // Check text searches (in message)
    for (const text of filters.textSearches) {
      if (!log.message?.toLowerCase().includes(text.toLowerCase())) return false
    }

    // Check data filters
    for (const [path, value] of Object.entries(filters.dataFilters)) {
      const logValue = this.getNestedValue(log.data, path)
      if (logValue === undefined) return false

      // Handle wildcards
      if (value.includes('*')) {
        const pattern = new RegExp('^' + value.replace(/\*/g, '.*') + '$')
        if (!pattern.test(String(logValue))) return false
      } else if (String(logValue) !== value) {
        return false
      }
    }

    return true
  }

  parseQuery(query) {
    const filters = {
      level: null,
      levelNegated: false,
      env: null,
      service: null,
      host: null,
      branch: null,
      commit: null,
      session: null,
      request: null,
      textSearches: [],
      dataFilters: {}
    }

    // Extract quoted text searches
    const textMatches = query.match(/"([^"]+)"/g)
    if (textMatches) {
      filters.textSearches = textMatches.map(m => m.slice(1, -1))
    }

    // Extract field:value pairs (including quoted values)
    const fieldPattern = /(\w+(?:\.\w+)*):(!)?("[^"]*"|[^\s]+)/g
    let match
    while ((match = fieldPattern.exec(query)) !== null) {
      const [, field, negated, rawValue] = match
      const value = rawValue.startsWith('"') ? rawValue.slice(1, -1) : rawValue

      if (field === 'level') {
        filters.level = value
        filters.levelNegated = negated === '!'
      } else if (field === 'env' || field === 'environment') {
        filters.env = value
      } else if (field === 'service') {
        filters.service = value
      } else if (field === 'host') {
        filters.host = value
      } else if (field === 'branch') {
        filters.branch = value
      } else if (field === 'commit') {
        filters.commit = value
      } else if (field === 'session' || field === 'session_id') {
        filters.session = value
      } else if (field === 'request' || field === 'request_id') {
        filters.request = value
      } else if (field.startsWith('data.')) {
        filters.dataFilters[field.slice(5)] = value
      }
    }

    return filters
  }

  getNestedValue(obj, path) {
    if (!obj) return undefined
    const parts = path.split('.')
    let value = obj
    for (const part of parts) {
      if (value === undefined || value === null) return undefined
      value = value[part]
    }
    return value
  }

  prepend(log) {
    // Remove "No logs found" message if present
    if (this.hasEmptyTarget) {
      this.emptyTarget.remove()
    }

    const levelClass = `log-level-${log.level}`
    const commit = log.commit ? `
      <button data-action="click->query#filter" data-query="commit:${this.escapeHtml(log.commit)}"
              class="text-[11px] font-mono px-2 py-1 rounded hover:ring-2 hover:ring-offset-1"
              style="background: #F5F3F0; color: #8B8780;"
              title="Filter by commit ${log.commit.slice(0, 7)}">
        ${log.commit.slice(0, 7)}
      </button>` : ''

    const dataHtml = log.data && Object.keys(log.data).length > 0
      ? `<div class="mb-3 p-2 rounded" style="background: #FFFFFE;">
           <div class="text-[12px] font-mono leading-relaxed">${this.renderInteractiveJson(log.data, 'data', 0)}</div>
         </div>`
      : ''

    const html = `
      <div class="log-row" data-controller="expand" style="border-bottom: 1px solid #F0EDE8;">
        <div class="flex items-center gap-4 px-5 py-3 cursor-pointer transition-colors hover:bg-[#FAF9F7]" data-action="click->expand#toggle">
          <span class="text-[12px] font-mono w-24" style="color: #B0ACA5;">${new Date(log.timestamp).toLocaleTimeString()}</span>
          <button data-action="click->query#filter" data-query="level:${log.level}"
                  class="log-level ${levelClass} px-2 py-0.5 text-[11px] font-medium rounded-full hover:ring-2 hover:ring-offset-1"
                  title="Filter by ${log.level}">
            ${log.level.toUpperCase()}
          </button>
          <span class="flex-1 text-[14px] font-mono truncate" style="color: #1A1A1A;">${this.escapeHtml(log.message || '')}</span>
          ${commit}
        </div>
        <div class="hidden px-5 pb-4" style="background: #FAF9F7;" data-expand-target="content">
          ${dataHtml}
          <div class="flex flex-wrap gap-4 text-[12px]" style="color: #8B8780;">
            ${log.session_id
              ? `<button data-action="click->query#filter" data-query="session:${this.escapeHtml(log.session_id)}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;" title="Filter by this session">
                   Session: ${this.escapeHtml(log.session_id)}
                 </button>`
              : '<span>Session: —</span>'}
            ${log.request_id
              ? `<button data-action="click->query#filter" data-query="request:${this.escapeHtml(log.request_id)}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;" title="Filter by this request">
                   Request: ${this.escapeHtml(log.request_id)}
                 </button>`
              : '<span>Request: —</span>'}
            ${log.branch
              ? `<button data-action="click->query#filter" data-query="branch:${this.escapeHtml(log.branch)}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;" title="Filter by this branch">
                   Branch: ${this.escapeHtml(log.branch)}
                 </button>`
              : '<span>Branch: —</span>'}
            ${log.commit
              ? `<button data-action="click->query#filter" data-query="commit:${this.escapeHtml(log.commit)}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;" title="Filter by this commit">
                   Commit: ${log.commit.slice(0, 7)}
                 </button>`
              : ''}
            ${log.environment
              ? `<button data-action="click->query#filter" data-query="env:${this.escapeHtml(log.environment)}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;" title="Filter by this environment">
                   Env: ${this.escapeHtml(log.environment)}
                 </button>`
              : ''}
            ${log.service
              ? `<button data-action="click->query#filter" data-query="service:${this.escapeHtml(log.service)}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;" title="Filter by this service">
                   Service: ${this.escapeHtml(log.service)}
                 </button>`
              : ''}
            ${log.host
              ? `<button data-action="click->query#filter" data-query="host:${this.escapeHtml(log.host)}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;" title="Filter by this host">
                   Host: ${this.escapeHtml(log.host)}
                 </button>`
              : ''}
          </div>
        </div>
      </div>
    `
    this.containerTarget.insertAdjacentHTML('afterbegin', html)
  }

  renderInteractiveJson(value, path, indent) {
    if (value === null) return this.renderPrimitive(null, path)
    if (Array.isArray(value)) return this.renderArray(value, path, indent)
    if (typeof value === 'object') return this.renderObject(value, path, indent)
    return this.renderPrimitive(value, path)
  }

  renderObject(obj, path, indent) {
    const keys = Object.keys(obj)
    if (keys.length === 0) return '<span style="color: #6B6760;">{}</span>'

    const padding = (indent + 1) * 12
    const closePadding = indent * 12
    let html = '<span style="color: #6B6760;">{</span>'

    keys.forEach((key, idx) => {
      const childPath = `${path}.${key}`
      const comma = idx < keys.length - 1 ? ',' : ''
      html += `
        <div style="padding-left: ${padding}px;">
          <span style="color: #1D4ED8;">"${this.escapeHtml(key)}"</span><span style="color: #6B6760;">: </span>${this.renderInteractiveJson(obj[key], childPath, indent + 1)}<span style="color: #6B6760;">${comma}</span>
        </div>`
    })

    html += `<div style="color: #6B6760; padding-left: ${closePadding}px;">}</div>`
    return html
  }

  renderArray(arr, path, indent) {
    if (arr.length === 0) return '<span style="color: #6B6760;">[]</span>'

    const padding = (indent + 1) * 12
    const closePadding = indent * 12
    let html = '<span style="color: #6B6760;">[</span>'

    arr.forEach((item, idx) => {
      const childPath = `${path}[${idx}]`
      const comma = idx < arr.length - 1 ? ',' : ''
      html += `
        <div style="padding-left: ${padding}px;">
          ${this.renderInteractiveJson(item, childPath, indent + 1)}<span style="color: #6B6760;">${comma}</span>
        </div>`
    })

    html += `<div style="color: #6B6760; padding-left: ${closePadding}px;">]</div>`
    return html
  }

  renderPrimitive(value, path) {
    const isString = typeof value === 'string'
    const display = isString ? `"${this.escapeHtml(value)}"` : String(value)
    const color = isString ? '#059669' : '#D97706'
    // Wrap value in quotes if it contains spaces or special characters
    const needsQuotes = isString && /[\s:"|]/.test(value)
    const escapedValue = needsQuotes ? `"${value.replace(/"/g, '\\"')}"` : String(value)
    const query = `${path}:${escapedValue}`

    return `<button type="button" data-action="click->query#filter" data-query="${this.escapeHtml(query)}"
                    class="hover:bg-blue-100 px-0.5 rounded cursor-pointer transition-colors"
                    style="color: ${color};"
                    title="Filter: ${this.escapeHtml(query)}">${display}</button>`
  }

  escapeHtml(text) {
    if (text === null || text === undefined) return 'null'
    const div = document.createElement('div')
    div.textContent = String(text)
    return div.innerHTML
  }

  disconnect() {
    this.stop()
  }
}
