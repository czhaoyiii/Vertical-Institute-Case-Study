import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  initialize() {
    this._timer = null
  }

  search() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this.element.requestSubmit(), 300)
  }
}
