import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "zone", "list", "placeholder"]

  connect() {
    this.files = []
    this._dragOver = this.handleDragOver.bind(this)
    this._dragLeave = this.handleDragLeave.bind(this)
    this._drop = this.handleDrop.bind(this)
    this._click = this.handleClick.bind(this)
    this._change = this.handleInputChange.bind(this)
    this.zoneTarget.addEventListener("dragover", this._dragOver)
    this.zoneTarget.addEventListener("dragleave", this._dragLeave)
    this.zoneTarget.addEventListener("drop", this._drop)
    this.zoneTarget.addEventListener("click", this._click)
    this.inputTarget.addEventListener("change", this._change)
  }

  disconnect() {
    this.zoneTarget.removeEventListener("dragover", this._dragOver)
    this.zoneTarget.removeEventListener("dragleave", this._dragLeave)
    this.zoneTarget.removeEventListener("drop", this._drop)
    this.zoneTarget.removeEventListener("click", this._click)
    this.inputTarget.removeEventListener("change", this._change)
  }

  handleDragOver(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("drop-zone--active")
  }

  handleDragLeave() {
    this.zoneTarget.classList.remove("drop-zone--active")
  }

  handleDrop(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove("drop-zone--active")
    const transferredFiles = Array.from(event.dataTransfer.files)
    this.addFiles(transferredFiles)
  }

  handleClick(event) {
    if (event.target.closest(".drop-zone-remove")) return
    this.inputTarget.click()
  }

  handleInputChange() {
    const transferredFiles = Array.from(this.inputTarget.files)
    this.addFiles(transferredFiles)
  }

  addFiles(newFiles) {
    if (!this.inputTarget.multiple) this.files = []

    const accept = (this.inputTarget.accept || "").split(",").map((s) => s.trim()).filter(Boolean)
    const maxSize = parseInt(this.data.get("maxSize") || "10485760", 10)

    newFiles.forEach((file) => {
      if (accept.length > 0 && !accept.some((type) => file.type === type || file.name.endsWith(type.replace("*", "")))) {
        this.showFileError(file.name, this.data.get("formatError") || "Неподдерживаемый формат")
        return
      }
      if (file.size > maxSize) {
        this.showFileError(file.name, this.data.get("sizeError") || "Файл слишком большой")
        return
      }
      this.files.push(file)
    })

    this.renderList()
  }

  removeFile(event) {
    event.stopPropagation()
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this.files.splice(index, 1)
    this.renderList()
  }

  renderList() {
    if (this.files.length > 0) {
      if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("d-none")
      this.listTarget.innerHTML = this.files.map((file, i) => `
        <div class="drop-zone-file">
          <i class="bi ${this.fileIcon(file)} drop-zone-file-icon"></i>
          <span class="drop-zone-file-name">${this._escapeHtml(file.name)}</span>
          <span class="drop-zone-file-size">${this.formatSize(file.size)}</span>
          <button type="button" class="drop-zone-remove" data-index="${i}" data-action="click->drop-zone#removeFile" aria-label="${this._removeLabel()}">&times;</button>
        </div>
      `).join("")
    } else {
      if (this.hasPlaceholderTarget) this.placeholderTarget.classList.remove("d-none")
      this.listTarget.innerHTML = ""
    }

    if (this.inputTarget.multiple) {
      const dt = new DataTransfer()
      this.files.forEach((f) => dt.items.add(f))
      this.inputTarget.files = dt.files
    } else if (this.files.length === 0) {
      this.inputTarget.value = ""
    } else {
      const dt = new DataTransfer()
      dt.items.add(this.files[0])
      this.inputTarget.files = dt.files
    }
  }

  showFileError(name, message) {
    const errorEl = document.createElement("div")
    errorEl.classList.add("drop-zone-error")
    errorEl.textContent = `${name}: ${message}`
    this.listTarget.appendChild(errorEl)
    setTimeout(() => errorEl.remove(), 4000)
  }

  fileIcon(file) {
    const type = file.type || ""
    if (type === "application/pdf") return "bi-filetype-pdf"
    if (type.startsWith("image/")) return "bi-filetype-jpg"
    return "bi-file-earmark"
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} ${this._unitBytes()}`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} ${this._unitKb()}`
    return `${(bytes / 1048576).toFixed(1)} ${this._unitMb()}`
  }

  _escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }

  _removeLabel() {
    return this.data.get("removeLabel") || "Удалить файл"
  }

  _unitBytes() {
    return this.data.get("unitBytes") || "Б"
  }

  _unitKb() {
    return this.data.get("unitKb") || "КБ"
  }

  _unitMb() {
    return this.data.get("unitMb") || "МБ"
  }
}
