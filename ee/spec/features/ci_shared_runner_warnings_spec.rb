# frozen_string_literal: true

require 'spec_helper'
require_relative './ci_shared_runner_alerts_shared_examples'

RSpec.describe 'CI shared runner limits', :with_trial_types, feature_category: :runner_core do
  include UsageQuotasHelpers
  include ::Ci::MinutesHelpers

  using RSpec::Parameterized::TableSyntax

  let_it_be(:owner) { create(:user) }
  let_it_be(:developer) { create(:user) }

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:namespace) { group }
  let_it_be_with_reload(:project) { create(:project, :repository, namespace: group, shared_runners_enabled: true) }
  let_it_be_with_reload(:pipeline) do
    create(:ci_empty_pipeline, project: project, sha: project.commit.sha, ref: 'master')
  end

  let_it_be_with_reload(:job) { create(:ci_build, pipeline: pipeline) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    group.add_member(owner, :owner)
    group.add_member(developer, :developer)

    sign_in(owner)
  end

  shared_examples 'group pages with alerts' do
    it_behaves_like 'page with the alert' do
      before do
        visit group_path(group)
      end
    end

    it_behaves_like 'page with the alert', true do
      before do
        visit group_usage_quotas_path(group)
      end
    end
  end

  shared_examples 'group pages with no alerts' do
    it_behaves_like 'page with no alerts' do
      before do
        visit group_path(group)
      end
    end

    it_behaves_like 'page with no alerts' do
      before do
        visit group_usage_quotas_path(group)
      end
    end
  end

  context 'when the limit is not exceeded' do
    before do
      set_sharded_ci_minutes_used(group, 500, project: project)
      group.update!(shared_runners_minutes_limit: 1000)
    end

    it_behaves_like 'project pages with no alerts'
    it_behaves_like 'group pages with no alerts'
  end

  context 'when close to the limit' do
    where(:case_name, :minutes_used, :minutes_limit, :displayed_usage) do
      'warning level' | 750 | 1000 | '250 / 1,000 (25%)'
      'danger level'  | 950 | 1000 | '50 / 1,000 (5%)'
    end

    with_them do
      let(:message) do
        "#{group.name} namespace has #{displayed_usage} shared runner " \
          "compute minutes remaining. When all compute minutes are used up, no new jobs or pipelines will run " \
          "in this namespace's projects."
      end

      before do
        set_sharded_ci_minutes_used(group, minutes_used, project: project)
        group.update!(shared_runners_minutes_limit: minutes_limit)
      end

      it_behaves_like 'project pages with alerts'
      it_behaves_like 'group pages with alerts'

      context 'when user role is not eligible to see the alert' do
        before do
          sign_in(developer)
        end

        it_behaves_like 'project pages with no alerts'
        it_behaves_like 'group pages with no alerts'
      end
    end
  end

  context 'when the limit is exceeded' do
    let(:message) do
      "#{group.name} namespace has reached its shared runner compute minutes quota. " \
        "To run new jobs and pipelines in this namespace's projects, buy additional compute minutes."
    end

    before do
      set_sharded_ci_minutes_used(group, 1001, project: project)
      group.update!(shared_runners_minutes_limit: 1000)
    end

    it_behaves_like 'project pages with alerts'
    it_behaves_like 'group pages with alerts'

    context 'when user role is not eligible to see the alert' do
      before do
        sign_in(developer)
      end

      it_behaves_like 'project pages with no alerts'
      it_behaves_like 'group pages with no alerts'
    end

    context 'when in a subgroup', :saas do
      let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
      let_it_be_with_reload(:subproject) do
        create(:project, :repository, namespace: subgroup, shared_runners_enabled: true)
      end

      let_it_be_with_reload(:pipeline) do
        create(:ci_empty_pipeline, project: subproject, sha: subproject.commit.sha, ref: 'master')
      end

      let_it_be_with_reload(:job) { create(:ci_build, pipeline: pipeline) }

      it_behaves_like 'page with the alert' do
        before do
          visit project_path(subproject)
        end
      end

      context 'when user role is not eligible to see the alert' do
        before do
          sign_in(developer)
          visit project_path(subproject)
        end

        it_behaves_like 'page with no alerts'
      end
    end
  end
end
