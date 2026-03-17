import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._submit = this.submit.bind(this)
    this.element.querySelectorAll("select").forEach((select) => {
      select.addEventListener("change", this._submit)
    })
  }

  disconnect() {
    this.element.querySelectorAll("select").forEach((select) => {
      select.removeEventListener("change", this._submit)
    })
  }

  submit() {
    this.element.requestSubmit()
  }
}
