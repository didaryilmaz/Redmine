module IssueLifecyclePatch

  def lifecycle_times

    changes = []

    journals
      .includes(:details)
      .order(:created_on)
      .each do |journal|

        detail = journal.details.find { |d| d.prop_key == "status_id" }

        next unless detail

        changes << {
          old_status_id: detail.old_value.to_i,
          new_status_id: detail.value.to_i,
          changed_at: journal.created_on,
          user: journal.user
        }

      end

    times = []

    changes.each_with_index do |change, index|

      next_change = changes[index + 1]

      ended_at =
        if next_change
          next_change[:changed_at]
        else
          Time.current
        end

      times << {
        status_id: change[:new_status_id],
        started_at: change[:changed_at],
        ended_at: ended_at,
        duration: ended_at - change[:changed_at],
        user: change[:user]
      }

    end

    times

  end

end