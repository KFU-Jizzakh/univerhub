import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "building", "floor", "startNumber", "endNumber", "defaultCapacity", "defaultGender",
    "tableCard", "tableBody", "hiddenFields", "countBadge", "submitBtn"
  ]
  static values = { url: String }

  connect() {
    const roomsData = this.element.dataset.batchRoomsRoomsData
    if (roomsData) {
      try {
        const parsed = JSON.parse(roomsData)
        if (parsed.length > 0) {
          this.buildTable(parsed)
        }
      } catch (e) { /* ignore parse errors */ }
    }

    const building = this.element.dataset.batchRoomsBuilding
    const floor = this.element.dataset.batchRoomsFloor
    if (building) this.buildingTarget.value = building
    if (floor) this.floorTarget.value = floor
  }

  async updateSuggestedNumber() {
    const buildingId = this.buildingTarget.value
    const floor = this.floorTarget.value
    if (!buildingId || !floor) return

    try {
      const params = new URLSearchParams({ building_id: buildingId, floor: floor })
      const response = await fetch(`${this.urlValue}?${params}`)
      if (response.ok) {
        const data = await response.json()
        if (data.number && !this.startNumberTarget.value) {
          this.startNumberTarget.value = data.number
        }
      }
    } catch (e) { /* ignore network errors */ }
  }

  generate() {
    const buildingId = this.buildingTarget.value
    const floor = this.floorTarget.value
    const start = parseInt(this.startNumberTarget.value.trim(), 10)
    const end = parseInt(this.endNumberTarget.value.trim(), 10)
    const defaultCapacity = this.defaultCapacityTarget.value
    const defaultGender = this.defaultGenderTarget.value

    if (!buildingId || !floor || isNaN(start) || isNaN(end)) {
      return
    }

    if (start > end) {
      return
    }

    const count = end - start + 1
    if (count > 200 && !confirm(this.tooManyRoomsLabel.replace("%{count}", count))) return

    const rooms = []
    for (let i = start; i <= end; i++) {
      rooms.push({
        number: String(i),
        capacity: defaultCapacity || "1",
        gender_restriction: defaultGender || ""
      })
    }

    this.buildTable(rooms)
  }

  buildTable(rooms) {
    this.tableBodyTarget.innerHTML = ""
    rooms.forEach((room, index) => {
      const tr = document.createElement("tr")
      tr.innerHTML = this.rowHtml(room, index)
      this.tableBodyTarget.appendChild(tr)
    })
    this.rebuildHiddenFields()
    this.tableCardTarget.classList.remove("d-none")
    this.updateCount(rooms.length)
  }

  rowHtml(room, index) {
    const esc = this.esc
    const genderNone = this.genderNoneLabel
    const genderMale = this.genderMaleLabel
    const genderFemale = this.genderFemaleLabel
    return `
      <td><input type="text" class="form-control form-control-sm" value="${esc(room.number)}"
            data-action="input->batch-rooms#onRowChange" data-index="${index}" data-field="number" required></td>
      <td><input type="number" class="form-control form-control-sm" value="${esc(room.capacity)}" min="1"
            data-action="input->batch-rooms#onRowChange" data-index="${index}" data-field="capacity" required></td>
      <td>
        <select class="form-select form-select-sm" data-action="change->batch-rooms#onRowChange" data-index="${index}" data-field="gender_restriction">
          <option value="">${esc(genderNone)}</option>
          <option value="male" ${room.gender_restriction === "male" ? "selected" : ""}>${esc(genderMale)}</option>
          <option value="female" ${room.gender_restriction === "female" ? "selected" : ""}>${esc(genderFemale)}</option>
        </select>
      </td>
      <td class="text-center">
        <button type="button" class="btn btn-sm btn-outline-danger" data-action="batch-rooms#deleteRow" data-index="${index}">&times;</button>
      </td>`
  }

  onRowChange(event) {
    this.rebuildHiddenFields()
  }

  deleteRow(event) {
    event.target.closest("tr").remove()
    this.rebuildHiddenFields()
    this.updateCount(this.tableBodyTarget.querySelectorAll("tr").length)
    if (this.tableBodyTarget.querySelectorAll("tr").length === 0) {
      this.tableCardTarget.classList.add("d-none")
    }
  }

  rebuildHiddenFields() {
    const buildingId = this.buildingTarget.value
    const floor = this.floorTarget.value
    this.hiddenFieldsTarget.innerHTML = ""

    this.tableBodyTarget.querySelectorAll("tr").forEach((tr) => {
      const num = tr.querySelector("[data-field='number']").value.trim()
      const cap = tr.querySelector("[data-field='capacity']").value.trim()
      const gen = tr.querySelector("[data-field='gender_restriction']").value
      this.hiddenFieldsTarget.innerHTML += `
        <input type="hidden" name="rooms[][building_id]" value="${this.esc(buildingId)}">
        <input type="hidden" name="rooms[][floor]" value="${this.esc(floor)}">
        <input type="hidden" name="rooms[][number]" value="${this.esc(num)}">
        <input type="hidden" name="rooms[][capacity]" value="${this.esc(cap)}">
        <input type="hidden" name="rooms[][gender_restriction]" value="${this.esc(gen)}">
      `
    })
  }

  updateCount(count) {
    if (this.hasCountBadgeTarget) this.countBadgeTarget.textContent = count
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.value = this.submitLabel.replace("%{count}", count)
    }
  }

  esc(str) {
    const div = document.createElement("div")
    div.appendChild(document.createTextNode(String(str || "")))
    return div.innerHTML
  }

  get genderNoneLabel() { return this.element.dataset.batchRoomsGenderNoneLabel || "Без ограничений" }
  get genderMaleLabel() { return this.element.dataset.batchRoomsGenderMaleLabel || "Мужской" }
  get genderFemaleLabel() { return this.element.dataset.batchRoomsGenderFemaleLabel || "Женский" }
  get tooManyRoomsLabel() { return this.element.dataset.batchRoomsTooManyLabel || "Будет создано %{count} комнат. Продолжить?" }
  get submitLabel() { return this.element.dataset.batchRoomsSubmitLabel || "Создать %{count} комнат" }
}
