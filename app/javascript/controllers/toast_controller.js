import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    setTimeout(() => this.element.classList.add('opacity-100'), 10)
    setTimeout(() => this.dismiss(), 5000)
  }

  dismiss() {
    this.element.classList.remove('opacity-100')
    setTimeout(() => this.element.remove(), 300)
  }
}
