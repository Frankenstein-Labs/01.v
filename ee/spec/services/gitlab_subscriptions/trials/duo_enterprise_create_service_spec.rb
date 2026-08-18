# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterpriseCreateService, :saas, feature_category: :acquisition do
  include TrialHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: user) }
  let(:glm_params) { { glm_source: 'some-source', glm_content: 'some-content' } }
  let(:namespace_id) { group.id }

  let(:params) do
    {
      first_name: 'John',
      last_name: 'Doe',
      company_name: 'Test Company',
      phone_number: '123-456-7890',
      country: 'US',
      state: 'CA',
      namespace_id: namespace_id
    }.merge(glm_params)
  end

  let(:lead_params) do
    {
      trial_user: params.except(:namespace_id).merge(
        {
          work_email: user.email,
          uid: user.id,
          namespace_id: namespace_id,
          setup_for_company: user.onboarding_status_setup_for_company,
          existing_plan: 'ultimate',
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab',
          product_interaction: 'duo_enterprise_trial',
          add_on_name: 'duo_enterprise',
          preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
          opt_in: user.onboarding_status_email_opt_in
        }
      )
    }
  end

  let(:step) { described_class::FULL }
  let(:lead_service_class) { GitlabSubscriptions::Trials::CreateAddOnLeadService }
  let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyDuoEnterpriseService }

  subject(:execute) { described_class.new(step: step, params: params, user: user).execute }

  before do
    allow_next_instance_of(Users::AddOnTrialEligibleNamespacesFinder, user, add_on: :duo_enterprise) do |finder|
      allow(finder).to receive(:execute).and_return(Group.where(id: group.id))
    end
  end

  describe '#execute' do
    context 'when step is FULL' do
      let(:step) { described_class::FULL }

      context 'when namespace_id is provided' do
        context 'when lead creation is successful' do
          context 'when trial creation is successful' do
            let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

            it 'creates lead and applies trial successfully' do
              expect_create_lead_success(lead_params)
              expect_apply_trial_success(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

              expect(execute).to be_success
              expect(execute.message).to eq('Trial applied')
              expect(execute.payload).to eq({ namespace: group, add_on_purchase: add_on_purchase })
            end

            it 'tracks lead creation success event' do
              expect_create_lead_success(lead_params)
              expect_apply_trial_success(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

              expect do
                execute
              end
                .to(
                  trigger_internal_events('duo_enterprise_lead_creation_success')
                    .with(user: user, namespace: group, category: 'InternalEventTracking')
                    .and(
                      trigger_internal_events('duo_enterprise_trial_registration_success')
                        .with(user: user, namespace: group, category: 'InternalEventTracking')
                        .and(
                          not_trigger_internal_events(
                            'duo_enterprise_lead_creation_failure', 'duo_enterprise_trial_registration_failure'
                          )
                        )
                        .and(
                          increment_usage_metrics(
                            'counts.count_total_duo_enterprise_lead_creation_success',
                            'counts.count_total_duo_enterprise_trial_registration_success'
                          )
                        )
                        .and(
                          not_increment_usage_metrics(
                            'counts.count_total_duo_enterprise_trial_registration_failure',
                            'counts.count_total_duo_enterprise_lead_creation_failure'
                          )
                        )
                    )
                )
            end
          end

          context 'when trial creation fails' do
            it 'returns error with trial failure reason' do
              expect_create_lead_success(lead_params)
              expect_apply_trial_fail(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

              expect(execute).to be_error
              expect(execute.message).to eq('_trial_fail_')
              expect(execute.payload).to eq({ namespace_id: group.id })
            end

            it 'tracks lead success and trial registration failure events' do
              expect_create_lead_success(lead_params)
              expect_apply_trial_fail(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

              expect do
                execute
              end
                .to(
                  trigger_internal_events('duo_enterprise_lead_creation_success')
                    .with(user: user, namespace: group, category: 'InternalEventTracking')
                    .and(
                      trigger_internal_events('duo_enterprise_trial_registration_failure')
                        .with(user: user, namespace: group, category: 'InternalEventTracking')
                        .and(
                          not_trigger_internal_events(
                            'duo_enterprise_lead_creation_failure', 'duo_enterprise_trial_registration_success'
                          )
                        )
                        .and(
                          increment_usage_metrics(
                            'counts.count_total_duo_enterprise_lead_creation_success',
                            'counts.count_total_duo_enterprise_trial_registration_failure'
                          )
                        )
                        .and(
                          not_increment_usage_metrics(
                            'counts.count_total_duo_enterprise_trial_registration_success',
                            'counts.count_total_duo_enterprise_lead_creation_failure'
                          )
                        )
                    )
                )
            end
          end
        end

        context 'when lead creation fails' do
          it 'returns error with lead failure reason and does not attempt to submit trial' do
            expect_create_lead_fail(lead_params)
            expect(apply_trial_service_class).not_to receive(:new)

            expect(execute).to be_error
            expect(execute.message).to eq('_lead_fail_')
            expect(execute.reason).to eq(described_class::LEAD_FAILED)
            expect(execute.payload).to eq({ namespace_id: group.id })
          end

          it 'tracks lead creation failure event' do
            expect_create_lead_fail(lead_params)

            expect do
              execute
            end
              .to(
                trigger_internal_events('duo_enterprise_lead_creation_failure')
                  .with(user: user, namespace: group, category: 'InternalEventTracking')
                  .and(
                    not_trigger_internal_events(
                      'duo_enterprise_lead_creation_success',
                      'duo_enterprise_trial_registration_failure',
                      'duo_enterprise_trial_registration_success'
                    )
                  )
                  .and(increment_usage_metrics('counts.count_total_duo_enterprise_lead_creation_failure'))
                  .and(
                    not_increment_usage_metrics(
                      'counts.count_total_duo_enterprise_lead_creation_success',
                      'counts.count_total_duo_enterprise_trial_registration_failure',
                      'counts.count_total_duo_enterprise_trial_registration_success'
                    )
                  )
              )
          end
        end

        context 'when namespace is not eligible for trial' do
          before do
            allow_next_instance_of(Users::AddOnTrialEligibleNamespacesFinder, user, add_on: :duo_enterprise) do |finder|
              allow(finder).to receive(:execute).and_return(Group.none)
            end
          end

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_service_class).not_to receive(:new)

            expect(execute).to be_error
            expect(execute.message).to eq('Not found')
            expect(execute.reason).to eq(described_class::NOT_FOUND)
          end
        end
      end

      context 'when namespace_id is not provided' do
        let(:params) { super().except(:namespace_id) }

        it 'returns not found error and lead/trial is not submitted' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_service_class).not_to receive(:new)

          expect(execute).to be_error
          expect(execute.message).to eq('Not found')
          expect(execute.reason).to eq(described_class::NOT_FOUND)
        end
      end

      context 'when namespace does not exist' do
        let(:params) { super().merge(namespace_id: non_existing_record_id) }

        it 'returns not found error and lead/trial is not submitted' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_service_class).not_to receive(:new)

          expect(execute).to be_error
          expect(execute.message).to eq('Not found')
          expect(execute.reason).to eq(described_class::NOT_FOUND)
        end
      end
    end

    context 'when step is RESUBMIT_LEAD' do
      let(:step) { described_class::RESUBMIT_LEAD }

      context 'when namespace exists and is eligible' do
        context 'when lead creation is successful' do
          context 'when trial creation is successful' do
            let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

            it 'creates lead and applies trial successfully' do
              expect_create_lead_success(lead_params)
              expect_apply_trial_success(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

              expect(execute).to be_success
              expect(execute.message).to eq('Trial applied')
              expect(execute.payload).to eq({ namespace: group, add_on_purchase: add_on_purchase })
            end
          end

          context 'when trial creation fails' do
            it 'returns error with trial failure reason' do
              expect_create_lead_success(lead_params)
              expect_apply_trial_fail(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

              expect(execute).to be_error
              expect(execute.message).to eq('_trial_fail_')
              expect(execute.payload).to eq({ namespace_id: group.id })
            end
          end
        end

        context 'when lead creation fails' do
          it 'returns error with lead failure reason and does not attempt to submit trial' do
            expect_create_lead_fail(lead_params)
            expect(apply_trial_service_class).not_to receive(:new)

            expect(execute).to be_error
            expect(execute.message).to eq('_lead_fail_')
            expect(execute.reason).to eq(described_class::LEAD_FAILED)
            expect(execute.payload).to eq({ namespace_id: group.id })
          end
        end
      end

      context 'when namespace is not eligible for trial' do
        before do
          allow_next_instance_of(Users::AddOnTrialEligibleNamespacesFinder, user, add_on: :duo_enterprise) do |finder|
            allow(finder).to receive(:execute).and_return(Group.none)
          end
        end

        it 'returns not found error and lead/trial is not submitted' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_service_class).not_to receive(:new)

          expect(execute).to be_error
          expect(execute.message).to eq('Not found')
          expect(execute.reason).to eq(described_class::NOT_FOUND)
        end
      end
    end

    context 'when step is RESUBMIT_TRIAL' do
      let(:step) { described_class::RESUBMIT_TRIAL }

      context 'when namespace exists and is eligible' do
        context 'when trial creation is successful' do
          let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

          it 'applies trial successfully without creating lead' do
            expect(lead_service_class).not_to receive(:new)
            expect_apply_trial_success(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

            expect(execute).to be_success
            expect(execute.message).to eq('Trial applied')
            expect(execute.payload).to eq({ namespace: group, add_on_purchase: add_on_purchase })
          end

          it 'tracks trial registration success event' do
            expect(lead_service_class).not_to receive(:new)
            expect_apply_trial_success(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

            expect do
              execute
            end
              .to(
                trigger_internal_events('duo_enterprise_trial_registration_success')
                  .with(user: user, namespace: group, category: 'InternalEventTracking')
                  .and(
                    not_trigger_internal_events(
                      'duo_enterprise_lead_creation_success', 'duo_enterprise_lead_creation_failure',
                      'duo_enterprise_trial_registration_failure'
                    )
                  )
                  .and(
                    increment_usage_metrics(
                      'counts.count_total_duo_enterprise_trial_registration_success'
                    )
                  )
                  .and(
                    not_increment_usage_metrics(
                      'counts.count_total_duo_enterprise_trial_registration_failure',
                      'counts.count_total_duo_enterprise_lead_creation_success',
                      'counts.count_total_duo_enterprise_lead_creation_failure'
                    )
                  )
              )
          end
        end

        context 'when trial creation fails' do
          it 'returns error with trial failure reason' do
            expect(lead_service_class).not_to receive(:new)
            expect_apply_trial_fail(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

            expect(execute).to be_error
            expect(execute.message).to eq('_trial_fail_')
            expect(execute.payload).to eq({ namespace_id: group.id })
          end

          it 'tracks trial registration failure event' do
            expect(lead_service_class).not_to receive(:new)
            expect_apply_trial_fail(user, group, extra_params: glm_params.merge(existing_group_attrs(group)))

            expect do
              execute
            end
              .to(
                trigger_internal_events('duo_enterprise_trial_registration_failure')
                  .with(user: user, namespace: group, category: 'InternalEventTracking')
                  .and(
                    not_trigger_internal_events(
                      'duo_enterprise_lead_creation_failure', 'duo_enterprise_trial_registration_success',
                      'duo_enterprise_lead_creation_success'
                    )
                  )
                  .and(
                    increment_usage_metrics(
                      'counts.count_total_duo_enterprise_trial_registration_failure'
                    )
                  )
                  .and(
                    not_increment_usage_metrics(
                      'counts.count_total_duo_enterprise_trial_registration_success',
                      'counts.count_total_duo_enterprise_lead_creation_success',
                      'counts.count_total_duo_enterprise_lead_creation_failure'
                    )
                  )
              )
          end
        end
      end

      context 'when namespace is not eligible for trial' do
        before do
          allow_next_instance_of(Users::AddOnTrialEligibleNamespacesFinder, user, add_on: :duo_enterprise) do |finder|
            allow(finder).to receive(:execute).and_return(Group.none)
          end
        end

        it 'returns not found error and lead/trial is not submitted' do
          expect(lead_service_class).not_to receive(:new)
          expect(apply_trial_service_class).not_to receive(:new)

          expect(execute).to be_error
          expect(execute.message).to eq('Not found')
          expect(execute.reason).to eq(described_class::NOT_FOUND)
        end
      end
    end

    context 'when step is unknown' do
      let(:step) { 'unknown_step' }

      it 'returns not found error and lead/trial is not submitted' do
        expect(lead_service_class).not_to receive(:new)
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.message).to eq('Not found')
        expect(execute.reason).to eq(described_class::NOT_FOUND)
      end
    end

    context 'when step is nil' do
      let(:step) { nil }

      it 'returns not found error and lead/trial is not submitted' do
        expect(lead_service_class).not_to receive(:new)
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.message).to eq('Not found')
        expect(execute.reason).to eq(described_class::NOT_FOUND)
      end
    end
  end
end
