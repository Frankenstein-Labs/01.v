# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FreeNamespaceCreateService, :saas, :with_current_organization,
  feature_category: :onboarding do
  let_it_be_with_reload(:user) do
    create(:user, organizations: [current_organization], onboarding_in_progress: true)
  end

  let(:group_name) { 'My group' }
  let(:project_name) { 'My project' }
  let(:namespace_id) { nil }
  let(:step) { described_class::FULL }

  let(:params) do
    {
      step: step,
      first_name: 'Jane',
      last_name: 'Doe',
      company_name: 'Acme',
      country: 'US',
      state: 'CA',
      group_name: group_name,
      project_name: project_name,
      onboarding_status_role: '0',
      onboarding_status_setup_for_company: 'false',
      onboarding_status_registration_objective: '1',
      glm_source: 'some_source',
      glm_content: 'some_content',
      jobs_to_be_done_other: '_jobs_to_be_done_other_',
      organization_id: current_organization.id
    }
  end

  subject(:execute) do
    described_class.new(user: user, params: params, step: step, namespace_id: namespace_id).execute
  end

  context 'when the step is unrecognized' do
    let(:step) { 'bogus_step' }

    it 'returns a not found error without touching any stage' do
      expect(::Groups::CreateService).not_to receive(:new)
      expect(::Projects::CreateService).not_to receive(:new)

      response = execute

      expect(response).to be_error
      expect(response.reason).to eq(described_class::NOT_FOUND)
    end
  end

  context 'when all three stages succeed' do
    it 'creates the group and project, finishes onboarding, and fires the expected side effects',
      :aggregate_failures do
      expect(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async).once
      expect(::Groups::CreateEventWorker).to receive(:perform_async).with(anything, user.id, 'created')
      expect(::Onboarding::Progress).to receive(:onboard).with(an_instance_of(Group))
      expect(::Gitlab::Tracking)
        .to receive(:event).with(described_class.name, 'create_group', namespace: an_instance_of(Group), user: user)
      expect(::Gitlab::Tracking)
        .to receive(:event).with(described_class.name, 'create_project', namespace: an_instance_of(Group), user: user)

      response = nil
      expect { response = execute }
        .to change { Group.count }.by(1)
        .and change { Project.count }.by(1)
        .and change { NamespaceSetting.enable_duo_code_review_by_default_pending.count }.by(1)

      expect(response).to be_success
      expect(response.payload[:project]).to eq(Project.last)
      expect(user.reset.onboarding_in_progress).to be(false)
    end

    it 'persists the onboarding status fields to the user', :aggregate_failures do
      execute

      expect(user.reset.onboarding_status_role).to eq(0)
      expect(user.onboarding_status_setup_for_company).to be(false)
      expect(user.onboarding_status_registration_objective).to eq(1)
    end

    it 'passes the expected iterable params to the trigger worker' do
      expect(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async).with(
        hash_including(
          'provider' => 'gitlab',
          'create_account' => true,
          'skip_email_confirmation' => true,
          'first_name' => 'Jane',
          'last_name' => 'Doe',
          'company_name' => 'Acme',
          'country' => 'US',
          'state' => 'CA',
          'work_email' => user.email,
          'uid' => user.id,
          'comment' => '_jobs_to_be_done_other_'
        )
      )

      execute
    end
  end

  context 'when resuming at the group stage (GROUP_FLOW)' do
    let(:step) { described_class::GROUP_FLOW }

    it 'creates the group and project without re-running the user stage', :aggregate_failures do
      expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

      response = nil
      expect { response = execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)
      expect(response).to be_success
      expect(response.payload[:project]).to eq(Project.last)
    end

    context 'when the user cannot create a group' do
      before do
        allow(user).to receive(:can_create_group?).and_return(false)
      end

      it 'returns a not found error without creating anything', :aggregate_failures do
        expect(::Groups::CreateService).not_to receive(:new)

        response = nil
        expect { response = execute }.to not_change { Group.count }.and not_change { Project.count }
        expect(response).to be_error
        expect(response.reason).to eq(described_class::NOT_FOUND)
      end
    end
  end

  context 'when stage 1 (user signup) validation fails' do
    shared_examples 'an aborted user stage' do |error_field|
      it 'aborts before the group and project stages and reports the field error', :aggregate_failures do
        expect(::Groups::CreateService).not_to receive(:new)
        expect(::Projects::CreateService).not_to receive(:new)
        expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

        response = nil
        expect { response = execute }.to not_change { Group.count }.and not_change { Project.count }

        expect(response).to be_error
        expect(response.reason).to eq(described_class::USER_VALIDATION_FAILED)
        expect(response.payload[:model_errors][error_field]).to be_present
      end
    end

    context 'when the role is missing (presence validator)' do
      let(:params) { super().merge(onboarding_status_role: nil) }

      it_behaves_like 'an aborted user stage', :role
    end

    context 'when setup_for_company is absent (inclusion validator)' do
      let(:params) { super().except(:onboarding_status_setup_for_company) }

      it_behaves_like 'an aborted user stage', :setup_for_company
    end
  end

  context 'when stage 2 (group) fails' do
    let(:group_name) { '   ' }

    it 'does not create a group or project' do
      expect { execute }.to not_change { Group.count }.and not_change { Project.count }
    end

    it 'returns a namespace creation error without a namespace id' do
      response = execute

      expect(response).to be_error
      expect(response.reason).to eq(described_class::NAMESPACE_CREATE_FAILED)
      expect(response.payload[:namespace_id]).to be_nil
      expect(response.payload[:model_errors]).to have_key(:group_name)
    end
  end

  context 'when stage 3 (project) fails' do
    let(:project_name) { '   ' }

    it 'creates the group but not the project' do
      expect { execute }.to change { Group.count }.by(1).and not_change { Project.count }
    end

    it 'returns a project creation error that round-trips the group id' do
      response = execute

      expect(response).to be_error
      expect(response.reason).to eq(described_class::PROJECT_CREATE_FAILED)
      expect(response.payload[:namespace_id]).to eq(Group.last.id)
      expect(response.payload[:model_errors]).to have_key(:project_name)
    end
  end

  context 'when retried after a project failure with the persisted group id (PROJECT_FLOW)' do
    let_it_be(:group) { create(:group, name: 'Existing group', organization: current_organization) }

    let(:namespace_id) { group.id }
    let(:project_name) { 'Recovered project' }
    let(:step) { described_class::PROJECT_FLOW }

    before_all do
      group.add_owner(user)
    end

    it 'does not re-run the user stage or re-create the group, and does not re-fire the iterable worker' do
      expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

      expect { execute }.to not_change { Group.count }.and change { Project.count }.by(1)
    end

    it 'succeeds and returns the recovered project' do
      response = execute

      expect(response).to be_success
      expect(response.payload[:project]).to eq(Project.last)
    end

    context 'when the namespace does not exist' do
      let(:namespace_id) { non_existing_record_id }

      it 'returns a not found error without creating a project', :aggregate_failures do
        expect(::Projects::CreateService).not_to receive(:new)

        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(described_class::NOT_FOUND)
      end
    end

    context 'when the namespace is not owned by the user' do
      let_it_be(:unrelated_group) { create(:group, organization: current_organization) }

      let(:namespace_id) { unrelated_group.id }

      it 'returns a not found error without creating a project', :aggregate_failures do
        expect(::Projects::CreateService).not_to receive(:new)

        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(described_class::NOT_FOUND)
      end
    end

    context 'when the user cannot create a project' do
      before do
        allow(user).to receive(:can_create_project?).and_return(false)
      end

      it 'returns a not found error without creating a project', :aggregate_failures do
        expect(::Projects::CreateService).not_to receive(:new)

        response = nil
        expect { response = execute }.to not_change { Project.count }
        expect(response).to be_error
        expect(response.reason).to eq(described_class::NOT_FOUND)
      end
    end
  end
end
