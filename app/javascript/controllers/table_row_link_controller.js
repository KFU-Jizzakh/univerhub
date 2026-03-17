import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate(event) {
    const row = event.currentTarget
    const url = row.dataset.url
    if (!url) return

    if (event.target.closest("a, button, input, select, label, form")) return

    Turbo.visit(url)
  }

  navigateByKey(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    const row = event.currentTarget
    const url = row.dataset.url
    if (!url) return

    event.preventDefault()
    Turbo.visit(url)
  }
}
