import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle() {
    const content = this.contentTarget

    // Render details on first expand (client-side rendering for performance)
    if (!content.dataset.rendered && content.dataset.logDetails) {
      const details = JSON.parse(content.dataset.logDetails)
      content.innerHTML = this.renderDetails(details)
      content.dataset.rendered = "true"
    }

    content.classList.toggle("hidden")
  }

  renderDetails(d) {
    const sessionIcon = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>'
    const requestIcon = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>'

    let html = ''

    // JSON data section
    if (d.data && Object.keys(d.data).length > 0) {
      html += `<div class="mb-3 p-2 rounded" style="background: #FFFFFE;">
        <div class="interactive-json text-[12px] font-mono leading-relaxed"
             data-controller="json-tree"
             data-json-tree-data-value='${JSON.stringify(d.data).replace(/'/g, "&#39;")}'
             data-json-tree-prefix-value="data"></div>
      </div>`
    }

    // Metadata row
    html += '<div class="flex flex-wrap gap-4 text-[12px]" style="color: #8B8780;">'

    // Session link
    if (d.session_id) {
      html += `<a href="/dashboard/projects/${d.project_id}/logs/session_trace?session_id=${encodeURIComponent(d.session_id)}"
                  class="hover:underline cursor-pointer flex items-center gap-1" style="color: #1D4ED8;"
                  title="View session trace" data-turbo-frame="_top">
                  ${sessionIcon} Session: ${d.session_id.substring(0, 20)}${d.session_id.length > 20 ? '...' : ''}
               </a>`
    } else {
      html += '<span>Session: —</span>'
    }

    // Request link
    if (d.request_id) {
      html += `<a href="/dashboard/projects/${d.project_id}/logs/trace?request_id=${encodeURIComponent(d.request_id)}"
                  class="hover:underline cursor-pointer flex items-center gap-1" style="color: #1D4ED8;"
                  title="View request trace" data-turbo-frame="_top">
                  ${requestIcon} Request: ${d.request_id}
               </a>`
    } else {
      html += '<span>Request: —</span>'
    }

    // Filter buttons
    const filters = [
      { label: 'Branch', value: d.branch, prefix: 'branch' },
      { label: 'Commit', value: d.commit, prefix: 'commit' },
      { label: 'Env', value: d.environment, prefix: 'env' },
      { label: 'Service', value: d.service, prefix: 'service' },
      { label: 'Host', value: d.host, prefix: 'host' }
    ]

    for (const f of filters) {
      if (f.value) {
        html += `<button data-action="click->query#filter" data-query="${f.prefix}:${f.value}"
                         class="hover:underline cursor-pointer" style="color: #1D4ED8;"
                         title="Filter by this ${f.label.toLowerCase()}">${f.label}: ${f.value}</button>`
      } else if (f.label !== 'Commit') {
        html += `<span>${f.label}: —</span>`
      }
    }

    html += '</div>'
    return html
  }
}
