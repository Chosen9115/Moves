import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "colorDot"]

  open() {
    // Position fixed modal relative to the section label
    const rect = this.element.querySelector(".sidebar-section-label").getBoundingClientRect()
    this.modalTarget.style.top = (rect.bottom + 4) + "px"
    this.modalTarget.style.display = "block"
    const input = this.modalTarget.querySelector("input[type=text]")
    if (input) setTimeout(() => input.focus(), 50)
  }

  close() {
    this.modalTarget.style.display = "none"
  }

  selectColor() {
    this.colorDotTargets.forEach(dot => dot.classList.remove("selected"))
    const checked = this.element.querySelector("input[name='project[color]']:checked")
    if (checked) {
      checked.closest("label").querySelector(".project-color-dot").classList.add("selected")
    }
  }

  connect() {
    this.selectColor()
  }
}
