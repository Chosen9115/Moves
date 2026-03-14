import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "trigger"]
  static classes = ["open"]
  static values  = { open: { type: Boolean, default: false } }

  connect() {
    this._apply()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  openValueChanged() {
    this._apply()
  }

  _apply() {
    this.contentTargets.forEach(el => {
      el.classList.toggle("disclosure-hidden", !this.openValue)
    })
    this.triggerTargets.forEach(el => {
      el.classList.toggle("disclosure-open", this.openValue)
    })
  }
}
