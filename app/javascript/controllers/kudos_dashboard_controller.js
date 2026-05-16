import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "row", "tabButton", "pendingCount", "approvedCount", "rejectedCount",
    "emptyState", "fileInput", "tbody",
    "checkbox", "selectAll", "bulkBar", "selectedCount", "bulkCategoryInput",
    "categoryFilter"
  ]
  static values = {
    tab:        { type: String, default: "pending" },
    search:     { type: String, default: "" },
    category:   { type: String, default: "" },
    categories: { type: Array,  default: [] }
  }

  connect() {
    this.updateView()
  }

  // ── Tab switching ────────────────────────────────────────────────────────────

  switchTab(event) {
    this.tabValue = event.currentTarget.dataset.tab
  }

  tabValueChanged() {
    this.clearSelection()
    this.updateView()
  }

  // ── Per-row approve / reject ─────────────────────────────────────────────────

  approve(event) {
    this.#setStatus(event.currentTarget.closest("[data-status]"), "approved")
  }

  reject(event) {
    this.#setStatus(event.currentTarget.closest("[data-status]"), "rejected")
  }

  // ── Search ───────────────────────────────────────────────────────────────────

  search(event) {
    this.searchValue = event.currentTarget.value.toLowerCase()
    this.updateView()
  }

  // ── Category filter ──────────────────────────────────────────────────────────

  filterCategory(event) {
    this.categoryValue = event.currentTarget.value
    this.updateView()
  }

  // ── Inline category edit ─────────────────────────────────────────────────────

  editCategory(event) {
    const wrapper = event.currentTarget.closest(".group")
    const display = wrapper.querySelector(".category-display")
    const editBtn = wrapper.querySelector("button[title='Edit category']")
    const select  = wrapper.querySelector(".category-select")
    display.classList.add("hidden")
    editBtn?.classList.add("hidden")
    select.value = display.textContent.trim()
    select.classList.remove("hidden")
    select.focus()
  }

  saveCategory(event) {
    const select  = event.currentTarget
    const wrapper = select.closest(".group")
    const display = wrapper.querySelector(".category-display")
    const editBtn = wrapper.querySelector("button[title='Edit category']")
    const newVal  = select.value
    if (newVal) display.textContent = newVal
    select.classList.add("hidden")
    display.classList.remove("hidden")
    editBtn?.classList.remove("hidden")

    const row  = select.closest("[data-id]")
    const id   = row?.dataset.id
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (id && newVal) {
      row.dataset.category = newVal
      fetch(`/kudos/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf },
        body: JSON.stringify({ category: newVal })
      })
    }
  }

  // ── Bulk selection ───────────────────────────────────────────────────────────

  toggleRow() {
    this.#updateBulkBar()
  }

  toggleAll(event) {
    const checked = event.currentTarget.checked
    this.#visibleCheckboxes().forEach(cb => { cb.checked = checked })
    this.#updateBulkBar()
  }

  clearSelection() {
    this.checkboxTargets.forEach(cb => { cb.checked = false })
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked       = false
      this.selectAllTarget.indeterminate = false
    }
    this.#updateBulkBar()
  }

  // ── Bulk actions ─────────────────────────────────────────────────────────────

  bulkApprove() {
    this.#selectedRows().forEach(row => this.#setStatus(row, "approved"))
    this.clearSelection()
  }

  bulkReject() {
    this.#selectedRows().forEach(row => this.#setStatus(row, "rejected"))
    this.clearSelection()
  }

  bulkSetCategory() {
    const val = this.bulkCategoryInputTarget.value
    if (!val) return
    this.#selectedRows().forEach(row => {
      const display = row.querySelector(".category-display")
      const select  = row.querySelector(".category-select")
      if (display) display.textContent = val
      if (select)  select.value        = val
    })
    this.bulkCategoryInputTarget.value = ""
    this.#updateBulkBar()
  }

  // ── File upload ──────────────────────────────────────────────────────────────

  triggerUpload() {
    this.fileInputTarget.click()
  }

  handleFile(event) {
    const file = event.currentTarget.files[0]
    if (!file) return

    if (!confirm(`Send "${file.name}" to the AI agent for processing?`)) {
      event.currentTarget.value = ""
      return
    }

    const formData = new FormData()
    formData.append("file", file)
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content

    fetch("/uploads/slack", {
      method: "POST",
      body: formData,
      headers: { "X-CSRF-Token": csrf }
    })
    .then(response => {
      if (response.ok) {
        alert("Messages will be processed in the background. Records will appear one by one, so you might need to refresh the page in a couple of minutes (depending on the file size).")
      } else {
        alert("Upload failed — server returned " + response.status)
      }
    })
    .catch(() => alert("Upload failed — network error."))

    event.currentTarget.value = ""
  }

  // ── View update ──────────────────────────────────────────────────────────────

  updateView() {
    const tab   = this.tabValue
    const query = this.searchValue
    let counts  = { pending: 0, approved: 0, rejected: 0 }
    let visible = 0

    this.rowTargets.forEach(row => {
      const status = row.dataset.status
      counts[status] = (counts[status] || 0) + 1

      const matchesTab      = status === tab
      const matchesSearch   = !query || row.textContent.toLowerCase().includes(query)
      const matchesCategory = !this.categoryValue || row.dataset.category === this.categoryValue
      const show            = matchesTab && matchesSearch && matchesCategory

      row.style.display = show ? "" : "none"
      if (show) visible++

      this.#styleActionButtons(row, status)
    })

    if (this.hasPendingCountTarget)  this.pendingCountTarget.textContent  = counts.pending  || 0
    if (this.hasApprovedCountTarget) this.approvedCountTarget.textContent = counts.approved || 0
    if (this.hasRejectedCountTarget) this.rejectedCountTarget.textContent = counts.rejected || 0
    if (this.hasEmptyStateTarget)    this.emptyStateTarget.classList.toggle("hidden", visible > 0)

    this.tabButtonTargets.forEach(btn => {
      const active = btn.dataset.tab === tab
      btn.classList.toggle("bg-indigo-600",   active)
      btn.classList.toggle("text-white",       active)
      btn.classList.toggle("bg-white",        !active)
      btn.classList.toggle("text-gray-600",   !active)
      btn.classList.toggle("border",          !active)
      btn.classList.toggle("border-gray-300", !active)
    })

    this.#updateBulkBar()
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  #setStatus(row, status) {
    row.dataset.status = status
    this.updateView()
    const id   = row.dataset.id
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/kudos/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf },
      body: JSON.stringify({ status })
    })
  }

  #visibleCheckboxes() {
    return this.checkboxTargets.filter(cb =>
      cb.closest("[data-status]")?.style.display !== "none"
    )
  }

  #selectedRows() {
    return this.checkboxTargets
      .filter(cb => cb.checked && cb.closest("[data-status]")?.style.display !== "none")
      .map(cb => cb.closest("[data-status]"))
  }

  #updateBulkBar() {
    const selected = this.#selectedRows().length
    if (this.hasSelectedCountTarget) this.selectedCountTarget.textContent = selected
    if (this.hasBulkBarTarget)       this.bulkBarTarget.classList.toggle("hidden", selected === 0)

    if (this.hasSelectAllTarget) {
      const visible      = this.#visibleCheckboxes()
      const checkedCount = visible.filter(cb => cb.checked).length
      this.selectAllTarget.checked       = visible.length > 0 && checkedCount === visible.length
      this.selectAllTarget.indeterminate = checkedCount > 0 && checkedCount < visible.length
    }
  }

  #addRow(item) {
    const row      = document.createElement("tr")
    row.dataset.kudosDashboardTarget = "row"
    row.dataset.status   = item.status   || "pending"
    row.dataset.category = item.category || ""
    row.className  = "hover:bg-gray-50 transition-colors"

    const category        = this.#esc(item.category || "Uncategorised")
    const reactionsFrom   = item.reactions_from ?? item.reactions ?? []
    const reactionsCount  = item.reactions_count ?? reactionsFrom.length ?? 0
    const reactionsTooltip = reactionsFrom.length
      ? `<div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 hidden group-hover:block bg-gray-800 text-white text-xs rounded px-2 py-1.5 z-10 min-w-max space-y-0.5">${reactionsFrom.map(r => `<div>${this.#esc(this.#formatReaction(String(r)))}</div>`).join("")}</div>`
      : ""

    row.innerHTML = `
      <td class="px-4 py-3">
        <input type="checkbox"
               data-kudos-dashboard-target="checkbox"
               data-action="change->kudos-dashboard#toggleRow"
               class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500 cursor-pointer">
      </td>
      <td class="px-4 py-3 text-sm font-medium text-gray-900 whitespace-nowrap">${this.#esc(item.giver || "")}</td>
      <td class="px-4 py-3 text-sm text-gray-700 whitespace-nowrap">${this.#esc(item.receiver || "")}</td>
      <td class="px-4 py-3 text-sm whitespace-nowrap">
        <div class="flex items-center gap-1 group">
          <span class="category-display inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-50 text-indigo-700">${category}</span>
          <button class="opacity-0 group-hover:opacity-100 transition-opacity text-gray-400 hover:text-indigo-600"
                  data-action="click->kudos-dashboard#editCategory" title="Edit category">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor">
              <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z"/>
            </svg>
          </button>
          <select class="category-select hidden w-44 px-2 py-0.5 text-xs border border-indigo-300 rounded focus:outline-none focus:ring-1 focus:ring-indigo-500 bg-white"
                  data-action="change->kudos-dashboard#saveCategory blur->kudos-dashboard#saveCategory">
            ${this.#categoryOptions(category)}
          </select>
        </div>
      </td>
      <td class="px-4 py-3 text-sm text-gray-600">
        <span class="line-clamp-2" title="${this.#esc(item.reason || "")}">${this.#esc(item.reason || "")}</span>
      </td>
      <td class="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">
        <div class="relative group inline-block">
          <span class="font-medium text-gray-700 cursor-default">${reactionsCount}</span>
          ${reactionsTooltip}
        </div>
      </td>
      <td class="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">${this.#esc(item.date || "")}</td>
      <td class="px-4 py-3 whitespace-nowrap">
        <div class="flex items-center gap-2">
          <button data-action="click->kudos-dashboard#approve" title="Approve"
                  class="approve-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors">✓ Approve</button>
          <button data-action="click->kudos-dashboard#reject" title="Reject"
                  class="reject-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors">✗ Reject</button>
        </div>
      </td>
    `
    this.tbodyTarget.appendChild(row)
  }

  #styleActionButtons(row, status) {
    const approveBtn = row.querySelector(".approve-btn")
    const rejectBtn  = row.querySelector(".reject-btn")
    if (!approveBtn || !rejectBtn) return

    if (status === "pending") {
      approveBtn.className = "approve-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors bg-green-50 text-green-700 hover:bg-green-100 border border-green-200"
      rejectBtn.className  = "reject-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors bg-red-50 text-red-700 hover:bg-red-100 border border-red-200"
    } else if (status === "approved") {
      approveBtn.className = "approve-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors bg-green-100 text-green-800 border border-green-300 cursor-default"
      rejectBtn.className  = "reject-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors bg-red-50 text-red-700 hover:bg-red-100 border border-red-200"
    } else {
      approveBtn.className = "approve-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors bg-green-50 text-green-700 hover:bg-green-100 border border-green-200"
      rejectBtn.className  = "reject-btn inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors bg-red-100 text-red-800 border border-red-300 cursor-default"
    }
  }

  #categoryOptions(selected = "") {
    return this.categoriesValue
      .map(c => `<option value="${this.#esc(c.name)}" title="${this.#esc(c.description)}" ${c.name === selected ? "selected" : ""}>${this.#esc(c.name)}</option>`)
      .join("")
  }

  #formatReaction(r) {
    const emojiMap = {
      taco: "🌮", heart: "❤️", thumbsup: "👍", fire: "🔥", clap: "👏",
      "100": "💯", star: "⭐", tada: "🎉", rocket: "🚀", mind_blown: "🤯",
      raised_hands: "🙌", muscle: "💪", pray: "🙏", moneybag: "💰",
      chart_with_upwards_trend: "📈", fist_bump: "👊", accessibility: "♿", books: "📚"
    }
    if (r.includes(":")) {
      const [emoji, username] = r.split(":", 2)
      return `${emojiMap[emoji] || `:${emoji}:`} ${username}`
    }
    return r
  }

  #esc(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
