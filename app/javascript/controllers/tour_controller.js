import { Controller } from "@hotwired/stimulus"

const STEPS = [
  {
    page: "/inbox",
    title: "Welcome to Moves",
    body: "Moves helps you focus on what actually matters. Every task gets scored by expected value — so you always know your best move. Let's walk through the core loop.",
    target: ".page-header-title",
    position: "bottom"
  },
  {
    page: "/inbox",
    title: "Capture everything here",
    body: "Type a quick note and press Enter to capture instantly. For longer thoughts, just keep talking — paste or dictate a paragraph and Moves will parse it with AI into structured fields.",
    target: ".capture-bar",
    position: "bottom"
  },
  {
    page: "/inbox",
    title: "Voice & paste guide",
    body: "Hover this icon anytime to see what details to include: the move, who's involved, dollar value, probability, effort, and deadlines. The more you share, the smarter the AI parse.",
    target: ".capture-hint-icon",
    position: "bottom"
  },
  {
    page: "/inbox",
    title: "Develop your moves",
    body: "New captures land here as inbox items. Click \"Develop →\" to fill in probability, effort, and payoff — the three inputs that drive your EV score. Or let AI suggest them.",
    target: ".move-list, .empty-state",
    position: "top"
  },
  {
    page: null,
    navigate: true,
    title: "Your move list",
    body: "All your active moves live here. Each row shows its recommendation — Move now, Strong position, Gone quiet — so you can scan and act fast.",
    sidebar: ".sidebar-nav a:nth-child(2)",
    target: ".page-header-title",
    position: "bottom"
  },
  {
    page: null,
    navigate: true,
    title: "Campaigns group related moves",
    body: "A campaign is a goal — like \"Close Series A\" or \"Launch product\". Moves inside a campaign share momentum. Campaign health rolls up from its moves.",
    sidebar: ".sidebar-nav a:nth-child(3)",
    target: ".page-header-title",
    position: "bottom"
  },
  {
    page: null,
    navigate: true,
    title: "Focus — your daily command center",
    body: "This is where Moves earns its keep. The Focus page ranks everything by expected value and surfaces your best moves, strategic bets, and things gone quiet. Start every day here.",
    sidebar: ".sidebar-nav a:nth-child(4)",
    target: ".main",
    position: "center"
  },
  {
    page: null,
    title: "Projects filter your world",
    body: "Projects are color-coded lenses. Click one to filter all views — moves, campaigns, and focus — to just that project. Click \"All projects\" to see everything.",
    target: ".sidebar-projects",
    position: "right"
  },
  {
    page: null,
    title: "Quick search with ⌘K",
    body: "Press ⌘K anytime to search across all moves and campaigns, or type a new move to capture it instantly from anywhere in the app.",
    target: ".sidebar-cmd-btn",
    position: "right"
  },
  {
    page: null,
    title: "You're ready",
    body: "Capture what's on your mind, develop the details, then check Focus daily to know your best move. The system gets smarter as you add signals and update probabilities. Go make your first move.",
    target: null,
    position: "center"
  }
]

export default class extends Controller {
  static values = { autoStart: Boolean }

  connect() {
    // Check for a saved step (mid-tour page navigation)
    const savedStep = localStorage.getItem("moves_tour_step")
    if (savedStep !== null && this.autoStartValue) {
      this.stepIndex = parseInt(savedStep, 10)
      this.resumedFromNav = true  // Skip re-navigation for this step
      localStorage.removeItem("moves_tour_step")
      setTimeout(() => this.render(), 300)
      return
    }

    this.stepIndex = 0
    this.resumedFromNav = false

    if (this.autoStartValue) {
      setTimeout(() => this.start(), 300)
    } else if (this.shouldAutoRun()) {
      setTimeout(() => this.start(), 500)
    }
  }

  disconnect() {
    this.cleanup()
  }

  shouldAutoRun() {
    return !localStorage.getItem("moves_tour_completed") && !localStorage.getItem("moves_tour_dismissed")
  }

  start() {
    this.stepIndex = 0
    this.render()
  }

  restart() {
    localStorage.removeItem("moves_tour_completed")
    localStorage.removeItem("moves_tour_dismissed")
    // Navigate to inbox to start the tour
    window.location.href = "/inbox?tour=1"
  }

