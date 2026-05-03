import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "skeleton", "button", "label", "email", "copyButton"]

  showSkeleton() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
    }
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = "Generating…"
    }
    if (this.hasContentTarget && this.hasSkeletonTarget) {
      const skeleton = this.skeletonTarget.content.cloneNode(true)
      this.contentTarget.replaceWith(skeleton.firstElementChild)
    }
  }

  async copy() {
    if (!this.hasEmailTarget) return
    try {
      await navigator.clipboard.writeText(this.emailTarget.innerText)
      if (this.hasCopyButtonTarget) {
        const original = this.copyButtonTarget.textContent
        this.copyButtonTarget.textContent = "Copied!"
        setTimeout(() => { this.copyButtonTarget.textContent = original }, 1500)
      }
    } catch (e) {
      console.error("Clipboard write failed", e)
    }
  }
}
