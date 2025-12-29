import { Controller } from "@hotwired/stimulus"

// Handles client-side rendering of interactive JSON trees
// This offloads expensive DOM generation from the server to the client
export default class extends Controller {
  static values = {
    data: String,
    prefix: { type: String, default: "data" }
  }

  connect() {
    this.render()
  }

  render() {
    try {
      const data = JSON.parse(this.dataValue)
      this.element.innerHTML = this.renderValue(data, this.prefixValue, 0)
    } catch (e) {
      this.element.innerHTML = `<span style="color: #DC2626;">Invalid JSON</span>`
    }
  }

  renderValue(value, path, indent) {
    if (value === null) return this.renderPrimitive(null, path)
    if (Array.isArray(value)) return this.renderArray(value, path, indent)
    if (typeof value === "object") return this.renderObject(value, path, indent)
    return this.renderPrimitive(value, path)
  }

  renderObject(obj, path, indent) {
    const keys = Object.keys(obj)
    if (keys.length === 0) return `<span style="color: #6B6760;">{}</span>`

    let html = `<span style="color: #6B6760;">{</span>`
    keys.forEach((key, idx) => {
      const childPath = `${path}.${key}`
      const comma = idx < keys.length - 1 ? "," : ""
      const padding = (indent + 1) * 12

      html += `<div style="padding-left: ${padding}px;">`
      html += `<span style="color: #1D4ED8;">"${this.escapeHtml(key)}"</span>`
      html += `<span style="color: #6B6760;">: </span>`
      html += this.renderValue(obj[key], childPath, indent + 1)
      html += `<span style="color: #6B6760;">${comma}</span>`
      html += `</div>`
    })
    html += `<div style="color: #6B6760; padding-left: ${indent * 12}px;">}</div>`
    return html
  }

  renderArray(arr, path, indent) {
    if (arr.length === 0) return `<span style="color: #6B6760;">[]</span>`

    let html = `<span style="color: #6B6760;">[</span>`
    arr.forEach((item, idx) => {
      const childPath = `${path}[${idx}]`
      const comma = idx < arr.length - 1 ? "," : ""
      const padding = (indent + 1) * 12

      html += `<div style="padding-left: ${padding}px;">`
      html += this.renderValue(item, childPath, indent + 1)
      html += `<span style="color: #6B6760;">${comma}</span>`
      html += `</div>`
    })
    html += `<div style="color: #6B6760; padding-left: ${indent * 12}px;">]</div>`
    return html
  }

  renderPrimitive(value, path) {
    let display, color, escapedValue

    if (value === null) {
      display = "null"
      color = "#D97706"
      escapedValue = "null"
    } else if (typeof value === "string") {
      display = `"${this.escapeHtml(value)}"`
      color = "#059669"
      // Wrap value in quotes if it contains spaces or special characters
      escapedValue = /[\s:"|]/.test(value) ? `"${value.replace(/"/g, '\\"')}"` : value
    } else if (typeof value === "boolean") {
      display = String(value)
      color = "#D97706"
      escapedValue = String(value)
    } else {
      display = String(value)
      color = "#D97706"
      escapedValue = String(value)
    }

    const query = `${path}:${escapedValue}`
    return `<button type="button" data-action="click->query#filter" data-query="${this.escapeHtml(query)}" class="hover:bg-blue-100 px-0.5 rounded cursor-pointer transition-colors" style="color: ${color};" title="Filter: ${this.escapeHtml(query)}">${display}</button>`
  }

  escapeHtml(str) {
    if (str === null || str === undefined) return ""
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}
