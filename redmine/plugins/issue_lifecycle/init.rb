Redmine::Plugin.register :issue_lifecycle do
  name 'Issue Lifecycle'
  author 'Didar'
  description 'Issue Lifecycle Analytics'
  version '1.0.0'

  project_module :issue_lifecycle do
    permission :view_issue_lifecycle,
               { lifecycle: [:index] }
  end

  menu :project_menu,
       :issue_lifecycle,
       { controller: 'lifecycle', action: 'index' },
       caption: 'Lifecycle',
       after: :issues,
       param: :project_id
end

