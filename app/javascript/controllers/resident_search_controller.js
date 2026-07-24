import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300
const MIN_CHARS = 2
const MAX_RESULTS = 8

export default class extends Controller {
  static targets = ["input", "hidden", "results", "selected", "selectedWrapper"]

  connect() {
    this._timer = null
    this._selectedIndex = -1
    this.boundHandleClickOutside = this._handleClickOutside.bind(this)
    document.addEventListener("click", this.boundHandleClickOutside)
  }

  disconnect() {
    clearTimeout(this._timer)
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  search() {
    clearTimeout(this._timer)
    const value = this.inputTarget.value.trim()
    this._selectedIndex = -1

    if (value.length < MIN_CHARS) {
      this._hideResults()
      return
    }

    this._timer = setTimeout(() => {
      const params = new URLSearchParams({ query: value, format: "json" })
      fetch(`/dormitory/residents?${params}`, {
        headers: { Accept: "application/json" }
      })
        .then(response => response.json())
        .then(data => this._renderResults(data))
        .catch(() => this._hideResults())
    }, DEBOUNCE_MS)
  }

  select(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    const resident = this._residents[idx]
    if (!resident) return
    this._applySelection(resident)
  }

  clear() {
    this.hiddenTarget.value = ""
    this.inputTarget.value = ""
    this.selectedTarget.textContent = ""
    this.inputTarget.parentElement.classList.remove("d-none")
    this.selectedWrapperTarget.classList.add("d-none")
    this.inputTarget.focus()
    this._hideResults()
  }

  navigateResults(event) {
    if (!this.resultsTarget.classList.contains("d-none")) {
      if (event.key === "ArrowDown") {
        event.preventDefault()
        this._selectedIndex = Math.min(this._selectedIndex + 1, this._residents.length - 1)
        this._highlightSelected()
      } else if (event.key === "ArrowUp") {
        event.preventDefault()
        this._selectedIndex = Math.max(this._selectedIndex - 1, 0)
        this._highlightSelected()
      } else if (event.key === "Enter") {
        event.preventDefault()
        if (this._selectedIndex >= 0 && this._residents[this._selectedIndex]) {
          this._applySelection(this._residents[this._selectedIndex])
        }
      } else if (event.key === "Escape") {
        this._hideResults()
      }
    }
  }

  _applySelection(resident) {
    this.hiddenTarget.value = resident.id
    this.selectedTarget.textContent = resident.full_name
    this.inputTarget.parentElement.classList.add("d-none")
    this.selectedWrapperTarget.classList.remove("d-none")
    this._hideResults()
  }

  _renderResults(residents) {
    this._residents = residents ? residents.slice(0, MAX_RESULTS) : []

    if (this._residents.length === 0) {
      this._hideResults()
      return
    }

    let html = ""
    this._residents.forEach((r, idx) => {
      const room = r.room_number ? ` &mdash; ${this._esc(r.room_number)}` : ""
      html += `<button type="button" class="resident-search-item"
        data-index="${idx}"
        data-action="click->resident-search#select">
        ${this._esc(r.full_name)}${room}
      </button>`
    })

    this.resultsTarget.innerHTML = html
    this.resultsTarget.classList.remove("d-none")
  }

  _highlightSelected() {
    const items = this.resultsTarget.querySelectorAll(".resident-search-item")
    items.forEach((item, idx) => {
      item.classList.toggle("resident-search-item--active", idx === this._selectedIndex)
    })
  }

  _hideResults() {
    this.resultsTarget.classList.add("d-none")
    this.resultsTarget.innerHTML = ""
    this._residents = []
    this._selectedIndex = -1
  }

  _handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this._hideResults()
    }
  }

  _esc(str) {
    const map = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }
    return String(str).replace(/[&<>"']/g, c => map[c])
  }
}
