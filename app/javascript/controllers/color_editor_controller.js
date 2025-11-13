import { Controller } from "@hotwired/stimulus"

// Controls live editing of --color-* CSS variables and persists to localStorage
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.load()
  }

  set(event) {
    const el = event.target
    const cssVar = el.dataset.cssVar
    const value = el.value
    document.documentElement.style.setProperty(cssVar, value)
    this.save()
  }

  load() {
    try {
      const saved = JSON.parse(localStorage.getItem("color_palette")) || {}
      Object.entries(saved).forEach(([k,v]) => {
        document.documentElement.style.setProperty(k, v)
        const input = this.element.querySelector(`input[data-css-var="${k}"]`)
        if (input) input.value = v
      })
    } catch(e) {
      // ignore
    }
  }

  save() {
    const data = {}
    this.inputTargets.forEach(input => data[input.dataset.cssVar] = input.value)
    localStorage.setItem("color_palette", JSON.stringify(data))
  }

  reset() {
    localStorage.removeItem("color_palette")
    // reload defaults by removing inline styles
    for (let i=1;i<=10;i++) {
      document.documentElement.style.removeProperty(`--color-${i}`)
    }
    this.inputTargets.forEach(input => input.value = getComputedStyle(document.documentElement).getPropertyValue(input.dataset.cssVar).trim())
  }
}
