import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tracks", "link"]

  connect() {
    this.loaded = false
  }

  toggle(event) {
    event.preventDefault()

    if (this.loaded) {
      this.tracksTarget.classList.toggle("hidden")
    } else {
      // Load the tracks
      const url = this.linkTarget.href
      fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      .then(response => response.text())
      .then(html => {
        this.tracksTarget.innerHTML = html
        this.tracksTarget.classList.remove("hidden")
        this.loaded = true
      })
    }
  }
}