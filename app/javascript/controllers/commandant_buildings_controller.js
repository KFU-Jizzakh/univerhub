import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "fieldset" ]

  connect() {
    this.toggleBuildings()
  }

  toggleBuildings() {
    if (!this.hasFieldsetTarget) return

    const commandantChecked = this.element.querySelectorAll(
      'input[data-role-name="dormitory.commandant"]:checked'
    ).length > 0

    this.fieldsetTarget.classList.toggle("d-none", !commandantChecked)
  }
}
