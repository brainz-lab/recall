import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "queryInput", "sinceInput", "untilInput", "formatSelect"]
  static values = { projectId: String }

  open() {
    // Copy current query to export form
    const queryInput = document.querySelector('[data-query-target="input"]')
    if (queryInput && this.hasQueryInputTarget) {
      this.queryInputTarget.value = queryInput.value
    }
    this.modalTarget.classList.remove("hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  closeOnEscape(e) {
    if (e.key === "Escape") this.close()
  }

  submit(e) {
    e.preventDefault()

    const format = this.formatSelectTarget.value
    const query = this.queryInputTarget.value
    const since = this.sinceInputTarget.value
    const until = this.untilInputTarget.value

    // Build export URL
    const params = new URLSearchParams()
    params.set('format', format)
    if (query) params.set('q', query)
    if (since) params.set('since', since)
    if (until) params.set('until', until)

    // Trigger download
    window.location.href = `/dashboard/projects/${this.projectIdValue}/exports?${params.toString()}`
    this.close()
  }
}
