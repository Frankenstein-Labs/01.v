# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::TrialNamespaceCreateService, :saas, feature_category: :acquisition do
  include TrialHelpers

  let_it_be_with_reload(:user) do
    create(
      :user,
      onboarding_in_progress: true,
      onboarding_status_registration_type: ::Onboarding::REGISTRATION_TYPE[:trial],
      onboarding_status_initial_registration_type: ::Onboarding::REGISTRATION_TYPE[:trial]
    )
  end

  let_it_be(:organization) { create(:organization, users: [user]) }
  let_it_be(:existing_group) { create(:group_with_plan, plan: :free_plan, owners: user) }
  let_it_be(:existing_project) { create(:project, namespace: existing_group) }
  let_it_be(:unrelated_group) { create(:group_with_plan, plan: :free_plan) }
  let_it_be(:unrelated_project) { create(:project, namespace: unrelated_group) }

  let(:glm_params) { { glm_source: 'some-source', glm_content: 'some-content' } }

  let(:params) do
    {
      company_name: 'Test Company',
      country: 'US',
      state: 'CA',
      project_name: 'Test Project',
      group_name: 'gitlab',
      organization_id: organization.id,
      onboarding_status_role: '0',
      onboarding_status_setup_for_company: 'true',
      onboarding_status_registration_objective: '1',
      first_name: user.first_name,
      last_name: user.last_name
    }.merge(glm_params)
  end

  let(:lead_params) do
    {
      trial_user: params.except(
        :namespace_id,
        :group_name,
        :project_name,
        :organization_id,
        :onboarding_status_role,
        :onboarding_status_setup_for_company,
        :onboarding_status_registration_objective
      ).merge(
        {
          work_email: user.email,
          uid: user.id,
          setup_for_company: true,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab',
          product_interaction: 'SaaS Trial',
          first_name: user.first_name,
          last_name: user.last_name,
          role: 'software_developer',
          jtbd: 'move_repository'
        }
      )
    }
  end

  let(:step) { described_class::FULL }
  let(:namespace_id) { nil }
  let(:project_id) { nil }

  let(:lead_service_class) { GitlabSubscriptions::CreateLeadService }
  let(:apply_trial_worker_class) { GitlabSubscriptions::Trials::ApplyTrialWorker }

  subject(:execute) do
    described_class.new(
      params: params, user: user, step: step,
      namespace_id: namespace_id, project_id: project_id
    ).execute
  end

  before do
    allow(Gitlab::AppJsonLogger).to receive(:info).and_call_original
  end

  describe '#execute' do
    context 'with full step (default)' do
      it 'creates lead and applies trial successfully', :aggregate_failures do
        expect_create_lead_success(lead_params)
        expect_apply_trial_async(user, namespace: nil, extra_params: glm_params)

        expect { execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)
        expect(execute).to be_success
        expect(execute.message).to eq('Trial applied')
        expect(execute.payload).to eq({ namespace: Group.last, project: Project.last })
      end

      it 'saves onboarding_status fields to user', :aggregate_failures do
        expect_create_lead_success(lead_params)
        expect_apply_trial_async(user, namespace: nil, extra_params: glm_params)

        expect { execute }.to change { user.reload.onboarding_status_role }.from(nil).to(0)
          .and change { user.onboarding_status_setup_for_company }.from(nil).to(true)
          .and change { user.onboarding_status_registration_objective }.from(nil).to(1)
      end

      it 'ends onboarding' do
        expect_create_lead_success(lead_params)
        expect_apply_trial_async(user, namespace: nil, extra_params: glm_params)

        expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
      end

      context 'when persisting the trial conversion' do
        before do
          expect_create_lead_success(lead_params)
          expect_apply_trial_async(user, namespace: nil, extra_params: glm_params)
        end

        context 'when converting a free user' do
          let(:lead_params) do
            super().deep_merge(trial_user: { product_interaction: 'SaaS Trial - defaulted' })
          end

          before do
            user.user_detail.update!(
              onboarding_status_registration_type: ::Onboarding::REGISTRATION_TYPE[:free],
              onboarding_status_initial_registration_type: ::Onboarding::REGISTRATION_TYPE[:free]
            )
          end

          it 'sets registration_type to trial and leaves initial_registration_type untouched' do
            expect { execute }
              .to change { user.reload.onboarding_status_registration_type }
                .from(::Onboarding::REGISTRATION_TYPE[:free]).to(::Onboarding::REGISTRATION_TYPE[:trial])
              .and not_change { user.onboarding_status_initial_registration_type }
                .from(::Onboarding::REGISTRATION_TYPE[:free])
          end
        end
      end

      context 'when first_name and last_name are provided in params' do
        let(:params) { super().merge(first_name: 'Jane', last_name: 'Smith') }

        it 'uses form-submitted names in lead params' do
          lead_params_with_names = lead_params.deep_dup
          lead_params_with_names[:trial_user][:first_name] = 'Jane'
          lead_params_with_names[:trial_user][:last_name] = 'Smith'

          expect_create_lead_success(lead_params_with_names)
          expect_apply_trial_async(user, namespace: nil, extra_params: glm_params)

          execute
        end
      end

      context 'when user validation fails' do
        let(:params) { super().merge(onboarding_status_role: nil) }

        it 'returns error early without creating group or project' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_worker_class).not_to receive(:perform_async)
          expect(Groups::CreateService).not_to receive(:new)
          expect(Projects::CreateService).not_to receive(:new)

          expect(Gitlab::AppJsonLogger)
            .to receive(:info)
            .with(class_name: described_class.name, message: 'Trial creation failed in user stage')

          expect(execute).to be_error
          expect(execute.message).to eq('Trial creation failed in user stage')
          expect(execute.reason).to eq(:user_validation_failed)
          expect(execute.payload).not_to have_key(:namespace_id)
          expect(execute.payload).not_to have_key(:project_id)
          expect(execute.payload.dig(:model_errors, :role)).to eq("can't be blank")
        end
      end

      context 'when namespace creation fails' do
        let(:params) { super().merge(group_name: '  ') }

        it 'returns error with namespace_create_failed reason and does not attempt next steps' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_worker_class).not_to receive(:perform_async)
          expect(Projects::CreateService).not_to receive(:new)

          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(class_name: described_class.name, message: /Trial creation failed in namespace stage/)
          )

          expect(execute).to be_error
          expect(execute.message).to eq("Trial creation failed in namespace stage")
          expect(execute.reason).to eq(:namespace_create_failed)
          expect(execute.payload).not_to have_key(:namespace_id)
          expect(execute.payload).not_to have_key(:project_id)
          expect(execute.payload.dig(:model_errors, :group_name)).to include(/^Name can't be blank/)
        end
      end

      context 'when project creation fails' do
        let(:params) { super().merge(project_name: '  ') }

        it 'returns error with project_create_failed reason and does not attempt next steps' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_worker_class).not_to receive(:perform_async)

          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(class_name: described_class.name, message: /Trial creation failed in project stage/)
          )

          expect(execute).to be_error
          expect(execute.message).to eq("Trial creation failed in project stage")
          expect(execute.reason).to eq(:project_create_failed)
          expect(execute.payload).to include({ namespace_id: Group.last.id })
          expect(execute.payload).not_to have_key(:project_id)
          expect(execute.payload.dig(:model_errors, :project_name)).to include(/name can't be blank/)
        end
      end

      context 'when lead creation fails' do
        it 'returns error with lead_failed reason and does not attempt to submit trial' do
          expect_create_lead_fail(lead_params)
          expect(apply_trial_worker_class).not_to receive(:perform_async)

          expect(Gitlab::AppJsonLogger)
            .to receive(:info)
            .with(class_name: described_class.name, message: 'Trial creation failed in lead stage')

          expect(execute).to be_error
          expect(execute.message).to eq('')
          expect(execute.reason).to eq(:lead_failed)
          expect(execute.payload).to eq({ namespace_id: Group.last.id, project_id: Project.last.id })
        end
      end
    end

    context 'with resume steps (onboarding status already saved)' do
      before do
        user.update!(
          onboarding_status_role: params[:onboarding_status_role],
          onboarding_status_setup_for_company: params[:onboarding_status_setup_for_company],
          onboarding_status_registration_objective: params[:onboarding_status_registration_objective]
        )
        allow(GitlabSubscriptions::Trials)
          .to receive(:namespace_eligible?).with(existing_group).and_return(true)
      end

      context 'with group_flow step' do
        let(:step) { described_class::GROUP_FLOW }

        it 'creates group, project, lead and trial' do
          expect_create_lead_success(lead_params)
          expect_apply_trial_async(user, namespace: nil, extra_params: glm_params)

          expect { execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)
          expect(execute).to be_success
          expect(execute.message).to eq('Trial applied')
          expect(execute.payload).to eq({ namespace: Group.last, project: Project.last })
        end

        context 'when user cannot create group' do
          before do
            allow(user).to receive(:can_create_group?).and_return(false)
          end

          it 'returns not found error' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end
      end

      context 'with project_flow step' do
        let(:step) { described_class::PROJECT_FLOW }
        let(:namespace_id) { existing_group.id }

        it 'uses existing group and creates project' do
          expect_create_lead_success(lead_params)
          expect_apply_trial_async(user, namespace: existing_group, extra_params: glm_params)

          expect { execute }.to not_change { Group.count }.and change { Project.count }.by(1)
          expect(execute).to be_success
          expect(execute.message).to eq('Trial applied')
          expect(execute.payload).to eq({ namespace: existing_group, project: Project.last })
        end

        context 'when project_id is provided' do
          let(:project_id) { existing_project.id }

          it 'uses existing project and submits lead and trial' do
            expect_create_lead_success(lead_params)
            expect_apply_trial_async(user, namespace: existing_group, extra_params: glm_params)

            expect { execute }.to not_change { Group.count }.and not_change { Project.count }
            expect(execute).to be_success
            expect(execute.payload).to eq({ namespace: existing_group, project: existing_project })
          end

          context 'when project does not exist' do
            let(:project_id) { non_existing_record_id }

            it 'returns not found error' do
              expect(lead_service_class).not_to receive(:new)
              expect(apply_trial_worker_class).not_to receive(:perform_async)

              expect(execute).to be_error
              expect(execute.reason).to eq(:not_found)
            end
          end

          context 'when user does not have admin access to the project' do
            let(:project_id) { unrelated_project.id }

            it 'returns not found error' do
              expect(lead_service_class).not_to receive(:new)
              expect(apply_trial_worker_class).not_to receive(:perform_async)

              expect(execute).to be_error
              expect(execute.reason).to eq(:not_found)
            end
          end
        end

        context 'when user cannot create project' do
          before do
            allow(user).to receive(:can_create_project?).and_return(false)
          end

          it 'returns not found error' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect { execute }.to not_change { Group.count }.and not_change { Project.count }
            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end

        context "when namespace_id does not exist" do
          let(:namespace_id) { non_existing_record_id }

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end

        context "when namespace isn't owned by user" do
          let(:namespace_id) { unrelated_group.id }

          before do
            allow(GitlabSubscriptions::Trials).to receive(:namespace_eligible?).with(unrelated_group).and_return(true)
          end

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.message).to eq('Not found')
            expect(execute.reason).to eq(:not_found)
          end
        end
      end

      context 'with lead_flow step' do
        let(:step) { described_class::LEAD_FLOW }
        let(:namespace_id) { existing_group.id }
        let(:project_id) { existing_project.id }

        it 'uses existing group and project, submits lead and trial' do
          expect_create_lead_success(lead_params)
          expect_apply_trial_async(user, namespace: existing_group, extra_params: glm_params)

          expect { execute }.to not_change { Group.count }.and not_change { Project.count }
          expect(execute).to be_success
          expect(execute.payload).to eq({ namespace: existing_group, project: existing_project })
        end

        context 'when namespace is not eligible' do
          before do
            allow(GitlabSubscriptions::Trials)
              .to receive(:namespace_eligible?).with(existing_group).and_return(false)
          end

          it 'returns not found error' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end

        context "when project_id does not exist" do
          let(:project_id) { non_existing_record_id }

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end

        context "when project isn't owned by user" do
          let(:project_id) { unrelated_project.id }

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.message).to eq('Not found')
            expect(execute.reason).to eq(:not_found)
          end
        end

        context 'when lead creation fails' do
          it 'returns lead_failed error' do
            expect_create_lead_fail(lead_params)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.reason).to eq(:lead_failed)
            expect(execute.payload).to eq({ namespace_id: existing_group.id, project_id: existing_project.id })
          end
        end
      end

      context 'with resubmit_trial step' do
        let(:step) { described_class::RESUBMIT_TRIAL }
        let(:namespace_id) { existing_group.id }
        let(:project_id) { existing_project.id }

        it 'skips lead creation and submits trial' do
          expect(lead_service_class).not_to receive(:new)
          expect_apply_trial_async(user, namespace: existing_group, extra_params: glm_params)

          expect(execute).to be_success
          expect(execute.message).to eq('Trial applied')
        end

        context 'when namespace is not eligible for trial' do
          before do
            allow(GitlabSubscriptions::Trials)
              .to receive(:namespace_eligible?).with(existing_group).and_return(false)
          end

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.message).to eq('Not found')
            expect(execute.reason).to eq(:not_found)
          end
        end

        context 'when project does not exist' do
          let(:project_id) { non_existing_record_id }

          it 'returns not found error' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end

        context "when user does not have admin access to the project" do
          let(:project_id) { unrelated_project.id }

          it 'returns not found error' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_worker_class).not_to receive(:perform_async)

            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end
      end

      context 'with unknown step' do
        let(:step) { 'unknown' }

        it 'returns not found error' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_worker_class).not_to receive(:perform_async)

          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end
    end
  end
end
