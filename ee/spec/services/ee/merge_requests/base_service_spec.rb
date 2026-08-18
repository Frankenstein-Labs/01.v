# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::BaseService, feature_category: :code_review_workflow do
  include ProjectForksHelper

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:status_checks) { create_list(:external_status_check, 3, project: project) }

  let(:user) { project.first_owner }
  let(:title) { 'Awesome merge_request' }
  let(:params) do
    {
      title: title,
      description: 'please fix',
      source_branch: 'feature',
      target_branch: 'master',
      squash: false
    }
  end

  subject { MergeRequests::CreateService.new(project: project, current_user: user, params: params) }

  it 'does not fire compliance hooks' do
    expect(project).not_to receive(:execute_external_compliance_hooks)

    subject.execute
  end

  context 'for UpdateService' do
    subject { MergeRequests::UpdateService.new(project: project, current_user: user, params: params) }

    let(:merge_request) do
      create(:merge_request, :simple, title: 'Old title',
        assignee_ids: [user.id],
        source_project: project,
        author: user)
    end

    it 'fires the correct number of compliance hooks' do
      expect(project).to receive(:execute_external_compliance_hooks).once.and_call_original

      subject.execute(merge_request)
    end
  end

  describe '#merge_requests_for_approval_reset' do
    let(:project) do
      create(:project, :repository, reset_approvals_on_push: true, approvals_before_merge: 1)
    end

    let(:user) { project.first_owner }

    let!(:merge_request) do
      create(:merge_request,
        source_project: project,
        source_branch: 'feature',
        target_project: project,
        target_branch: 'master',
        author: user
      )
    end

    let!(:approval) { create(:approval, merge_request: merge_request, user: user) }
    let!(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

    let(:service_instance) { MergeRequests::CreateService.new(project: project, current_user: user, params: params) }

    it 'preloads source_project' do
      merge_requests = service_instance.send(:merge_requests_for_approval_reset, 'feature')

      merge_requests.each do |mr|
        expect(mr.association(:source_project)).to be_loaded
      end
    end
  end

  describe '#filter_params' do
    let(:params_filtering_service) { double(:params_filtering_service) }

    context 'filter users and groups' do
      before do
        allow(subject).to receive(:execute_hooks)
      end

      it 'calls ParamsFilteringService' do
        expect(ApprovalRules::ParamsFilteringService).to receive(:new).with(
          an_instance_of(MergeRequest),
          project.first_owner,
          params
        ).and_return(params_filtering_service)
        expect(params_filtering_service).to receive(:execute).and_return(params)

        subject.execute
      end
    end
  end
end
