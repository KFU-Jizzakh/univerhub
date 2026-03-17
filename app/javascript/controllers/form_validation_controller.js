import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "passwordConfirmation", "feedback", "gradeInput"]

  connect() {
    this.element.noValidate = true
    this._submit = this.handleSubmit.bind(this)
    this.element.addEventListener("submit", this._submit)

    if (this.hasPasswordTarget) {
      this._checkPassword = this.checkPassword.bind(this)
      this.passwordTarget.addEventListener("input", this._checkPassword)
    }
    if (this.hasPasswordConfirmationTarget) {
      this._checkPasswordMatch = this.checkPasswordMatch.bind(this)
      this.passwordConfirmationTarget.addEventListener("input", this._checkPasswordMatch)
    }
    if (this.hasGradeInputTarget) {
      this._checkGrade = this.checkGrade.bind(this)
      this.gradeInputTarget.addEventListener("input", this._checkGrade)
    }
  }

  disconnect() {
    this.element.removeEventListener("submit", this._submit)

    if (this.hasPasswordTarget && this._checkPassword) {
      this.passwordTarget.removeEventListener("input", this._checkPassword)
    }
    if (this.hasPasswordConfirmationTarget && this._checkPasswordMatch) {
      this.passwordConfirmationTarget.removeEventListener("input", this._checkPasswordMatch)
    }
    if (this.hasGradeInputTarget && this._checkGrade) {
      this.gradeInputTarget.removeEventListener("input", this._checkGrade)
    }
  }

  handleSubmit(event) {
    let valid = true

    this.element.querySelectorAll("[required]").forEach((input) => {
      if (!input.checkValidity()) {
        input.classList.add("is-invalid")
        input.classList.remove("is-valid")
        valid = false
      }
    })

    if (this.hasPasswordConfirmationTarget) {
      if (this.passwordTarget.value !== this.passwordConfirmationTarget.value) {
        this.showFeedback(this.passwordConfirmationTarget, this.data.get("mismatchMessage") || "Пароли не совпадают")
        valid = false
      }
    }

    if (this.hasGradeInputTarget) {
      if (!this.validateGrade()) {
        valid = false
      }
    }

    if (!valid) {
      event.preventDefault()
    }
  }

  checkPassword() {
    const input = this.passwordTarget
    const min = parseInt(input.dataset.minLength || "6", 10)
    if (input.value.length === 0) {
      this.clearFeedback(input)
    } else if (input.value.length < min) {
      this.showFeedback(input, this.data.get("minMessage") || `Минимум ${min} символов`)
    } else {
      this.markValid(input)
    }
    if (this.hasPasswordConfirmationTarget && this.passwordConfirmationTarget.value.length > 0) {
      this.checkPasswordMatch()
    }
  }

  checkPasswordMatch() {
    const pwd = this.passwordTarget.value
    const confirm = this.passwordConfirmationTarget.value
    if (confirm.length === 0) {
      this.clearFeedback(this.passwordConfirmationTarget)
    } else if (pwd !== confirm) {
      this.showFeedback(this.passwordConfirmationTarget, this.data.get("mismatchMessage") || "Пароли не совпадают")
    } else {
      this.markValid(this.passwordConfirmationTarget)
    }
  }

  checkGrade() {
    this.validateGrade()
  }

  validateGrade() {
    const input = this.gradeInputTarget
    const val = parseFloat(input.value)
    const min = parseFloat(input.min || 0)
    const max = parseFloat(input.max)

    if (input.value === "") {
      this.clearFeedback(input)
      return true
    }

    if (isNaN(val)) {
      this.showFeedback(input, this.data.get("gradeNotNumberMessage") || "Введите число")
      return false
    }

    if (val < min) {
      this.showFeedback(input, this.data.get("gradeMinMessage") || `Минимальное значение: ${min}`)
      return false
    }

    if (!isNaN(max) && val > max) {
      this.showFeedback(input, this.data.get("gradeMaxMessage") || `Максимальное значение: ${max}`)
      return false
    }

    this.markValid(input)
    return true
  }

  showFeedback(input, message) {
    input.classList.add("is-invalid")
    input.classList.remove("is-valid")
    let feedback = input.parentElement.querySelector(".invalid-feedback")
    if (!feedback) {
      feedback = document.createElement("div")
      feedback.classList.add("invalid-feedback")
      feedback.setAttribute("role", "alert")
      input.parentElement.appendChild(feedback)
    }
    feedback.textContent = message
  }

  markValid(input) {
    input.classList.remove("is-invalid")
    input.classList.add("is-valid")
    const feedback = input.parentElement.querySelector(".invalid-feedback")
    if (feedback) feedback.remove()
  }

  clearFeedback(input) {
    input.classList.remove("is-invalid", "is-valid")
    const feedback = input.parentElement.querySelector(".invalid-feedback")
    if (feedback) feedback.remove()
  }
}
