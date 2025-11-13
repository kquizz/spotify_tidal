import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  toggle() {
    document.documentElement.classList.toggle("dark")
  }
}