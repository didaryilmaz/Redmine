class IssueLifecycleService
  def initialize(project)
    @project = project
  end

  def statuses
    @statuses ||= IssueStatus.order(:position).to_a
  end

  def rows
    @rows ||= issues.flat_map do |issue|
      lifecycle_rows_for(issue)
    end
  end

  def summary_rows(sort: nil, direction: "asc", category_id: nil, user_id: nil)
    filtered_rows = filtered_base_summary_rows(
      category_id: category_id,
      user_id: user_id
    )

    sort_summary_rows(filtered_rows, sort, direction)
  end

  def stats(category_id: nil, user_id: nil)
    filtered_rows = filtered_base_summary_rows(
      category_id: category_id,
      user_id: user_id
    )

    total_issues = filtered_rows.count
    total_duration = filtered_rows.sum { |row| row[:total_seconds] }
    average_duration = total_issues.positive? ? total_duration / total_issues : 0

    {
      total_issues: total_issues,
      total_duration_seconds: total_duration,
      average_duration_seconds: average_duration,
      transition_count: filtered_rows.sum { |row| row[:transition_count] }
    }
  end

  def selected_issue(issue_id)
    return nil if issue_id.blank?

    issues.find { |issue| issue.id.to_s == issue_id.to_s }
    end

  def issue_detail_rows(issue_id)
    return [] if issue_id.blank?

    rows.select do |row|
        row[:issue_id].to_s == issue_id.to_s
    end
  end

  def category_totals(category_id: nil, user_id: nil)
    filtered_rows = filtered_base_summary_rows(
      category_id: category_id,
      user_id: user_id
    )

    filtered_rows
      .group_by { |row| row[:category] }
      .map do |category, rows|
        {
          category: category,
          issue_count: rows.count,
          total_seconds: rows.sum { |row| row[:total_seconds] }
        }
      end
      .sort_by { |row| row[:category].to_s.downcase }
  end

  def user_totals(category_id: nil, user_id: nil)
    filtered_rows = rows

    if category_id.present?
      filtered_rows = filtered_rows.select do |row|
        row[:issue].category_id.to_s == category_id.to_s
      end
    end

    if user_id.present?
      filtered_rows = filtered_rows.select do |row|
        row[:user_id].to_s == user_id.to_s
      end
    end

    filtered_rows
      .group_by { |row| row[:user] }
      .map do |user, rows|
        {
          user: user,
          transition_count: rows.count { |row| row[:transition] },
          total_seconds: rows.sum { |row| row[:duration_seconds] }
        }
      end
      .sort_by { |row| row[:user].to_s.downcase }
  end

  private

  def issues
    @issues ||= @project.issues.includes(
      :category,
      :author,
      :status,
      journals: [:user, :details]
    ).order(:id)
  end

  def filtered_base_summary_rows(category_id: nil, user_id: nil)
    result = base_summary_rows

    if category_id.present?
      result = result.select do |row|
        row[:category_id].to_s == category_id.to_s
      end
    end

    if user_id.present?
      result = result.select do |row|
        row[:user_ids].map(&:to_s).include?(user_id.to_s)
      end
    end

    result
  end

  def base_summary_rows
    @base_summary_rows ||= rows.group_by { |row| row[:issue_id] }.map do |_issue_id, issue_rows|
      issue = issue_rows.first[:issue]

      durations_by_status_id = Hash.new(0)

      issue_rows.each do |row|
        durations_by_status_id[row[:status_id]] += row[:duration_seconds]
      end

      {
        issue: issue,
        issue_id: issue.id,
        subject: issue.subject,
        category: issue.category&.name || "-",
        category_id: issue.category_id,
        durations_by_status_id: durations_by_status_id,
        total_seconds: issue_rows.sum { |row| row[:duration_seconds] },
        last_change_at: issue_rows.map { |row| row[:started_at] }.max,
        users: issue_rows.map { |row| row[:user] }.uniq.join(", "),
        user_ids: issue_rows.map { |row| row[:user_id] }.compact.uniq,
        transition_count: issue_rows.count { |row| row[:transition] }
      }
    end
  end

  def sort_summary_rows(summary_rows, sort, direction)
    sorted =
      case sort
      when "issue_id"
        summary_rows.sort_by { |row| row[:issue_id] }

      when "subject"
        summary_rows.sort_by { |row| row[:subject].to_s.downcase }

      when "category"
        summary_rows.sort_by { |row| row[:category].to_s.downcase }

      when "total_seconds"
        summary_rows.sort_by { |row| row[:total_seconds] }

      when "last_change_at"
        summary_rows.sort_by { |row| row[:last_change_at] || Time.at(0) }

      when "users"
        summary_rows.sort_by { |row| row[:users].to_s.downcase }

      else
        if sort.to_s.start_with?("status_")
          status_id = sort.to_s.delete_prefix("status_").to_i
          summary_rows.sort_by { |row| row[:durations_by_status_id][status_id] }
        else
          summary_rows.sort_by { |row| row[:issue_id] }
        end
      end

    direction == "desc" ? sorted.reverse : sorted
  end

  def lifecycle_rows_for(issue)
    changes = status_changes_for(issue)

    return [single_status_row(issue)] if changes.empty?

    lifecycle_rows = []

    current_status_id = changes.first[:old_status_id]
    started_at = issue.created_on

    changes.each do |change|
      lifecycle_rows << build_row(
        issue: issue,
        status_id: current_status_id,
        started_at: started_at,
        ended_at: change[:changed_at],
        user: change[:user],
        ongoing: false
      )

      current_status_id = change[:new_status_id]
      started_at = change[:changed_at]
    end

    last_change = changes.last

    lifecycle_rows << build_row(
      issue: issue,
      status_id: current_status_id,
      started_at: started_at,
      ended_at: Time.current,
      user: last_change[:user],
      ongoing: true
    )

    lifecycle_rows
  end

  def status_changes_for(issue)
    issue.journals.sort_by(&:created_on).filter_map do |journal|
      detail = journal.details.find { |d| d.prop_key == "status_id" }

      next unless detail

      {
        old_status_id: detail.old_value.to_i,
        new_status_id: detail.value.to_i,
        changed_at: journal.created_on,
        user: journal.user
      }
    end
  end

  def single_status_row(issue)
    build_row(
      issue: issue,
      status_id: issue.status_id,
      started_at: issue.created_on,
      ended_at: Time.current,
      user: issue.author,
      ongoing: true
    )
  end

  def build_row(issue:, status_id:, started_at:, ended_at:, user:, ongoing:)
    status = IssueStatus.find_by(id: status_id)

    {
      issue: issue,
      issue_id: issue.id,
      subject: issue.subject,
      category: issue.category&.name || "-",
      status_id: status_id,
      status: status&.name || "-",
      started_at: started_at,
      ended_at: ended_at,
      duration_seconds: (ended_at - started_at).to_i,
      user: user&.name || "-",
      user_id: user&.id,
      ongoing: ongoing,
      transition: !ongoing
    }
  end
end