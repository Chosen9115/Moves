import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hint", "form", "hintRow", "spinner"]
  static values = { parseUrl: String }

  connect() {
    this.updateHint()
    this.submitting = false
  }

  onInput() {
    this.updateHint()
    this.autoExpand()
  }

  onKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submitCapture()
    }
  }

  autoExpand() {
    const input = this.inputTarget
    input.style.height = "auto"
    input.style.height = input.scrollHeight + "px"
    input.style.overflow = "hidden"
  }

  updateHint() {
    const text = this.inputTarget.value
    const isRich = text.length > 50 || text.includes("\n")
    if (this.hasHintTarget) {
      this.hintTarget.textContent = isRich ? "Enter to parse with AI" : "Enter to capture"
      this.hintTarget.classList.toggle("hint-ai", isRich)
    }
  }

  submit(event) {
    // Allow the form through if we triggered it intentionally
    if (this.submitting) return

    event.preventDefault()
    this.submitCapture()
  }

  submitCapture() {
    const text = this.inputTarget.value.trim()
    if (!text) return

    this.showLoading()

    const isRich = text.length > 50 || text.includes("\n")
    if (isRich) {
      // Route to AI parse
      const form = document.createElement("form")
      form.method = "POST"
      form.action = this.parseUrlValue

      const csrfToken = document.querySelector("meta[name='csrf-token']").content
      const csrfInput = document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)

      const textInput = document.createElement("input")
      textInput.type = "hidden"
      textInput.name = "raw_text"
      textInput.value = text
      form.appendChild(textInput)

      document.body.appendChild(form)
      form.submit()
    } else {
      // Quick capture — set flag and submit the real form
      this.submitting = true
      this.formTarget.requestSubmit()
    }
  }

  showLoading() {
    if (this.hasHintTarget) {
      const isRich = this.inputTarget.value.length > 50 || this.inputTarget.value.includes("\n")
      this.hintTarget.textContent = isRich ? "Parsing with AI…" : "Capturing…"
      this.hintTarget.classList.add("hint-loading")
    }
    if (this.hasHintRowTarget) {
      this.hintRowTarget.classList.add("is-loading")
    }
    this.inputTarget.disabled = true
  }
}
