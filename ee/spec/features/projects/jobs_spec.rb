# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe 'Jobs', :js, :clean_gitlab_redis_shared_state, :saas, feature_category: :continuous_integration do
  let_it_be(:group) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:user_access_level) { :developer }

  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:job) { create(:ci_build, :trace_live, pipeline: pipeline) }

  include_context 'with duo features enabled and agentic chat available for group on SaaS'

  before_all do
    project.add_role(user, user_access_level)
  end

  before do
    sign_in(user)
  end

  context 'when job is failed' do
    let(:job) { create(:ci_build, :trace_artifact, :failed, pipeline: pipeline) }

    before do
      add_on_purchase = create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
      create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: add_on_purchase)
    end

    it_behaves_like 'user can troubleshoot job failure' do
      subject { project_job_path(project, job) }
    end

    it_behaves_like 'user can use agentic chat', quarantine: {
      issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/43262',
      type: 'flaky'
    } do
      subject { project_job_path(project, job) }
    end

    it_behaves_like 'user can navigate AI panel using navigation rail' do
      subject { project_job_path(project, job) }
    end
  end

  describe "GET /:project/jobs/:id", :js do
    context 'when job is not running', :js do
      let(:job) { create(:ci_build, :success, :trace_artifact, pipeline: pipeline) }

      before do
        stub_application_setting(ci_job_live_trace_enabled: true)
      end

      context 'when namespace is in read-only mode' do
        before do
          # Trigger read-only mode via storage limit to avoid association loading issues with direct Namespace stubbing
          allow_next_instance_of(::Namespaces::Storage::RootSize) do |size_checker|
            allow(size_checker).to receive(:above_size_limit?).and_return(true)
          end
        end

        it 'does not show retry button' do
          visit project_job_path(project, job)
          wait_for_requests

          expect(page).not_to have_link('Retry')
          expect(page).to have_content('Job succeeded')
        end
      end
    end
  end
end
