# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User sees feature flag list', :js, feature_category: :feature_flags do
  include FeatureFlagHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, namespace: user.namespace, developers: user) }

  before do
    sign_in(user)
  end

  context 'with too many feature flags' do
    before do
      plan_limits = create(:plan_limits, :default_plan)
      plan_limits.update!(Operations::FeatureFlag.limit_name => 1)
      create(:operations_feature_flag, :new_version_flag, project: project, active: false)
    end

    it 'stops users from adding another' do
      visit(project_feature_flags_path(project))
      expect(page).to have_text("You've reached your feature flag limit (1). To add more, delete at least one feature flag, or upgrade to a higher tier.")
    end
  end
end
