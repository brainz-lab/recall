import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  copy(event) {
    const text = event.currentTarget.dataset.copy
    const button = event.currentTarget
    const originalText = button.textContent.trim()

    this.copyToClipboard(text).then(() => {
      button.textContent = "Copied!"
      button.style.background = "#2D5A2D"
      button.style.color = "#E8F5E8"

      setTimeout(() => {
        button.textContent = originalText
        button.style.background = ""
        button.style.color = ""
      }, 2000)
    }).catch((err) => {
      console.error("Failed to copy:", err)
      button.textContent = "Failed"
      setTimeout(() => {
        button.textContent = originalText
      }, 2000)
    })
  }

  async copyToClipboard(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text)
    } else {
      // Fallback for older browsers or non-secure contexts
      const textArea = document.createElement("textarea")
      textArea.value = text
      textArea.style.position = "fixed"
      textArea.style.left = "-999999px"
      textArea.style.top = "-999999px"
      document.body.appendChild(textArea)
      textArea.focus()
      textArea.select()
      return new Promise((resolve, reject) => {
        document.execCommand("copy") ? resolve() : reject(new Error("execCommand failed"))
        textArea.remove()
      })
    }
  }
}