  render() {
    this.cleanup()

    const step = STEPS[this.stepIndex]
    if (!step) return this.finish()

    // Skip navigation if we just arrived here from a page change
    if (!this.resumedFromNav) {
      // If step requires a specific page, navigate there
      if (step.page && !window.location.pathname.startsWith(step.page)) {
        localStorage.setItem("moves_tour_step", this.stepIndex)
        window.location.href = step.page + "?tour=1"
        return
      }

      // If step navigates via sidebar click
      if (step.navigate && step.sidebar) {
        const sidebarLink = document.querySelector(step.sidebar)
        if (sidebarLink) {
          localStorage.setItem("moves_tour_step", this.stepIndex)
          const href = sidebarLink.getAttribute("href")
          window.location.href = href + (href.includes("?") ? "&" : "?") + "tour=1"
          return
        }
      }
    }
    this.resumedFromNav = false

    // Build overlay
    this.overlay = document.createElement("div")
    this.overlay.className = "tour-overlay"
    this.overlay.addEventListener("click", (e) => {
      if (e.target === this.overlay) this.dismiss()
    })

    // Build tooltip
    const tooltip = document.createElement("div")
    tooltip.className = "tour-tooltip"
    tooltip.innerHTML = `
      <div class="tour-step-indicator">${this.stepIndex + 1} of ${STEPS.length}</div>
      <div class="tour-title">${step.title}</div>
      <div class="tour-body">${step.body}</div>
      <div class="tour-actions">
        <button class="tour-btn-skip" data-action="skip">Skip tour</button>
        <button class="tour-btn-next" data-action="next">
          ${this.stepIndex === STEPS.length - 1 ? "Get started" : "Next →"}
        </button>
      </div>
    `

    tooltip.querySelector("[data-action='skip']").addEventListener("click", () => this.dismiss())
    tooltip.querySelector("[data-action='next']").addEventListener("click", () => this.next())

    // Position
    const target = step.target ? document.querySelector(step.target) : null

    if (target && step.position !== "center") {
      // Create spotlight hole — its box-shadow provides the dimming
      const rect = target.getBoundingClientRect()
      const pad = 8
      this.spotlight = document.createElement("div")
      this.spotlight.className = "tour-spotlight"
      this.spotlight.style.top = (rect.top - pad) + "px"
      this.spotlight.style.left = (rect.left - pad) + "px"
      this.spotlight.style.width = (rect.width + pad * 2) + "px"
      this.spotlight.style.height = (rect.height + pad * 2) + "px"
      document.body.appendChild(this.spotlight)

      // Overlay is transparent — spotlight box-shadow handles dimming
      this.overlay.classList.add("tour-overlay-transparent")
      document.body.appendChild(this.overlay)

      // Position tooltip relative to target
      document.body.appendChild(tooltip)
      this.positionTooltip(tooltip, rect, step.position)
    } else {
      // Centered modal — overlay provides the dimming
      tooltip.classList.add("tour-tooltip-centered")
      document.body.appendChild(this.overlay)
      document.body.appendChild(tooltip)
    }

    this.tooltip = tooltip

    // Animate in
    requestAnimationFrame(() => {
      this.overlay.classList.add("tour-overlay-visible")
      tooltip.classList.add("tour-tooltip-visible")
      if (this.spotlight) this.spotlight.classList.add("tour-spotlight-visible")
    })

    // Keyboard
    this._keyHandler = (e) => {
      if (e.key === "Escape") this.dismiss()
      if (e.key === "ArrowRight" || e.key === "Enter") this.next()
      if (e.key === "ArrowLeft") this.prev()
    }
    document.addEventListener("keydown", this._keyHandler)
  }

  positionTooltip(tooltip, rect, position) {
    const margin = 16
    requestAnimationFrame(() => {
      const tw = tooltip.offsetWidth
      const th = tooltip.offsetHeight
      let top, left

      switch (position) {
        case "bottom":
          top = rect.bottom + margin
          left = rect.left + rect.width / 2 - tw / 2
          break
        case "top":
          top = rect.top - th - margin
          left = rect.left + rect.width / 2 - tw / 2
          break
        case "right":
          top = rect.top + rect.height / 2 - th / 2
          left = rect.right + margin
          break
        case "left":
          top = rect.top + rect.height / 2 - th / 2
          left = rect.left - tw - margin
          break
      }

      // Keep on screen
      left = Math.max(margin, Math.min(left, window.innerWidth - tw - margin))
      top = Math.max(margin, Math.min(top, window.innerHeight - th - margin))

      tooltip.style.top = top + "px"
      tooltip.style.left = left + "px"
    })
  }

  next() {
    this.stepIndex++
    if (this.stepIndex >= STEPS.length) {
      this.finish()
    } else {
      this.render()
    }
  }

  prev() {
    if (this.stepIndex > 0) {
      this.stepIndex--
      this.render()
    }
  }

  dismiss() {
    localStorage.setItem("moves_tour_dismissed", "true")
    localStorage.removeItem("moves_tour_step")
    this.cleanup()
  }

  finish() {
    localStorage.setItem("moves_tour_completed", "true")
    localStorage.removeItem("moves_tour_step")
    this.cleanup()
  }

  cleanup() {
    if (this.overlay) { this.overlay.remove(); this.overlay = null }
    if (this.tooltip) { this.tooltip.remove(); this.tooltip = null }
    if (this.spotlight) { this.spotlight.remove(); this.spotlight = null }
    if (this._keyHandler) {
      document.removeEventListener("keydown", this._keyHandler)
      this._keyHandler = null
    }
  }
}
