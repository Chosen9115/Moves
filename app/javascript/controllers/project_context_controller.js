import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static values = { projectId: Number, projectName: String, projectColor: String }

  connect() {
    this.boundClose = this.closeMenu.bind(this)
    document.addEventListener("click", this.boundClose)
    document.addEventListener("contextmenu", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
    document.removeEventListener("contextmenu", this.boundClose)
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    // Close any other open menus
    document.querySelectorAll(".project-ctx-menu").forEach(m => m.style.display = "none")

    const menu = this.menuTarget
    menu.style.display = "block"

    // Position near the click
    const rect = this.element.getBoundingClientRect()
    menu.style.top = `${rect.bottom + 4}px`
    menu.style.left = `${rect.left}px`
  }

  closeMenu(event) {
    if (this.hasMenuTarget && !this.menuTarget.contains(event?.target)) {
      this.menuTarget.style.display = "none"
    }
  }

  rename() {
    const newName = this.menuTarget.querySelector("[data-rename-input]").value.trim()
    if (!newName) return

    fetch(`/projects/${this.projectIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ project: { name: newName } })
    }).then(() => window.location.reload())
  }

  changeColor(event) {
    const color = event.currentTarget.dataset.color
    fetch(`/projects/${this.projectIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ project: { color: color } })
    }).then(() => window.location.reload())
  }

  confirmDelete() {
    if (!confirm("This project's campaigns will become unassigned. Delete?")) return

    fetch(`/projects/${this.projectIdValue}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      }
    }).then(() => window.location.reload())
  }
}
