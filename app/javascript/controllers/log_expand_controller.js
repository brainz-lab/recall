import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "chevron", "frame"]

  toggle() {
    const content = this.contentTarget
    const isHidden = content.classList.contains("hidden")

    // If opening and frame hasn't been loaded yet, trigger the load
    if (isHidden && this.hasFrameTarget) {
      const frame = this.frameTarget
      if (!frame.src && frame.dataset.src) {
        frame.src = frame.dataset.src
      }
    }

    content.classList.toggle("hidden")

    // Rotate chevron
    if (this.hasChevronTarget) {
      this.chevronTarget.style.transform = isHidden ? "rotate(90deg)" : ""
    }
  }
}
