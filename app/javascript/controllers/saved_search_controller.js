import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "nameInput", "queryInput", "queryField"]

  openModal() {
    this.modalTarget.classList.remove("hidden")
    // Update query field with current input value
    if (this.hasQueryInputTarget && this.hasQueryFieldTarget) {
      this.queryFieldTarget.value = this.queryInputTarget.value
    }
    // Focus the name input
    if (this.hasNameInputTarget) {
      this.nameInputTarget.focus()
    }
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
  }

  // Close on escape key
  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && !this.modalTarget.classList.contains("hidden")) {
      this.closeModal()
    }
  }
}
