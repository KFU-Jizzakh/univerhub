import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300

export default class extends Controller {
  static targets = ["input", "warning"]

  connect() {
    this._timer = null
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  check() {
    clearTimeout(this._timer)
    const value = this.inputTarget.value.trim()
    if (value.length < 1) {
      this._hideWarning()
      return
    }

    this._timer = setTimeout(() => {
      const params = new URLSearchParams({ number: value })
      const url = `/dormitory/residents/check_ticket?${params}`

      fetch(url, { headers: { Accept: "application/json" } })
        .then(response => response.json())
        .then(data => {
          if (data.found) {
            const residentId = this.inputTarget.dataset.residentId
            if (residentId && String(data.id) === String(residentId)) {
              this._hideWarning()
              return
            }
            const link = `<a href="/dormitory/residents/${data.id}">${data.full_name}</a>`
            this.warningTarget.innerHTML = `${this._warningText()}: ${link}`
            this.warningTarget.classList.remove("d-none")
          } else {
            this._hideWarning()
          }
        })
    }, DEBOUNCE_MS)
  }

  _hideWarning() {
    this.warningTarget.classList.add("d-none")
    this.warningTarget.innerHTML = ""
  }

  _warningText() {
    return this.element.dataset.warningText || "Проживающий с таким номером студбилета уже существует"
  }
}
