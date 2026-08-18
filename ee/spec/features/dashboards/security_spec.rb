# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Security dashboard', :js, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:current_organization) { user.organization }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  it_behaves_like 'a "Your work" page with sidebar and breadcrumbs', :security_dashboard_path, :security_dashboard
end
