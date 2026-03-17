import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "previewContainer", "removeCheckbox"]

  connect() {
    this._previewHandler = this.preview.bind(this)
    this.inputTarget.addEventListener("change", this._previewHandler)
    if (this.hasPreviewTarget && this.previewTarget.dataset.originalSrc) {
      this._originalSrc = this.previewTarget.dataset.originalSrc
    }
  }

  disconnect() {
    this.inputTarget.removeEventListener("change", this._previewHandler)
  }

  preview(event) {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      if (this.hasPreviewTarget) {
        this.previewTarget.src = e.target.result
        this.previewTarget.classList.remove("d-none")
      }
      if (this.hasPreviewContainerTarget) {
        this.previewContainerTarget.classList.remove("d-none")
      }
      if (this.hasRemoveCheckboxTarget) {
        this.removeCheckboxTarget.checked = false
      }
    }
    reader.readAsDataURL(file)
  }

  remove(event) {
    if (event.target.checked) {
      if (this.hasPreviewTarget) {
        this.previewTarget.classList.add("d-none")
        this.previewTarget.src = ""
      }
      this.inputTarget.value = ""
    } else {
      if (this.hasPreviewTarget && this._originalSrc) {
        this.previewTarget.src = this._originalSrc
        this.previewTarget.classList.remove("d-none")
      }
    }
  }
}
