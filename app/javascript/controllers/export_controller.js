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

    // Build and submit a POST form for download
    const form = document.createElement("form")
    form.method = "POST"
    form.action = `/dashboard/projects/${this.projectIdValue}/exports`
    form.style.display = "none"

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      const tokenInput = document.createElement("input")
      tokenInput.type = "hidden"
      tokenInput.name = "authenticity_token"
      tokenInput.value = csrfToken
      form.appendChild(tokenInput)
    }

    const fields = { format, q: query, since, until }
    for (const [name, value] of Object.entries(fields)) {
      if (value) {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = name
        input.value = value
        form.appendChild(input)
      }
    }

    document.body.appendChild(form)
    form.submit()
    form.remove()
    this.close()
  }
}
