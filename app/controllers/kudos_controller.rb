class KudosController < ApplicationController
  def index
    @categories = Category.all
    @kudos = [
      { id: 1, giver: "Alice Mercer",  receiver: "Bob Kim",      category: "Teamwork",             reactions_count: 7,  reason: "Saved the deploy at midnight by catching the config error before it hit prod.", channel: "#engineering", date: "May 14, 2026", status: "pending" },
      { id: 2, giver: "Carol Singh",   receiver: "Dave Liu",      category: "Innovation",           reactions_count: 12, reason: "Shipped the new onboarding flow two weeks early — already reducing churn.", channel: "#product",     date: "May 13, 2026", status: "pending" },
      { id: 3, giver: "Emma Torres",   receiver: "Frank Osei",    category: "Technical Excellence", reactions_count: 4,  reason: "Refactored the auth middleware with zero downtime and cleaned up 800 lines of legacy code.", channel: "#backend",     date: "May 12, 2026", status: "pending" },
      { id: 4, giver: "Grace Park",    receiver: "Henry Wu",      category: "Teamwork",             reactions_count: 9,  reason: "Jumped in on-call coverage last minute so I could attend my daughter's recital.", channel: "#general",     date: "May 11, 2026", status: "pending" },
      { id: 5, giver: "Ivan Petrov",   receiver: "Julia Nkosi",   category: "Customer Focus",       reactions_count: 2,  reason: "Stayed late to walk the client through the new reporting dashboard personally.", channel: "#sales",       date: "May 10, 2026", status: "pending" },
      { id: 6, giver: "Kim Larsen",    receiver: "Leo Martins",   category: "Innovation",           reactions_count: 15, reason: "Built the CSV export feature over the weekend — saved us from losing the contract.", channel: "#product",     date: "May 9, 2026",  status: "approved" },
      { id: 7, giver: "Mia Chen",      receiver: "Nate Brooks",   category: "Teamwork",             reactions_count: 6,  reason: "Pair-programmed with me for three hours to unblock my first contribution to the codebase.", channel: "#engineering", date: "May 8, 2026",  status: "approved" },
      { id: 8, giver: "Olivia Grant",  receiver: "Paul Adeyemi",  category: "Technical Excellence", reactions_count: 1,  reason: "Wrote documentation so thorough I could onboard in one day instead of one week.", channel: "#engineering", date: "May 7, 2026",  status: "rejected" },
    ]
  end
end
