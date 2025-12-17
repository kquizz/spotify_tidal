import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "content"]

  connect() {
    // noop
  }

  open(event) {
    const error = event.currentTarget.dataset.error
    this.contentTarget.textContent = error
    this.modalTarget.classList.remove("hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  copy() {
    const text = this.contentTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      // optionally show a temporary feedback
    })
  }
}
