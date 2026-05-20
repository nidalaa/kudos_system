class DashboardController < ApplicationController
  CATEGORY_COLORS = {
    "Teamwork"             => "#6366f1",
    "Technical Excellence" => "#f59e0b",
    "Innovation"           => "#10b981",
    "Leadership"           => "#ef4444",
    "Customer Impact"      => "#8b5cf6",
    "Above & Beyond"       => "#06b6d4"
  }.freeze

  def index
    @period       = params[:period].presence || "month"
    @period_range = parse_period
    @period_label = period_label

    scope = Kudos.where(status: "approved").where(slack_timestamp: @period_range)

    @total            = scope.count
    @unique_receivers = scope.distinct.count(:receiver_id)
    @unique_givers    = scope.distinct.count(:giver_id)
    @by_category      = scope.group(:category).count
    @top_receivers    = build_leaderboard(scope, :receiver_id)
    @top_givers       = build_leaderboard(scope, :giver_id)
    @weekly_trend     = build_weekly_trend(scope)
    @most_backed      = build_most_backed(scope)
    @category_colors  = CATEGORY_COLORS
  end

  private

  def parse_period
    now = Time.current
    case @period
    when "week"    then 1.week.ago..now
    when "2weeks"  then 2.weeks.ago..now
    when "quarter" then 3.months.ago..now
    when "year"    then now.beginning_of_year..now
    when "custom"
      from = begin; params[:from].present? ? Date.parse(params[:from]).beginning_of_day : 1.month.ago; rescue; 1.month.ago; end
      to   = begin; params[:to].present?   ? Date.parse(params[:to]).end_of_day         : now;          rescue; now;          end
      from..to
    else
      1.month.ago..now
    end
  end

  def period_label
    { "week" => "Last week", "2weeks" => "Last 2 weeks", "quarter" => "Last quarter",
      "year" => "Current year", "custom" => "Custom range" }.fetch(@period, "Last month")
  end

  def build_leaderboard(scope, person_col)
    counts = scope.group(person_col).order(Arel.sql("count_all DESC")).limit(10).count
    employee_ids = counts.keys
    employees = Employee.where(id: employee_ids).index_by(&:id)

    counts.map do |employee_id, count|
      emp = employees[employee_id]
      next unless emp

      person_scope  = scope.where(person_col => employee_id)
      by_cat        = person_scope.group(:category).count
      sparkline     = build_sparkline(person_scope)
      top3          = build_most_backed(person_scope, limit: 5)

      {
        id:        employee_id,
        name:      "#{emp.first_name} #{emp.last_name}",
        count:     count,
        by_cat:    by_cat,
        sparkline: sparkline,
        top3:      top3
      }
    end.compact
  end

  def build_sparkline(person_scope)
    person_scope
      .group(Arel.sql("date_trunc('week', slack_timestamp)"))
      .order(Arel.sql("date_trunc('week', slack_timestamp)"))
      .count
      .map { |week, cnt| { week: week.strftime("%b %d"), count: cnt } }
  end

  def build_weekly_trend(scope)
    categories = Category.pluck(:name)
    days = scope
      .group(Arel.sql("date_trunc('day', slack_timestamp)"))
      .order(Arel.sql("date_trunc('day', slack_timestamp)"))
      .count
      .keys
      .map { |d| d.strftime("%b %d") }

    datasets = categories.map do |cat|
      counts_by_day = scope
        .where(category: cat)
        .group(Arel.sql("date_trunc('day', slack_timestamp)"))
        .order(Arel.sql("date_trunc('day', slack_timestamp)"))
        .count

      data = days.map do |d|
        matching = counts_by_day.find { |day, _| day.strftime("%b %d") == d }
        matching ? matching[1] : 0
      end

      { label: cat, data: data, color: CATEGORY_COLORS.fetch(cat, "#94a3b8") }
    end.reject { |ds| ds[:data].all?(&:zero?) }

    { days: days, datasets: datasets }
  end

  def build_most_backed(scope, limit: 3)
    scope
      .select("kudos.*, array_length(reactions_from, 1) as rxn_count")
      .order(Arel.sql("rxn_count DESC NULLS LAST"))
      .limit(limit)
      .includes(:giver, :receiver)
      .map do |k|
        {
          receiver:  "#{k.receiver.first_name} #{k.receiver.last_name}",
          giver:     "#{k.giver.first_name} #{k.giver.last_name}",
          reason:    k.reason.to_s,
          category:  k.category.to_s,
          reactions: Array(k.reactions_from).size
        }
      end
  end
end
