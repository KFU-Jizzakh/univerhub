import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["building", "room", "forceGroup", "forceInput", "loading", "bed"]
  static values = { residentGender: String, residentCourse: String, isAdmin: String, roomPrompt: String, roomTemplate: String, bedPrompt: String, currentRoomData: String, currentBedLabel: String }

  connect() {
    this._updateRooms({ preserveCurrent: true })
  }

  changeBuilding() {
    this._updateRooms({ preserveCurrent: false })
  }

  checkBuilding() {
    if (!this.buildingTarget.value) {
      this.buildingTarget.focus()
    }
  }

  _updateRooms({ preserveCurrent = false } = {}) {
    const buildingId = this.buildingTarget.value
    const gender = this.residentGenderValue
    const course = this.residentCourseValue

    if (!buildingId) {
      this._setRoomOptions([])
      this._setBedOptions([])
      this._hideForce()
      return
    }

    this._showLoading()

    const params = new URLSearchParams({ building_id: buildingId, gender: gender })
    if (course) params.append("course", course)
    const url = `/dormitory/rooms/available?${params}`

    fetch(url, { headers: { Accept: "application/json" } })
      .then(response => response.json())
      .then(rooms => {
        this._setRoomOptions(rooms)
        if (preserveCurrent && this.currentRoomDataValue) {
          this._applyCurrentSelection()
        } else {
          this._setBedOptions([])
        }
        this._hideLoading()
      })
      .catch((error) => { this._hideLoading(); console.error("Failed to load rooms:", error) })
  }

  changeRoom() {
    const selected = this.roomTarget.options[this.roomTarget.selectedIndex]
    if (!selected || !selected.value) {
      this._setBedOptions([])
      this._hideForce()
      return
    }

    this._setBedOptions(selected.dataset.bedLabels ? JSON.parse(selected.dataset.bedLabels) : [])

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

    rooms.forEach(room => this.roomTarget.appendChild(this._roomOption(room)))

    this._hideForce()
  }

  _roomOption(room) {
    const option = document.createElement("option")
    option.value = room.id
    const template = this.roomTemplateValue
      .replace("{floor}", room.floor)
      .replace("{slots}", room.available_slots)
    option.textContent = `${room.number} ${template}`
    option.dataset.availableSlots = room.available_slots
    option.dataset.status = room.status
    option.dataset.bedLabels = JSON.stringify(room.free_bed_labels)
    return option
  }

  _applyCurrentSelection() {
    let current
    try {
      current = JSON.parse(this.currentRoomDataValue)
    } catch {
      return
    }
    if (!current || !current.id) return

    let option = this.roomTarget.querySelector(`option[value="${current.id}"]`)
    if (!option) {
      option = this._roomOption(current)
      this.roomTarget.appendChild(option)
    }
    this.roomTarget.value = current.id

    const beds = current.free_bed_labels.slice()
    if (this.currentBedLabelValue && !beds.includes(this.currentBedLabelValue)) {
      beds.push(this.currentBedLabelValue)
    }
    if (Array.isArray(current.bed_labels)) {
      beds.sort((a, b) => current.bed_labels.indexOf(a) - current.bed_labels.indexOf(b))
    }

    this._setBedOptions(beds)
    if (this.currentBedLabelValue && this.hasBedTarget) {
      this.bedTarget.value = this.currentBedLabelValue
    }
    this._hideForce()
  }

  _setBedOptions(beds) {
    if (!this.hasBedTarget) return

    this.bedTarget.innerHTML = ""
    if (this.hasBedPromptValue) {
      const promptOption = document.createElement("option")
      promptOption.value = ""
      promptOption.textContent = this.bedPromptValue
      this.bedTarget.appendChild(promptOption)
    }
    beds.forEach(bed => {
      const option = document.createElement("option")
      option.value = bed
      option.textContent = bed
      this.bedTarget.appendChild(option)
    })
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
