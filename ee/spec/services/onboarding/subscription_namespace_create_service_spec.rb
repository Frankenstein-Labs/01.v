# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::SubscriptionNamespaceCreateService, :saas, feature_category: :acquisition do
  include SaasRegistrationHelpers

  let(:step) { described_class::FULL }

  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let(:params) do
    {
      first_name: 'Test',
      last_name: 'User',
      group_name: 'Test Group',
      project_name: 'Test Project',
      organization_id: organization.id,
      company_name: 'Test Company'
    }
  end

  let(:plan_id) { '2c92a0fc8d4c41510000000000000000' }

  let(:lead_params) do
    {
      work_email: user.email,
      opt_in: user.onboarding_status_email_opt_in,
      skip_country_validation: true,
      product_interaction: 'Direct Purchase Account Creation Premium Dotcom',
      plan_id: plan_id,
      first_name: 'Test',
      last_name: 'User',
      company_name: 'Test Company'
    }
  end

  subject(:execute) do
    described_class.new(user: user, params: params, plan_id: plan_id, step: step).execute
  end

  before_all do
    create(:organization_user, organization: organization, user: user)
  end

  before do
    allow(::Onboarding::Progress).to receive(:onboard)
    allow(Gitlab::AppJsonLogger).to receive(:info).and_call_original
  end

  describe '#execute' do
    describe 'FULL flow - creating new group and project' do
      context 'when user can create group and project' do
        it 'creates group and project successfully', :aggregate_failures do
          expect_create_hand_raise_lead_success(lead_params)

          result = nil
          expect { result = execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)

          expect(result).to be_success
          expect(result.message).to eq('Group and project created')
          expect(result.payload[:namespace]).to be_a(Group)
          expect(result.payload[:project]).to be_a(Project)
          expect(result.payload[:project].namespace).to eq(result.payload[:namespace])
        end
      end

      context 'when user cannot create group' do
        before do
          allow(user).to receive(:can_create_group?).and_return(false)
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end

        it 'does not create group or project' do
          expect { execute }.not_to change { Group.count }
        end

        it 'does not create project' do
          expect { execute }.not_to change { Project.count }
        end
      end

      context 'when group creation fails' do
        before do
          params[:group_name] = ''
        end

        it 'returns namespace_create_failed error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:namespace_create_failed)
          expect(execute.message).to eq('Namespace creation failed')

          expect(Gitlab::AppJsonLogger).to have_received(:info).with(
            hash_including(class_name: described_class.name, message: /Namespace creation failed/)
          )
        end
      end

      context 'when group creation fails - does not create project' do
        before do
          params[:group_name] = ''
        end

        it 'does not create project' do
          expect { execute }.not_to change { Project.count }
        end
      end

      context 'when group creation fails - includes payload' do
        before do
          params[:group_name] = ''
        end

        it 'includes error messages in payload' do
          result = execute

          expect(result.payload[:model_errors]).to have_key(:group_name)
          expect(result.payload[:model_errors][:group_name]).to be_present
        end
      end

      context 'when user cannot create project' do
        before do
          allow(user).to receive(:can_create_project?).and_return(false)
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when project creation fails' do
        before do
          params[:project_name] = ''
        end

        it 'returns project_create_failed error' do
          expect { execute }.to change { Group.count }.by(1)

          expect(execute).to be_error
          expect(execute.reason).to eq(:project_create_failed)
          expect(execute.message).to eq('Project creation failed')

          expect(Gitlab::AppJsonLogger).to have_received(:info).with(
            hash_including(class_name: described_class.name, message: /Project creation failed/)
          )
        end
      end

      context 'when project creation fails - includes payload' do
        before do
          params[:project_name] = ''
        end

        it 'includes error messages in payload' do
          execute

          expect(execute.payload[:model_errors]).to have_key(:project_name)
        end
      end
    end

    describe 'GROUP_FLOW - creating new group only' do
      let(:step) { described_class::GROUP_FLOW }

      context 'when user can create group' do
        it 'creates group and project successfully', :aggregate_failures do
          expect_create_hand_raise_lead_success(lead_params)

          result = nil
          expect { result = execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)

          expect(result).to be_success
          expect(result.message).to eq('Group and project created')
          expect(result.payload[:namespace]).to be_a(Group)
          expect(result.payload[:project]).to be_a(Project)
        end
      end

      context 'when user cannot create group' do
        before do
          allow(user).to receive(:can_create_group?).and_return(false)
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when group creation fails' do
        before do
          params[:group_name] = ''
        end

        it 'returns namespace_create_failed error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:namespace_create_failed)
        end

        it 'includes error messages in payload' do
          result = execute

          expect(result.payload[:model_errors]).to have_key(:group_name)
        end
      end
    end

    describe 'PROJECT_FLOW - creating project in existing namespace' do
      let(:step) { described_class::PROJECT_FLOW }

      subject(:execute) do
        described_class.new(
          user: user, params: params, plan_id: plan_id,
          step: step, namespace_id: namespace.id
        ).execute
      end

      before_all do
        namespace.add_owner(user)
      end

      context 'when namespace exists and user is admin of it' do
        it 'creates project successfully', :aggregate_failures do
          expect_create_hand_raise_lead_success(lead_params)

          result = nil
          expect { result = execute }.to change { Project.count }.by(1).and not_change { Group.count }

          expect(result).to be_success
          expect(result.payload[:namespace]).to eq(namespace)
          expect(result.payload[:project]).to be_a(Project)
          expect(result.payload[:project].namespace).to eq(namespace)
        end
      end

      context 'when namespace does not exist' do
        subject(:execute) do
          described_class.new(
            user: user, params: params, plan_id: plan_id,
            step: step, namespace_id: non_existing_record_id
          ).execute
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when user is not admin of the namespace' do
        before do
          allow(user).to receive(:can?).with(:admin_namespace, namespace).and_return(false)
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when user cannot create project' do
        before do
          allow(user).to receive(:can_create_project?).and_return(false)
        end

        it 'returns not found error', :aggregate_failures do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when project creation fails' do
        before do
          params[:project_name] = ''
        end

        it 'returns project_create_failed error', :aggregate_failures do
          result = execute

          expect(result).to be_error
          expect(result.reason).to eq(:project_create_failed)
          expect(result.message).to eq('Project creation failed')
          expect(result.payload[:namespace_id]).to eq(namespace.id)
          expect(result.payload[:model_errors]).to have_key(:project_name)
        end
      end

      context 'when project_id is provided for an existing project' do
        subject(:execute) do
          described_class.new(
            user: user, params: params, plan_id: plan_id,
            step: step, namespace_id: namespace.id, project_id: project.id
          ).execute
        end

        it 'uses existing project and submits lead successfully', :aggregate_failures do
          expect_create_hand_raise_lead_success(lead_params)

          expect { execute }.to not_change { Project.count }.and not_change { Group.count }

          expect(execute).to be_success
          expect(execute.payload).to eq({ namespace: namespace, project: project })
        end

        context 'when project does not exist' do
          subject(:execute) do
            described_class.new(
              user: user, params: params, plan_id: plan_id,
              step: step, namespace_id: namespace.id, project_id: non_existing_record_id
            ).execute
          end

          it 'returns not found error', :aggregate_failures do
            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end

        context 'when user is not admin of the project' do
          before do
            allow(user).to receive(:can?).and_call_original
            allow(user).to receive(:can?).with(:admin_project, project).and_return(false)
          end

          it 'returns not found error', :aggregate_failures do
            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end
      end
    end

    describe 'LEAD_FLOW - submitting lead for existing namespace and project' do
      let(:step) { described_class::LEAD_FLOW }

      subject(:execute) do
        described_class.new(
          user: user, params: params, plan_id: plan_id,
          step: step, namespace_id: namespace.id, project_id: project.id
        ).execute
      end

      before_all do
        namespace.add_owner(user)
      end

      context 'when namespace and project exist and user is admin of both' do
        it 'submits lead without creating group or project', :aggregate_failures do
          expect_create_hand_raise_lead_success(lead_params)

          expect { execute }.to not_change { Group.count }.and not_change { Project.count }

          expect(execute).to be_success
          expect(execute.payload).to eq({ namespace: namespace, project: project })
        end
      end

      context 'when namespace does not exist' do
        subject(:execute) do
          described_class.new(
            user: user, params: params, plan_id: plan_id,
            step: step, namespace_id: non_existing_record_id, project_id: project.id
          ).execute
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when project does not exist' do
        subject(:execute) do
          described_class.new(
            user: user, params: params, plan_id: plan_id,
            step: step, namespace_id: namespace.id, project_id: non_existing_record_id
          ).execute
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when user is not admin of the namespace' do
        before do
          allow(user).to receive(:can?).with(:admin_namespace, namespace).and_return(false)
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when user is not admin of the project' do
        before do
          allow(user).to receive(:can?).and_call_original
          allow(user).to receive(:can?).with(:admin_project, project).and_return(false)
        end

        it 'returns not found error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when lead creation fails' do
        it 'returns lead_failed error', :aggregate_failures do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |instance|
            expect(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Lead service error'))
          end

          result = execute

          expect(result).to be_error
          expect(result.message).to eq('')
          expect(result.payload).to eq(namespace_id: namespace.id, project_id: project.id)

          expect(Gitlab::AppJsonLogger)
            .to have_received(:info)
            .with(class_name: described_class.name, message: 'Lead submission failed')
        end
      end
    end

    describe 'invalid step' do
      let(:step) { 'invalid_step' }

      it 'returns not found error' do
        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    describe 'lead submission' do
      context 'when lead creation fails during FULL flow' do
        it 'still creates group and project' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |instance|
            expect(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Lead service error'))
          end

          expect { execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)
        end
      end
    end

    describe 'persisting the company name on the user' do
      let(:step) { described_class::LEAD_FLOW }

      subject(:execute) do
        described_class.new(
          user: user, params: params, plan_id: plan_id,
          step: step, namespace_id: namespace.id, project_id: project.id
        ).execute
      end

      before_all do
        namespace.add_owner(user)
      end

      before do
        expect_create_hand_raise_lead_success(lead_params)
      end

      it 'updates the user company so it is carried over to CustomersDot on auth' do
        expect { execute }.to change { user.reload.company }.to('Test Company')
      end

      context 'when the user update fails' do
        before do
          allow(user).to receive(:update).with(company: 'Test Company').and_return(false)
        end

        it 'still succeeds and logs the failure' do
          expect(execute).to be_success

          expect(Gitlab::AppJsonLogger).to have_received(:info).with(
            class_name: described_class.name, message: 'Failed to persist company name on user',
            Labkit::Fields::GL_USER_ID => user.id
          )
        end
      end

      context 'when company_name is blank' do
        let(:lead_params) { super().merge(company_name: '') }

        before do
          params[:company_name] = ''
          user.update!(company: 'Existing Company')
        end

        it 'does not overwrite the existing company' do
          expect { execute }.not_to change { user.reload.company }.from('Existing Company')
        end
      end
    end
  end
end
