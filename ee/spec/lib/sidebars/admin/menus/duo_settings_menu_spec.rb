# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::DuoSettingsMenu, feature_category: :navigation do
  it_behaves_like 'Admin menu',
    link: '/admin/gitlab_duo',
    title: _('GitLab Duo'),
    icon: 'tanuki-ai'

  it_behaves_like 'Admin menu without sub menus', active_routes: {
    action: %w[show index],
    controller: [:gitlab_duo, :seat_utilization, :configuration]
  }
end
