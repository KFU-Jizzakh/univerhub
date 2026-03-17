import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["building", "floor", "number"]
  static values = { url: String }

  async updateNumber() {
    const buildingId = this.buildingTarget.value
    const floor = this.floorTarget.value

    if (!buildingId || !floor) return

    try {
      const params = new URLSearchParams({ building_id: buildingId, floor: floor })
      const response = await fetch(`${this.urlValue}?${params}`)
      if (response.ok) {
        const data = await response.json()
        if (data.number && !this.numberTarget.value) {
          this.numberTarget.value = data.number
        }
      }
    } catch (e) {
      // ignore network errors
    }
  }
}
