import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "leaderboardList",
    "receiversTab", "giversTab",
    "donutChart", "donutLegend",
    "trendChart",
    "detailPanel", "detailBackdrop", "detailName", "detailByCat", "sparklineChart", "detailTop3"
  ]
  static values = {
    topReceivers:   { type: Array,  default: [] },
    topGivers:      { type: Array,  default: [] },
    byCategory:     { type: Object, default: {} },
    weeklyTrend:    { type: Object, default: {} },
    mostBacked:     { type: Array,  default: [] },
    categoryColors: { type: Object, default: {} }
  }

  #activeTab = "receivers"
  #sparkline = null

  connect() {
    this.#renderLeaderboard()
  }

  // ── Tabs ─────────────────────────────────────────────────────────────────

  showReceivers() {
    this.#activeTab = "receivers"
    this.#renderLeaderboard()
    this.#styleTab(this.receiversTabTarget, true)
    this.#styleTab(this.giversTabTarget, false)
  }

  showGivers() {
    this.#activeTab = "givers"
    this.#renderLeaderboard()
    this.#styleTab(this.giversTabTarget, true)
    this.#styleTab(this.receiversTabTarget, false)
  }

  #styleTab(btn, active) {
    btn.classList.toggle("border-indigo-500", active)
    btn.classList.toggle("text-indigo-400",   active)
    btn.classList.toggle("border-transparent", !active)
    btn.classList.toggle("text-slate-500",     !active)
  }

  // ── Leaderboard ──────────────────────────────────────────────────────────

  #renderLeaderboard() {
    const people = this.#activeTab === "receivers"
      ? this.topReceiversValue
      : this.topGiversValue

    this.leaderboardListTarget.innerHTML = people.map((p, i) => `
      <button
        class="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-800 transition-colors text-left group"
        data-index="${i}"
        data-action="click->kudos-analytics#openDetail">
        <span class="font-bold text-sm w-5 text-right ${i === 0 ? 'text-amber-400' : 'text-slate-600'}">${i + 1}</span>
        <span class="flex-1 text-sm font-medium text-slate-300 group-hover:text-white underline decoration-dotted decoration-slate-600 underline-offset-2 truncate">${this.#esc(p.name)}</span>
        <span class="text-indigo-400 font-bold text-sm tabular-nums">${p.count}</span>
        <span class="text-slate-600 text-xs">kudos</span>
      </button>
    `).join("") || '<p class="text-xs text-slate-600 text-center py-6">No data for this period.</p>'
  }

  // ── Detail panel ─────────────────────────────────────────────────────────

  async openDetail(event) {
    const idx    = parseInt(event.currentTarget.dataset.index)
    const people = this.#activeTab === "receivers" ? this.topReceiversValue : this.topGiversValue
    const person = people[idx]
    if (!person) return

    this.detailNameTarget.textContent = person.name

    // Category breakdown
    const maxCat = Math.max(...Object.values(person.by_cat), 1)
    this.detailByCatTarget.innerHTML = Object.entries(person.by_cat)
      .sort((a, b) => b[1] - a[1])
      .map(([cat, cnt]) => {
        const color = this.categoryColorsValue[cat] || "#94a3b8"
        const pct   = Math.round((cnt / maxCat) * 100)
        return `
          <div class="flex items-center gap-2">
            <span style="color:${color}" class="text-xs">●</span>
            <span class="flex-1 text-xs text-slate-400 truncate">${this.#esc(cat)}</span>
            <div class="w-20 bg-slate-800 rounded h-1.5 overflow-hidden">
              <div style="background:${color};width:${pct}%" class="h-full rounded"></div>
            </div>
            <span class="text-xs text-indigo-300 w-4 text-right tabular-nums">${cnt}</span>
          </div>`
      }).join("") || '<p class="text-xs text-slate-600">No category data.</p>'

    // Top 3 most backed-up kudos
    const borderColors = ["border-amber-400", "border-slate-500", "border-amber-700", "border-slate-600", "border-slate-700"]
    this.detailTop3Target.innerHTML = (person.top3 || []).map((k, i) => `
      <div class="bg-slate-950 rounded-lg p-3 border-l-2 ${borderColors[i] || 'border-slate-700'}">
        <div class="flex items-center justify-between mb-1">
          <span class="text-xs font-semibold text-slate-300">${this.#esc(k.category || "")}</span>
          <span class="text-xs font-bold text-amber-400">${k.reactions} reactions</span>
        </div>
        <div class="relative group/tip">
          <p class="text-xs text-slate-500 italic leading-relaxed line-clamp-2">"${this.#esc(k.reason)}"</p>
          <div class="pointer-events-none absolute bottom-full left-0 mb-1.5 hidden group-hover/tip:block bg-slate-700 text-slate-200 text-xs rounded-lg px-3 py-2 z-10 w-full shadow-xl leading-relaxed">
            "${this.#esc(k.reason)}"
          </div>
        </div>
        <div class="text-xs text-slate-700 mt-1">
          ${this.#activeTab === "receivers" ? "from " + this.#esc(k.giver) : "to " + this.#esc(k.receiver)}
        </div>
      </div>`
    ).join("") || '<p class="text-xs text-slate-600">No kudos yet.</p>'

    // Sparkline
    await this.#renderSparkline(person.sparkline || [])

    this.detailPanelTarget.classList.remove("hidden")
    this.detailBackdropTarget.classList.remove("hidden")
  }

  closeDetail() {
    this.detailPanelTarget.classList.add("hidden")
    this.detailBackdropTarget.classList.add("hidden")
    if (this.#sparkline) { this.#sparkline.destroy(); this.#sparkline = null }
  }

  async #renderSparkline(sparklineData) {
    if (this.#sparkline) { this.#sparkline.destroy(); this.#sparkline = null }
    if (!sparklineData.length) return

    const { Chart, registerables } = await import("chart.js")
    if (registerables) Chart.register(...registerables)

    this.#sparkline = new Chart(this.sparklineChartTarget, {
      type: "bar",
      data: {
        labels: sparklineData.map(d => d.week),
        datasets: [{
          data:            sparklineData.map(d => d.count),
          backgroundColor: "#6366f1",
          borderRadius:    2
        }]
      },
      options: {
        plugins: { legend: { display: false }, tooltip: { callbacks: { title: () => "" } } },
        scales: {
          x: { ticks: { color: "#475569", font: { size: 9 } }, grid: { display: false } },
          y: { ticks: { color: "#475569", font: { size: 9 }, stepSize: 1 }, grid: { color: "#1e293b" } }
        }
      }
    })
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  #esc(str) {
    return String(str ?? "")
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }
}
