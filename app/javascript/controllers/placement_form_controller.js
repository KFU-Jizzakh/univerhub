import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "toggle", "fields", "preview", "gender", "course",
    "building", "room", "bed"
  ]
  static values = {
    previewUrl: String,
    roomsUrl: String,
    bedsUrl: String,
    roomPrompt: String,
    bedPrompt: String,
    previewTemplate: String,
    noRoom: String,
    loadError: String,
    manual: Boolean
  }

  connect() {
    this.manualSelection = this.manualValue
    this.toggle()
    if (this.hasToggleTarget && this.hasGenderTarget && this.hasCourseTarget &&
        (!this.hasRoomTarget || !this.roomTarget.value)) {
      this.updateSuggestion()
    }
  }

  toggle() {
    if (!this.hasToggleTarget || !this.hasFieldsTarget) return

    const enabled = this.toggleTarget.checked
    this.fieldsTarget.classList.toggle("d-none", !enabled)
    this.fieldsTarget.querySelectorAll("input, select, textarea").forEach((field) => {
      field.disabled = !enabled
    })
  }

  markManual() {
    this.manualSelection = true
  }

  async updateSuggestion() {
    if (!this.hasToggleTarget || !this.hasGenderTarget || !this.hasCourseTarget) return

    const params = new URLSearchParams({
      gender: this.genderTarget.value,
      course: this.courseTarget.value
    })

    let data
    try {
      const response = await fetch(`${this.previewUrlValue}?${params}`, { headers: { Accept: "application/json" } })
      data = await response.json()
    } catch (error) {
      console.error("Failed to load preview:", error)
      if (this.hasPreviewTarget) this.previewTarget.textContent = this.loadErrorValue
      return
    }

    if (!data.room_id) {
      if (this.hasRoomTarget) this._setRoomOptions([])
      if (this.hasBedTarget) this._setBedOptions([])
      if (this.hasPreviewTarget) this.previewTarget.textContent = this.noRoomValue
      return
    }

    const buildingSelected = this.hasBuildingTarget && this.buildingTarget.value

    if (this.manualSelection && buildingSelected) {
      await this.loadRooms(null, { preserve: true })
      if (this.hasPreviewTarget) {
        this.previewTarget.textContent = this.roomTarget.options.length > 1 ? "" : this.noRoomValue
      }
      return
    }

    if (this.hasBuildingTarget && String(data.building_id) !== this.buildingTarget.value) {
      this.buildingTarget.value = data.building_id
    }

    await this.loadRooms(null, { preselectRoomId: String(data.room_id), preselectBed: data.bed_label || null })
    if (this.hasPreviewTarget) {
      this.previewTarget.textContent = this.previewTemplateValue
        .replace("{building}", data.building)
        .replace("{room}", data.room_number)
        .replace("{bed}", data.bed_label || "—")
    }
  }

  async loadRooms(trigger, { preselectRoomId = null, preselectBed = null, preserve = false } = {}) {
    if (!this.hasBuildingTarget || !this.hasRoomTarget) return
    if (trigger instanceof Event) this.manualSelection = true

    const previousRoom = this.roomTarget.value
    const previousBed = this.bedTarget.value
    const buildingId = this.buildingTarget.value

    if (!buildingId) {
      this._setRoomOptions([])
      this._setBedOptions([])
      return
    }

    const params = new URLSearchParams({
      building_id: buildingId,
      gender: this.genderTarget.value,
      course: this.courseTarget.value
    })

    try {
      const response = await fetch(`${this.roomsUrlValue}?${params}`, { headers: { Accept: "application/json" } })
      const rooms = await response.json()
      this._setRoomOptions(rooms)
      if (preselectRoomId && rooms.some(room => String(room.id) === preselectRoomId)) {
        this.roomTarget.value = preselectRoomId
        await this.changeRoom(null, { preselectBed })
      } else if (preserve && previousRoom && rooms.some(room => String(room.id) === previousRoom)) {
        this.roomTarget.value = previousRoom
        await this.changeRoom(null, { preserveBed: previousBed })
      } else {
        this._setBedOptions([])
      }
    } catch (error) {
      console.error("Failed to load rooms:", error)
      this._setErrorOption(this.roomTarget)
    }
  }

  async changeRoom(trigger, { preselectBed = null, preserveBed = null } = {}) {
    if (!this.hasRoomTarget || !this.hasBedTarget) return
    if (trigger instanceof Event) this.manualSelection = true

    const roomId = this.roomTarget.value
    if (!roomId) {
      this._setBedOptions([])
      return
    }

    try {
      const response = await fetch(`${this.bedsUrlValue}?id=${roomId}`, { headers: { Accept: "application/json" } })
      const beds = await response.json()
      this._setBedOptions(beds)
      if (preselectBed && beds.includes(preselectBed)) {
        this.bedTarget.value = preselectBed
      } else if (preserveBed && beds.includes(preserveBed)) {
        this.bedTarget.value = preserveBed
      }
    } catch (error) {
      console.error("Failed to load beds:", error)
      this._setErrorOption(this.bedTarget)
    }
  }

  _setRoomOptions(rooms) {
    this.roomTarget.innerHTML = ""
    this.roomTarget.appendChild(this._promptOption(this.roomPromptValue))
    rooms.forEach(room => {
      const option = document.createElement("option")
      option.value = room.id
      option.textContent = room.free_bed_labels.length
        ? `${room.number} (${room.free_bed_labels.join(", ")})`
        : room.number
      this.roomTarget.appendChild(option)
    })
  }

  _setBedOptions(beds) {
    this.bedTarget.innerHTML = ""
    this.bedTarget.appendChild(this._promptOption(this.bedPromptValue))
    beds.forEach(bed => {
      const option = document.createElement("option")
      option.value = bed
      option.textContent = bed
      this.bedTarget.appendChild(option)
    })
  }

  _promptOption(text) {
    const option = document.createElement("option")
    option.value = ""
    option.textContent = text
    return option
  }

  _setErrorOption(select) {
    select.innerHTML = ""
    select.appendChild(this._promptOption(this.loadErrorValue))
  }
}