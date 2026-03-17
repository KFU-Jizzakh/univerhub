import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "comment", "hint"]

  connect() {
    this.changeReason()
  }

  changeReason() {
    if (this.selectTarget.value === "other") {
      this.hintTarget.classList.remove("d-none")
    } else {
      this.hintTarget.classList.add("d-none")
    }
  }
}
