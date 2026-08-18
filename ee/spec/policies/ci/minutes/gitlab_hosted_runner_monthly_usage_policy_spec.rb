# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::GitlabHostedRunnerMonthlyUsagePolicy, feature_category: :hosted_runners do
  let_it_be_with_reload(:current_user) { create(:admin) }
  let(:gitlab_hosted_runner_monthly_usage) { create(:ci_hosted_runner_monthly_usage) }

  subject(:policy) { described_class.new(current_user, gitlab_hosted_runner_monthly_usage) }

  context 'when GitLab instance is not dedicated' do
    before do
      stub_application_setting(gitlab_dedicated_instance: false)
    end

    it { is_expected.not_to be_allowed(:read_dedicated_hosted_runner_usage) }
  end

  context 'when GitLab instance is dedicated' do
    before do
      stub_application_setting(gitlab_dedicated_instance: true)
    end

    context 'when user is an admin', :enable_admin_mode do
      it { is_expected.to be_allowed(:read_dedicated_hosted_runner_usage) }
    end

    context 'when user is not an admin' do
      let(:current_user) { create(:user) }

      it { is_expected.not_to be_allowed(:read_dedicated_hosted_runner_usage) }
    end
  end
end
