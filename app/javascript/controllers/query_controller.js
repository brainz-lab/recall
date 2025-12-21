import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  filter(e) {
    e.stopPropagation()
    this.inputTarget.value = e.currentTarget.dataset.query
    this.inputTarget.form.requestSubmit()
  }
}
