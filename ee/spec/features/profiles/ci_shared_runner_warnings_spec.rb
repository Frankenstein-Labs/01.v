# frozen_string_literal: true

require 'spec_helper'
require_relative '../ci_shared_runner_alerts_shared_examples'

RSpec.describe 'Profile > CI shared runner limits', :freeze_time, feature_category: :runner_core do
  include ::Ci::MinutesHelpers
  include UsageQuotasHelpers

  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:namespace) { user.namespace }
  let_it_be_with_reload(:statistics) { create(:namespace_statistics, namespace: namespace) }
  let_it_be_with_reload(:project) do
    create(:project, :repository, namespace: namespace, shared_runners_enabled: true)
  end

  let_it_be(:pipeline) { create(:ci_empty_pipeline, project: project, sha: project.commit.sha, ref: 'master') }
  let_it_be(:job) { create(:ci_build, pipeline: pipeline) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    sign_in(user)
  end

  context 'when the limit is not exceeded' do
    before do
      set_sharded_ci_minutes_used(namespace, 0, project: project)
      namespace.update!(shared_runners_minutes_limit: 100)
    end

    it_behaves_like 'project pages with no alerts'
  end

  context 'when close to the limit' do
    where(:case_name, :minutes_used, :minutes_limit, :displayed_usage) do
      'warning level' | 750 | 1000 | '250 / 1,000 (25%)'
      'danger level'  | 950 | 1000 | '50 / 1,000 (5%)'
    end

    with_them do
      let(:message) do
        "#{namespace.name} namespace has #{displayed_usage} shared runner " \
          "compute minutes remaining. When all compute minutes are used up, no new jobs or pipelines will run " \
          "in this namespace's projects."
      end

      before do
        set_sharded_ci_minutes_used(namespace, minutes_used, project: project)
        namespace.update!(shared_runners_minutes_limit: minutes_limit)
      end

      it_behaves_like 'project pages with alerts'

      it_behaves_like 'page with the alert', true do
        before do
          visit profile_usage_quotas_path(namespace)
        end
      end
    end
  end

  context 'when limit is exceeded' do
    before do
      set_sharded_ci_minutes_used(namespace, 101, project: project)
      namespace.update!(shared_runners_minutes_limit: 100)
    end

    let(:message) do
      "#{namespace.name} namespace has reached its shared runner compute minutes quota. " \
        "To run new jobs and pipelines in this namespace's projects, buy additional compute minutes."
    end

    it_behaves_like 'project pages with alerts'

    it_behaves_like 'page with the alert', true do
      before do
        visit profile_usage_quotas_path(namespace)
      end
    end
  end
end
