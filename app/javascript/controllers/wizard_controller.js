import { Controller } from "@hotwired/stimulus"

const ESCAPE_MAP = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, c => ESCAPE_MAP[c])
}

export default class extends Controller {
  static targets = ["step", "buildingSelect", "residentList", "nextBtn"]

  connect() {
    this.currentStep = 1
    this.showStep(this.currentStep)
  }

  nextStep() {
    if (this.currentStep === 1) {
      if (!this.buildingSelectTarget.value) {
        alert(this.buildingSelectTarget.dataset.prompt || "Выберите здание")
        this.buildingSelectTarget.focus()
        return
      }
    }

    if (this.currentStep === 2) {
      const selected = this._selectedResidents()
      if (selected.length === 0) {
        alert("Выберите хотя бы одного проживающего")
        return
      }
    }

    if (this.currentStep < 3) {
      this.currentStep++
      this.showStep(this.currentStep)
    }
  }

  prevStep() {
    if (this.currentStep > 1) {
      this.currentStep--
      this.showStep(this.currentStep)
    }
  }

  loadResidents() {
    const buildingId = this.buildingSelectTarget.value
    if (!buildingId) return

    const params = new URLSearchParams({ building_id: buildingId, format: "json" })
    fetch(`/dormitory/residents?${params}`, {
      headers: { Accept: "application/json" }
    })
      .then(response => response.json())
      .then(data => this._renderResidents(data))
      .catch(() => {
        this.residentListTarget.innerHTML = "<p class='text-danger'>Ошибка загрузки данных</p>"
      })
  }

  _renderResidents(residents) {
    if (!residents || residents.length === 0) {
      this.residentListTarget.innerHTML = "<p class='text-muted'>Нет проживающих в выбранном здании</p>"
      return
    }

    let html = '<div class="d-flex justify-content-between align-items-center mb-2">'
    html += '<span class="small text-muted" id="selection-count">Выбрано: 0</span>'
    html += '<div>'
    html += '<button type="button" class="btn btn-sm btn-link" data-action="wizard#selectAll">Выбрать всех</button>'
    html += '<button type="button" class="btn btn-sm btn-link" data-action="wizard#deselectAll">Снять всех</button>'
    html += '</div></div>'

    html += '<div class="table-responsive"><table class="table table-hover table-sm mb-0">'
    html += '<thead class="table-light"><tr><th></th><th>ФИО</th><th>Комната</th><th>Статус</th></tr></thead>'
    html += '<tbody>'

    residents.forEach(r => {
      html += '<tr>'
      html += `<td><input type="checkbox" name="resident_ids[]" value="${escapeHtml(r.id)}" class="form-check-input resident-checkbox" data-action="change->wizard#updateCount"></td>`
      html += `<td>${escapeHtml(r.full_name || `${r.last_name} ${r.first_name}`)}</td>`
      html += `<td>${escapeHtml(r.room_number || "—")}</td>`
      html += `<td>${escapeHtml(r.status || "—")}</td>`
      html += '</tr>'
    })

    html += '</tbody></table></div>'
    this.residentListTarget.innerHTML = html
  }

  selectAll() {
    const checkboxes = this.residentListTarget.querySelectorAll(".resident-checkbox")
    checkboxes.forEach(cb => cb.checked = true)
    this._updateCount()
  }

  deselectAll() {
    const checkboxes = this.residentListTarget.querySelectorAll(".resident-checkbox")
    checkboxes.forEach(cb => cb.checked = false)
    this._updateCount()
  }

  updateCount() {
    this._updateCount()
  }

  _updateCount() {
    const count = this._selectedResidents().length
    const el = this.residentListTarget.querySelector("#selection-count")
    if (el) el.textContent = `Выбрано: ${count}`
  }

  _selectedResidents() {
    const checkboxes = this.residentListTarget.querySelectorAll(".resident-checkbox:checked")
    return Array.from(checkboxes)
  }

  showStep(step) {
    this.stepTargets.forEach(el => {
      const elStep = parseInt(el.dataset.step, 10)
      if (elStep === step) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }
}
