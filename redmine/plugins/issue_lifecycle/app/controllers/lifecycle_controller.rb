require_relative '../services/issue_lifecycle_service'

class LifecycleController < ApplicationController
  before_action :find_project
  before_action :authorize

  def index
    service = IssueLifecycleService.new(@project)

    @sort = params[:sort].presence || "issue_id"
    @direction = params[:direction] == "desc" ? "desc" : "asc"

    @category_id = params[:category_id].presence
    @user_id = params[:user_id].presence
    @selected_issue_id = params[:selected_issue_id].presence

    @statuses = service.statuses
    @categories = @project.issue_categories.order(:name)
    @users = User.active.order(:firstname, :lastname)

    @summary_rows = service.summary_rows(
      sort: @sort,
      direction: @direction,
      category_id: @category_id,
      user_id: @user_id
    )

    @stats = service.stats(
      category_id: @category_id,
      user_id: @user_id
    )

    @category_totals = service.category_totals(
      category_id: @category_id,
      user_id: @user_id
    )

    @user_totals = service.user_totals(
      category_id: @category_id,
      user_id: @user_id
    )

    @selected_issue = service.selected_issue(@selected_issue_id)
    @issue_detail_rows = service.issue_detail_rows(@selected_issue_id)
  end

  private

  def find_project
    @project = Project.find_by_identifier(params[:project_id])
  end
end