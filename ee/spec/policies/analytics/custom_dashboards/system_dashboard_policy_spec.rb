# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::SystemDashboardPolicy, feature_category: :custom_dashboards_foundation do
  include PolicyHelpers

  let(:system_dashboard) do
    Analytics::CustomDashboards::SystemDashboard.new(
      slug: 'gitlab_duo',
      config: { 'title' => 'Test', 'version' => '2', 'panels' => [] }
    )
  end

  subject(:policy) { described_class.new(user, system_dashboard) }

  describe 'rules' do
    context 'when user is authenticated' do
      let(:user) { build(:user) }

      it { expect_allowed(:read_system_dashboard) }
    end

    context 'when user is anonymous' do
      let(:user) { nil }

      it { expect_disallowed(:read_system_dashboard) }
    end
  end
end
