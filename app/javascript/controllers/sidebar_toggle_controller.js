import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "univerhub_sidebar_collapsed"
const MOBILE_BREAKPOINT = 992

export default class extends Controller {
  static targets = ["sidebar", "main", "overlay", "toggle"]

  connect() {
    this._isMobile = window.innerWidth < MOBILE_BREAKPOINT
    this._handleResize = this.handleResize.bind(this)
    this._handleKeydown = this.handleKeydown.bind(this)
    this.restoreState()
    document.addEventListener("keydown", this._handleKeydown)
    window.addEventListener("resize", this._handleResize)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleKeydown)
    window.removeEventListener("resize", this._handleResize)
  }

  handleResize() {
    this._isMobile = window.innerWidth < MOBILE_BREAKPOINT
  }

  toggle() {
    if (this._isMobile) {
      this.toggleMobile()
    } else {
      this.toggleDesktop()
    }
  }

  close() {
    if (this._isMobile) {
      document.body.classList.remove("sidebar-open")
      this.overlayTarget.setAttribute("aria-hidden", "true")
      this.unlockBodyScroll()
      this.returnFocusToToggle()
    }
  }

  toggleDesktop() {
    const collapsed = document.body.classList.toggle("sidebar-collapsed")
    localStorage.setItem(STORAGE_KEY, collapsed ? "1" : "0")
    this.updateToggleAria(!collapsed)
  }

  toggleMobile() {
    const opening = !document.body.classList.contains("sidebar-open")
    document.body.classList.toggle("sidebar-open")
    if (opening) {
      this.lockBodyScroll()
      this.overlayTarget.setAttribute("aria-hidden", "false")
      this.sidebarTarget.setAttribute("aria-hidden", "false")
    } else {
      this.unlockBodyScroll()
      this.overlayTarget.setAttribute("aria-hidden", "true")
      this.sidebarTarget.setAttribute("aria-hidden", "true")
      this.returnFocusToToggle()
    }
    this.updateToggleAria(opening)
  }

  restoreState() {
    if (this._isMobile) {
      this.sidebarTarget.setAttribute("aria-hidden", "true")
      return
    }

    const collapsed = localStorage.getItem(STORAGE_KEY) === "1"
    if (collapsed) {
      document.body.classList.add("sidebar-collapsed")
    }
    this.updateToggleAria(!collapsed)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && document.body.classList.contains("sidebar-open")) {
      this.close()
    }
  }

  updateToggleAria(expanded) {
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", expanded)
  }

  returnFocusToToggle() {
    if (this.hasToggleTarget) this.toggleTarget.focus()
  }

  lockBodyScroll() {
    document.body.style.overflow = "hidden"
  }

  unlockBodyScroll() {
    document.body.style.overflow = ""
  }
}
