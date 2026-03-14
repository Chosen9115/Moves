import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "input", "results", "hint"]

  connect() {
    this._onKey = this._globalKey.bind(this)
    document.addEventListener("keydown", this._onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKey)
  }

  _globalKey(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === "k") {
      e.preventDefault()
      this.open()
    }
  }

  open() {
    this.overlayTarget.classList.remove("palette-hidden")
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this._fetchResults("")
  }

  close() {
    this.overlayTarget.classList.add("palette-hidden")
  }

  overlayClick(e) {
    if (e.target === this.overlayTarget) this.close()
  }

  keydown(e) {
    if (e.key === "Escape") { this.close(); return }
    if (e.key === "ArrowDown") { e.preventDefault(); this._moveFocus(1); return }
    if (e.key === "ArrowUp")   { e.preventDefault(); this._moveFocus(-1); return }
    if (e.key === "Enter")     { e.preventDefault(); this._selectActive(); return }
  }

  search() {
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => this._fetchResults(this.inputTarget.value.trim()), 120)
  }

  async _fetchResults(q) {
    const res  = await fetch(`/search?q=${encodeURIComponent(q)}`)
    const data = await res.json()
    this._render(q, data)
  }

  _render(q, data) {
    const el = this.resultsTarget
    el.innerHTML = ""

    const recDisplay = {
      "Push now": "Move now", "Good bet": "Strong position",
      "Needs signal": "Gone quiet", "Optional": "Low priority",
      "Probably dead": "Let it go", "Reassess": "Re-examine"
    }
    const recColor = {
      "Push now": "var(--accent)", "Good bet": "var(--blue)",
      "Needs signal": "var(--amber)", "Probably dead": "var(--danger)",
      "Reassess": "var(--danger)"
    }

    if (q) {
      el.appendChild(this._item({
        label: `New move: <strong>${this._esc(q)}</strong>`,
        icon: "+",
        action: () => {
          const form = document.getElementById("palette-quick-form")
          form.querySelector("[name='move[title]']").value = q
          form.submit()
        }
      }))
    }

    data.moves?.forEach(m => {
      const rec = recDisplay[m.rec] || m.rec
      const color = recColor[m.rec] || "var(--muted)"
      el.appendChild(this._item({
        label: this._esc(m.title),
        meta: rec,
        metaColor: color,
        icon: "→",
        action: () => { window.location.href = m.url }
      }))
    })

    data.campaigns?.forEach(c => {
      el.appendChild(this._item({
        label: this._esc(c.name),
        meta: "Campaign",
        icon: "◈",
        action: () => { window.location.href = c.url }
      }))
    })

    if (!q && !data.moves?.length && !data.campaigns?.length) {
      const empty = document.createElement("div")
      empty.className = "palette-empty"
      empty.textContent = "Type to search moves and campaigns."
      el.appendChild(empty)
    }

    if (el.children.length > 0) el.children[0].classList.add("active")
  }

  _item({ label, meta, metaColor, icon, action }) {
    const row = document.createElement("div")
    row.className = "palette-item"
    row.innerHTML = `
      <span class="palette-item-icon">${icon}</span>
      <span class="palette-item-label">${label}</span>
      ${meta ? `<span class="palette-item-meta" style="color:${metaColor || "var(--muted)"}">${meta}</span>` : ""}
    `
    row.addEventListener("click", action)
    row.addEventListener("mouseenter", () => {
      this.resultsTarget.querySelectorAll(".palette-item").forEach(r => r.classList.remove("active"))
      row.classList.add("active")
    })
    return row
  }

  _moveFocus(dir) {
    const items = [...this.resultsTarget.querySelectorAll(".palette-item")]
    const curr  = items.findIndex(i => i.classList.contains("active"))
    const next  = Math.max(0, Math.min(items.length - 1, curr + dir))
    items.forEach(i => i.classList.remove("active"))
    items[next]?.classList.add("active")
    items[next]?.scrollIntoView({ block: "nearest" })
  }

  _selectActive() {
    this.resultsTarget.querySelector(".palette-item.active")?.click()
  }

  _esc(s) {
    return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")
  }
}
