import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "progress"]
  static values = { current: { type: Number, default: 0 } }

  connect() {
    this.showStep(this.currentValue)
    this.element.addEventListener("keydown", this.handleKey.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleKey.bind(this))
  }

  handleKey(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      const active = this.stepTargets[this.currentValue]
      const primaryInput = active?.querySelector("input[data-wizard-primary]")
      if (primaryInput && primaryInput === document.activeElement && primaryInput.value.trim()) {
        e.preventDefault()
        this.next()
      }
    }
    if (e.key === "Escape") this.cancel()
  }

  next() {
    if (this.currentValue < this.stepTargets.length - 1) {
      this.showStep(this.currentValue + 1)
    }
  }

  back() {
    if (this.currentValue > 0) {
      this.showStep(this.currentValue - 1)
    }
  }

  skip() {
    this.next()
  }

  cancel() {
    window.history.back()
  }

  selectProb(e) {
    const btn = e.currentTarget
    btn.closest("[data-wizard-prob-group]").querySelectorAll(".wizard-choice-btn").forEach(b => b.classList.remove("selected"))
    btn.classList.add("selected")
    this.element.querySelector("[data-prob-input]").value = btn.dataset.value
  }

  selectEffort(e) {
    const btn = e.currentTarget
    btn.closest("[data-wizard-effort-group]").querySelectorAll(".wizard-choice-btn").forEach(b => b.classList.remove("selected"))
    btn.classList.add("selected")
    this.element.querySelector("[data-effort-input]").value = btn.dataset.value
  }

  selectScale(e) {
    const btn = e.currentTarget
    btn.closest("[data-wizard-scale-group]").querySelectorAll(".wizard-scale-btn").forEach(b => b.classList.remove("selected"))
    btn.classList.add("selected")
    this.element.querySelector("[data-scale-input]").value = btn.dataset.value
    // Clear the raw $ input when a scale is chosen
    const rawInput = this.element.querySelector("[data-raw-input]")
    if (rawInput) rawInput.value = ""
  }

  rawInputChanged(e) {
    if (e.target.value.trim()) {
      // Clear scale selection when typing a $ amount
      this.element.querySelectorAll(".wizard-scale-btn").forEach(b => b.classList.remove("selected"))
      this.element.querySelector("[data-scale-input]").value = ""
    }
  }

  showStep(index) {
    this.stepTargets.forEach((step, i) => {
      step.classList.toggle("wizard-step-active", i === index)
      step.classList.toggle("wizard-step-hidden", i !== index)
    })
    this.currentValue = index
    this.updateProgress()

    // Focus primary input in new step
    const active = this.stepTargets[index]
    const primaryInput = active?.querySelector("input[data-wizard-primary], textarea[data-wizard-primary]")
    if (primaryInput) {
      setTimeout(() => primaryInput.focus(), 50)
    }
  }

  updateProgress() {
    if (this.hasProgressTarget) {
      this.progressTargets.forEach((dot, i) => {
        dot.classList.toggle("active", i === this.currentValue)
        dot.classList.toggle("done", i < this.currentValue)
      })
    }
  }
}
