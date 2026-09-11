import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._submit = this.submit.bind(this)
    this.fields().forEach((field) => {
      field.addEventListener("change", this._submit)
    })
  }

  disconnect() {
    this.fields().forEach((field) => {
      field.removeEventListener("change", this._submit)
    })
  }

  fields() {
    return this.element.querySelectorAll("select, input[type=checkbox]")
  }

  submit() {
    this.element.requestSubmit()
  }
}
