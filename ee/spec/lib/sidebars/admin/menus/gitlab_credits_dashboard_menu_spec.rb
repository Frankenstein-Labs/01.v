# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::GitlabCreditsDashboardMenu, feature_category: :navigation do
  it_behaves_like 'Admin menu',
    link: '/admin/gitlab_credits_dashboard',
    title: _('GitLab Credits'),
    icon: 'gitlab-credits'

  it_behaves_like 'Admin menu without sub menus', active_routes: {
    controller: ["admin/gitlab_credits_dashboard", "admin/gitlab_credits_dashboard/users"]
  }
end
