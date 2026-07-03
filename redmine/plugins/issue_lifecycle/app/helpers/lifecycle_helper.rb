module LifecycleHelper
  def format_duration(seconds)
    seconds = seconds.to_i

    days = seconds / 1.day
    seconds %= 1.day

    hours = seconds / 1.hour
    seconds %= 1.hour

    minutes = seconds / 1.minute

    parts = []

    parts << "#{days} gün" if days.positive?
    parts << "#{hours} saat" if hours.positive?
    parts << "#{minutes} dk" if minutes.positive?

    parts.empty? ? "0 dk" : parts.join(" ")
  end

  def lifecycle_bar_width(value, max_value)
    max_value = max_value.to_i
    value = value.to_i

    return 0 if max_value <= 0

    ((value.to_f / max_value) * 100).round(2)
  end

  def lifecycle_sort_direction(column)
    if params[:sort] == column && params[:direction] != "desc"
      "desc"
    else
      "asc"
    end
  end

  def lifecycle_sort_link(label, column)
    link_to(
      label,
      {
        controller: "lifecycle",
        action: "index",
        project_id: @project.identifier,
        sort: column,
        direction: lifecycle_sort_direction(column),
        category_id: params[:category_id],
        user_id: params[:user_id],
        selected_issue_id: params[:selected_issue_id]
      }
    )
  end

  def lifecycle_issue_detail_link(issue)
    link_to(
      "##{issue.id}",
      {
        controller: "lifecycle",
        action: "index",
        project_id: @project.identifier,
        sort: @sort,
        direction: @direction,
        category_id: params[:category_id],
        user_id: params[:user_id],
        selected_issue_id: issue.id
      }
    )
  end

  def lifecycle_chart_colors
    [
      "#3b82f6",
      "#22c55e",
      "#f59e0b",
      "#a855f7",
      "#94a3b8",
      "#ef4444",
      "#14b8a6",
      "#6366f1",
      "#ec4899"
    ]
  end

  def lifecycle_chart_color(index)
    lifecycle_chart_colors[index % lifecycle_chart_colors.length]
  end

  def lifecycle_total_value(rows, key = :total_seconds)
    rows.sum { |row| row[key].to_i }
  end

  def lifecycle_percentage(value, total)
    total = total.to_i
    value = value.to_i

    return 0 if total <= 0

    ((value.to_f / total) * 100).round(1)
  end

  def lifecycle_donut_gradient(rows, key = :total_seconds)
    total = lifecycle_total_value(rows, key)

    return "conic-gradient(#e5e7eb 0% 100%)" if total <= 0

    start_percent = 0.0

    segments = rows.each_with_index.map do |row, index|
      value = row[key].to_i
      percent = (value.to_f / total) * 100
      end_percent = start_percent + percent

      color = lifecycle_chart_color(index)

      segment = "#{color} #{start_percent.round(2)}% #{end_percent.round(2)}%"

      start_percent = end_percent

      segment
    end

    "conic-gradient(#{segments.join(', ')})"
  end
end