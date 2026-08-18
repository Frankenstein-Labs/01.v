# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Deployments::ApprovalService, feature_category: :continuous_delivery do
  let_it_be(:project, refind: true) { create(:project, :repository) }

  let(:service) { described_class.new(project, user, params) }
  let(:params) { { comment: comment } }
  let(:user) { create(:user) }
  let(:environment) { create(:environment, project: project) }
  let(:status) { 'approved' }
  let(:comment) { nil }
  let(:job) { create(:ci_build, :manual, project: project) }
  let(:deployment) do
    create(
      :deployment,
      :blocked,
      project: project,
      environment: environment,
      deployable: job
    )
  end

  let!(:protected_environment) do
    create(
      :protected_environment,
      :maintainers_can_deploy,
      name: environment.name,
      project: project,
      approval_rules: approval_rules
    )
  end

  let(:approval_rules) { [build(:protected_environment_approval_rule, :maintainer_access)] }

  before do
    stub_licensed_features(protected_environments: true)
    project.add_maintainer(user) if user
  end

  shared_examples_for 'error' do |message:|
    it 'returns an error' do
      expect(deployment).not_to receive(:invalidate_cache)

      expect(subject[:status]).to eq(:error)
      expect(subject[:message]).to eq(message)
    end
  end

  shared_examples_for 'reject' do
    it 'rejects the deployment', :aggregate_failures do
      expect(deployment).to receive(:invalidate_cache).and_call_original

      expect(subject[:status]).to eq(:success)
      expect(subject[:approval].status).to eq('rejected')
      expect(subject[:approval].user).to eq(user)
      expect(subject[:approval].deployment).to eq(deployment)
      expect(deployment.approvals.approved.count).to eq(0)
      expect(deployment.approvals.rejected.count).to eq(1)
    end
  end

  shared_examples_for 'approve' do
    it 'approves the deployment', :aggregate_failures do
      expect(deployment).to receive(:invalidate_cache).and_call_original

      expect(subject[:status]).to eq(:success)
      expect(subject[:approval].status).to eq('approved')
      expect(subject[:approval].user).to eq(user)
      expect(subject[:approval].deployment).to eq(deployment)
      expect(deployment.approvals.approved.count).to eq(1)
      expect(deployment.approvals.rejected.count).to eq(0)
    end
  end

  shared_examples_for 'comment' do
    context 'with a comment' do
      let(:comment) { 'LGTM!' }

      it 'saves the comment' do
        expect(subject[:status]).to eq(:success)
        expect(subject[:approval].comment).to eq(comment)
      end
    end
  end

  shared_examples_for 'set approval rule' do
    context 'with approval rule' do
      let(:access_level_setting) { multi_access_level }
      let(:approval_rule) { approval_rules.first.reload }

      it 'sets an rule to the deployment approval' do
        expect(subject[:status]).to eq(:success)
        expect(subject[:approval].approval_rule).to eq(approval_rule)
        expect(::Deployments::Approval.last.approval_rule).to eq(approval_rule)
      end
    end
  end

  shared_examples_for 'audit event' do
    let(:comment) { 'LGTM!' }

    it 'creates an audit event' do
      expect(Gitlab::Audit::Auditor).to receive(:audit).with({
        name: "deployment_#{status}",
        author: user,
        scope: project,
        target: environment,
        message: "#{status.capitalize} deployment with IID: #{deployment.iid} and ID: #{deployment.id}",
        additional_details: {
          comment: comment
        }
      })

      subject
    end
  end

  shared_examples_for 'webhook event' do
    # A rejection drops the build, which fires the pre-existing deployment
    # lifecycle webhook (status: 'failed') in addition to the approval webhook.
    # Scope assertions to the approval webhook by matching on `approval_id`.
    context 'when the project has an active deployment_events web hook' do
      let!(:project_hook) { create(:project_hook, project: project, deployment_events: true) }

      it 'enqueues an async deployment webhook carrying the approval metadata' do
        allow(::Deployments::HooksWorker).to receive(:perform_async)

        subject

        expect(::Deployments::HooksWorker).to have_received(:perform_async).with(
          hash_including(
            'deployment_id' => deployment.id,
            'status' => status.to_s,
            'approval_id' => kind_of(Integer),
            'approver_id' => user.id
          )
        )
      end
    end

    context 'when the project has no active deployment hooks or integrations' do
      it 'does not enqueue an approval webhook' do
        allow(::Deployments::HooksWorker).to receive(:perform_async)

        subject

        expect(::Deployments::HooksWorker).not_to have_received(:perform_async).with(
          hash_including('approval_id' => anything)
        )
      end
    end
  end

  describe '#execute' do
    subject { service.execute(deployment, status) }

    context 'when status is approved' do
      include_examples 'approve'
      include_examples 'comment'
      include_examples 'set approval rule'
      include_examples 'audit event'
      include_examples 'webhook event'
    end

    context 'when status is rejected' do
      let(:status) { 'rejected' }

      include_examples 'reject'
      include_examples 'comment'
      include_examples 'set approval rule'
      include_examples 'audit event'
      include_examples 'webhook event'
    end

    context 'when user approves for different groups' do
      let!(:group1) { create(:group, name: 'group1') }
      let!(:group2) { create(:group, name: 'group2') }

      let!(:approval_rule1) do
        create(
          :protected_environment_approval_rule,
          group: group1,
          protected_environment: protected_environment
        )
      end

      let!(:approval_rule2) do
        create(
          :protected_environment_approval_rule,
          group: group2,
          protected_environment: protected_environment
        )
      end

      before do
        group1.add_maintainer(user)
        group2.add_maintainer(user)
      end

      it 'creates a new approval', :aggregate_failures do
        service = described_class.new(project, user, params.merge(represented_as: 'group1'))
        deployment.reload
        service_result1 = service.execute(deployment, status)
        expect(service_result1[:approval].approval_rule).to eq(approval_rule1)

        service = described_class.new(project, user, params.merge(represented_as: 'group2'))
        service_result2 = service.execute(deployment, status)
        expect(service_result2[:approval].approval_rule).to eq(approval_rule2)

        expect(service_result1[:approval].id)
          .not_to eq(service_result2[:approval].id)
      end
    end

    context 'when user already approved' do
      let(:comment) { 'Original comment' }

      let(:approval_rules) do
        [
          build(
            :protected_environment_approval_rule,
            :maintainer_access,
            required_approvals: 2
          )
        ]
      end

      before do
        service.execute(deployment, :approved)
      end

      context 'and is approving again' do
        it 'is a no-op that does not fire the side effects again', :aggregate_failures do
          expect(deployment).not_to receive(:invalidate_cache)
          expect(::Deployments::HooksWorker).not_to receive(:perform_async)
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          expect(subject[:status]).to eq(:success)
          expect(subject[:approval].status).to eq('approved')
          expect(deployment.approvals.approved.count).to eq(1)
        end

        context 'with a different comment' do
          it 'does not change the comment' do
            service = described_class.new(project, user, params.merge(comment: 'Changed comment'))

            expect(service.execute(deployment, status)[:approval].comment).to eq('Original comment')
          end
        end
      end

      context 'and is rejecting' do
        let(:status) { 'rejected' }

        include_examples 'reject'

        context 'with a different comment' do
          it 'changes the comment' do
            service = described_class.new(project, user, params.merge(comment: 'Changed comment'))

            expect(service.execute(deployment, status)[:approval].comment).to eq('Changed comment')
          end
        end
      end
    end

    context 'processing the build with multi access levels' do
      context 'when build is nil' do
        before do
          deployment.deployable = nil
        end

        it 'does not raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when deployment was rejected' do
        let(:status) { 'rejected' }

        it 'drops the build' do
          subject

          expect(deployment.deployable.status).to eq('failed')
          expect(deployment.deployable.failure_reason).to eq('deployment_rejected')
        end
      end

      context 'when no additional approvals are required' do
        let(:access_level_setting) { multi_access_level }
        let(:approval_rules) { [build(:protected_environment_approval_rule, :maintainer_access, required_approvals: 1)] }

        it 'keeps the build manual' do
          expect { subject }.not_to change { deployment.deployable.status }

          expect(deployment.deployable).to be_manual
        end

        it 'keeps the deployment blocked' do
          expect { subject }.not_to change { deployment.status }
        end
      end

      context 'when additional approvals are required' do
        let(:access_level_setting) { multi_access_level }
        let(:approval_rules) { [build(:protected_environment_approval_rule, :maintainer_access, required_approvals: 2)] }

        it 'does not change the build' do
          expect { subject }.not_to change { deployment.deployable.reload.status }
        end
      end
    end

    context 'validations' do
      context 'when status is not recognized' do
        let(:status) { 'foo' }

        include_examples 'error', message: 'Unrecognized approval status.'
      end

      context 'when environment is not protected' do
        let(:deployment) { create(:deployment, :blocked, project: project, deployable: job) }

        include_examples 'error', message: 'This environment is not protected.'
      end

      context 'when Protected Environments feature is not available' do
        before do
          stub_licensed_features(protected_environments: false)
        end

        include_examples 'error', message: 'This environment is not protected.'
      end

      context 'when deployment approval is not configured' do
        let(:approval_rules) { [] }

        include_examples 'error', message: 'Deployment approvals is not configured for this environment.'
      end

      context 'when the user does not have permission to update deployment' do
        before do
          project.add_developer(user)
        end

        include_examples 'error', message: "You don't have permission to approve this deployment. Contact the project or group owner for help."
      end

      context 'with approval rule' do
        let!(:approval_rule) { create(:protected_environment_approval_rule, :maintainer_access, protected_environment: protected_environment) }

        context 'when the user does not have permission to read deployment' do
          before do
            project.add_guest(user)
          end

          include_examples 'error', message: "You don't have permission to approve this deployment. Contact the project or group owner for help."
        end

        context 'when there are no rules for the user' do
          before do
            project.add_developer(user)
          end

          include_examples 'error', message: "You don't have permission to approve this deployment. Contact the project or group owner for help."
        end

        context 'when there are no approval rules that match represented_as' do
          let!(:group) { create(:group, name: 'QA group') }

          let!(:approval_rule) do
            create(:protected_environment_approval_rule, group: group, protected_environment: protected_environment)
          end

          let(:params) { { represented_as: 'Developer group' } }

          before do
            group.add_maintainer(user)
          end

          include_examples 'error', message: "There are no approval rules for the given `represent_as` parameter. Use a valid User/Group/Role name instead."
        end
      end

      context 'when user is nil' do
        let(:user) { nil }

        include_examples 'error', message: "You don't have permission to approve this deployment. Contact the project or group owner for help."
      end

      context 'when deployment is not waiting for approvals' do
        let(:deployment) { create(:deployment, project: project, environment: environment, deployable: job) }

        before do
          allow(deployment).to receive(:waiting_for_approval?).and_return(false)
        end

        include_examples 'error', message: 'This deployment is not waiting for approvals.'
      end

      context 'when the creator of the deployment is approving' do
        before do
          deployment.user = user
        end

        context 'when allow pipeline triggerer to approve deployment' do
          before do
            project.project_setting.update!(allow_pipeline_trigger_approve_deployment: true)
          end

          include_examples 'approve'
        end

        context 'when not allow pipeline triggerer to approve deployment' do
          before do
            project.project_setting.update!(allow_pipeline_trigger_approve_deployment: false)
          end

          include_examples 'error', message: 'You cannot approve your own deployment. This configuration can be adjusted in the protected environment settings.'
        end
      end

      context 'when the creator of the deployment is rejecting' do
        let(:status) { 'rejected' }

        before do
          deployment.update!(user: user)
        end

        include_examples 'reject'
      end
    end
  end
end
