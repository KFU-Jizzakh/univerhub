import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["building", "room", "forceGroup", "forceInput", "loading"]
  static values = { residentGender: String, isAdmin: String, roomPrompt: String, roomTemplate: String }

  connect() {
    this._updateRooms()
  }

  changeBuilding() {
    this._updateRooms()
  }

  checkBuilding() {
    if (!this.buildingTarget.value) {
      this.buildingTarget.focus()
    }
  }

  _updateRooms() {
    const buildingId = this.buildingTarget.value
    const gender = this.residentGenderValue

    if (!buildingId) {
      this._setRoomOptions([])
      this._hideForce()
      return
    }

    this._showLoading()

    const params = new URLSearchParams({ building_id: buildingId, gender: gender })
    const url = `/dormitory/rooms/available?${params}`

    fetch(url, { headers: { Accept: "application/json" } })
      .then(response => response.json())
      .then(rooms => {
        this._setRoomOptions(rooms)
        this._hideLoading()
      })
      .catch(() => this._hideLoading())
  }

  changeRoom() {
    const selected = this.roomTarget.options[this.roomTarget.selectedIndex]
    if (!selected || !selected.value) {
      this._hideForce()
      return
    }

    const available = parseInt(selected.dataset.availableSlots || "0", 10)
    const full = available <= 0

    if (full && this._isAdmin()) {
      this._showForce()
    } else {
      this._hideForce()
    }
  }

  _setRoomOptions(rooms) {
    const promptOption = document.createElement("option")
    promptOption.value = ""
    promptOption.textContent = this.roomPromptValue

    this.roomTarget.innerHTML = ""
    this.roomTarget.appendChild(promptOption)

    rooms.forEach(room => {
      const option = document.createElement("option")
      option.value = room.id
      const template = this.roomTemplateValue
        .replace("{floor}", room.floor)
        .replace("{slots}", room.available_slots)
      option.textContent = `${room.number} ${template}`
      option.dataset.availableSlots = room.available_slots
      option.dataset.status = room.status
      this.roomTarget.appendChild(option)
    })

    this._hideForce()
  }

  _showForce() {
    if (this.hasForceGroupTarget) {
      this.forceGroupTarget.classList.remove("d-none")
    }
  }

  _hideForce() {
    if (this.hasForceGroupTarget && this.hasForceInputTarget) {
      this.forceGroupTarget.classList.add("d-none")
      this.forceInputTarget.checked = false
    }
  }

  _showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("d-none")
    }
  }

  _hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("d-none")
    }
  }

  _isAdmin() {
    return this.isAdminValue === "true"
  }
}
