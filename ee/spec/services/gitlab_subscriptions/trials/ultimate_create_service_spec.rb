# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::UltimateCreateService, :saas, feature_category: :acquisition do
  include TrialHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :free_plan, owners: user) }
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
      trial_user: params.except(:namespace_id, :new_group_name, :organization_id).merge(
        {
          work_email: user.email,
          uid: user.id,
          namespace_id: group.id,
          trial_type: GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2,
          setup_for_company: user.onboarding_status_setup_for_company,
          existing_plan: 'free',
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab'
        }
      )
    }
  end

  let(:step) { described_class::FULL }
  let(:lead_service_class) { GitlabSubscriptions::CreateLeadService }
  let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyTrialService }

  subject(:execute) { described_class.new(step: step, params: params, user: user).execute }

  before do
    allow(GitlabSubscriptions::Trials)
      .to receive(:eligible_namespaces_for_user).with(user).and_return(Group.where(id: group.id))
  end

  describe '#execute' do
    context 'when step is FULL' do
      let(:step) { described_class::FULL }

      context 'when the namespace is on a premium plan' do
        let(:group) { create(:group_with_plan, plan: :premium_plan, owners: user) }
        let(:lead_params) do
          super().deep_merge(
            trial_user: {
              trial_type: GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE_V2,
              existing_plan: 'premium'
            }
          )
        end

        it 'sends the premium trial type on the lead' do
          expect_create_lead_success(lead_params)
          expect_apply_ultimate_trial_success(
            user, group, extra_params: glm_params.merge(existing_group_attrs(group))
          )

          expect(execute).to be_success
        end
      end

      context 'when namespace_id is provided' do
        context 'when lead creation is successful' do
          context 'when trial creation is successful' do
            it 'creates lead and applies trial successfully' do
              expect_create_lead_success(lead_params)
              expect_apply_ultimate_trial_success(
                user, group, extra_params: glm_params.merge(existing_group_attrs(group))
              )

              expect(execute).to be_success
              expect(execute.message).to eq('Trial applied')
              expect(execute.payload).to eq({ namespace: group })
            end

            it 'tracks lead creation success event' do
              expect_create_lead_success(lead_params)
              expect_apply_ultimate_trial_success(
                user, group, extra_params: glm_params.merge(existing_group_attrs(group))
              )

              expect do
                execute
              end
                .to(
                  trigger_internal_events('lead_creation_success')
                    .with(user: user, namespace: group, category: 'InternalEventTracking')
                    .and(
                      trigger_internal_events('trial_registration_success')
                        .with(user: user, namespace: group, category: 'InternalEventTracking')
                        .and(
                          not_trigger_internal_events('lead_creation_failure', 'trial_registration_failure')
                        )
                        .and(
                          increment_usage_metrics(
                            'counts.count_total_lead_creation_success',
                            'counts.count_total_trial_registration_success'
                          )
                        )
                        .and(
                          not_increment_usage_metrics(
                            'counts.count_total_trial_registration_failure',
                            'counts.count_total_lead_creation_failure'
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
                  trigger_internal_events('lead_creation_success')
                    .with(user: user, namespace: group, category: 'InternalEventTracking')
                    .and(
                      trigger_internal_events('trial_registration_failure')
                        .with(user: user, namespace: group, category: 'InternalEventTracking')
                        .and(
                          not_trigger_internal_events('lead_creation_failure', 'trial_registration_success')
                        )
                        .and(
                          increment_usage_metrics(
                            'counts.count_total_lead_creation_success',
                            'counts.count_total_trial_registration_failure'
                          )
                        )
                        .and(
                          not_increment_usage_metrics(
                            'counts.count_total_trial_registration_success',
                            'counts.count_total_lead_creation_failure'
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
                trigger_internal_events('lead_creation_failure')
                  .with(user: user, namespace: group, category: 'InternalEventTracking')
                  .and(
                    not_trigger_internal_events(
                      'lead_creation_success',
                      'trial_registration_failure',
                      'trial_registration_success'
                    )
                  )
                  .and(increment_usage_metrics('counts.count_total_lead_creation_failure'))
                  .and(
                    not_increment_usage_metrics(
                      'counts.count_total_lead_creation_success',
                      'counts.count_total_trial_registration_failure',
                      'counts.count_total_trial_registration_success'
                    )
                  )
              )
          end
        end

        context 'when namespace is not eligible for trial' do
          before do
            allow(GitlabSubscriptions::Trials)
              .to receive(:eligible_namespaces_for_user).with(user).and_return(Group.none)
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

      context 'when creating a new namespace' do
        let_it_be(:organization) { create(:organization, users: [user]) }
        let(:namespace_id) { 0 }
        let(:params) { super().merge(new_group_name: 'gitlab', organization_id: organization.id) }

        # The group is created during execution, so its id is only known at match time.
        let(:lead_params) do
          { trial_user: super()[:trial_user].merge(namespace_id: kind_of(Integer)) }
        end

        context 'when group is successfully created' do
          let(:extra_params) { { organization_id: organization.id, with_add_on: true, add_on_name: 'duo_enterprise' } }

          context 'when lead creation is successful' do
            context 'when trial creation is successful' do
              it 'return success with the namespace' do
                allow(::Namespace.sticking).to receive(:stick).with(anything, anything).and_call_original

                expect_create_lead_success(lead_params)
                expect_new_group_apply_trial_success

                expect { execute }.to change { Group.count }.by(1)

                expect(::Namespace.sticking).to have_received(:stick).with(:namespace, Group.last.id)
                expect(execute).to be_success
                expect(execute.payload).to eq({ namespace: Group.last })
              end
            end

            context 'when trial creation fails' do
              it 'returns an error indicating trial failed' do
                expect_create_lead_success(lead_params)
                expect_new_group_apply_trial_fail

                expect { execute }.to change { Group.count }.by(1)

                expect(execute).to be_error
                expect(execute.payload).to eq({ namespace_id: Group.last.id })
              end

              def expect_new_group_apply_trial_fail
                expect_next_instance_of(apply_trial_service_class) do |instance|
                  expect(instance).to receive(:execute).and_return(
                    ServiceResponse.error(message: '_trial_fail_')
                  )
                end
              end
            end
          end

          context 'when lead creation fails' do
            it 'returns error with lead failure reason and does not attempt to submit trial' do
              expect_create_lead_fail(lead_params)
              expect(apply_trial_service_class).not_to receive(:new)

              expect { execute }.to change { Group.count }.by(1)

              expect(execute).to be_error
              expect(execute.message).to eq('_lead_fail_')
              expect(execute.reason).to eq(described_class::LEAD_FAILED)
              expect(execute.payload).to eq({ namespace_id: Group.last.id })
            end
          end

          context 'when group name needs sanitized' do
            it 'return success with the namespace path sanitized for duplication' do
              create(:group_with_plan, plan: :free_plan, name: 'gitlab')

              expect_create_lead_success(lead_params)
              expect_new_group_apply_trial_success

              expect { execute }.to change { Group.count }.by(1)

              expect(execute).to be_success
              expect(execute.payload[:namespace].path).to eq('gitlab1')
            end
          end

          def expect_new_group_apply_trial_success
            expect_next_instance_of(apply_trial_service_class) do |instance|
              expect(instance).to receive(:execute).and_return(
                ServiceResponse.success
              )
            end
          end
        end

        context 'when user is not allowed to create groups' do
          before do
            user.can_create_group = false
          end

          it 'returns not_found and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_service_class).not_to receive(:new)

            expect { execute }.not_to change { Group.count }
            expect(execute).to be_error
            expect(execute.reason).to eq(:not_found)
          end
        end

        context 'when group creation had an error' do
          context 'when there are invalid characters used' do
            let(:params) { super().merge(new_group_name: ' _invalid_ ') }

            it 'returns namespace_create_failed and lead/trial is not submitted' do
              expect(lead_service_class).not_to receive(:new)
              expect(apply_trial_service_class).not_to receive(:new)

              expect { execute }.not_to change { Group.count }
              expect(execute).to be_error
              expect(execute.reason).to eq(:namespace_create_failed)
              expect(execute.message.to_sentence).to match(/^Group URL can only include non-accented letters/)
              expect(execute.payload[:namespace_id]).to eq(0)
            end
          end

          context 'when name is entered with blank spaces' do
            let(:params) { super().merge(new_group_name: '  ') }

            it 'returns namespace_create_failed' do
              expect(lead_service_class).not_to receive(:new)
              expect(apply_trial_service_class).not_to receive(:new)

              expect { execute }.not_to change { Group.count }
              expect(execute).to be_error
              expect(execute.reason).to eq(:namespace_create_failed)
              expect(execute.message.to_sentence).to match(/^Name can't be blank/)
              expect(execute.payload[:namespace_id]).to eq(0)
            end
          end
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
            it 'creates lead and applies trial successfully' do
              expect_create_lead_success(lead_params)
              expect_apply_ultimate_trial_success(
                user, group, extra_params: glm_params.merge(existing_group_attrs(group))
              )

              expect(execute).to be_success
              expect(execute.message).to eq('Trial applied')
              expect(execute.payload).to eq({ namespace: group })
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
          allow(GitlabSubscriptions::Trials)
            .to receive(:eligible_namespaces_for_user).with(user).and_return(Group.none)
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
          it 'applies trial successfully without creating lead' do
            expect(lead_service_class).not_to receive(:new)
            expect_apply_ultimate_trial_success(
              user, group, extra_params: glm_params.merge(existing_group_attrs(group))
            )

            expect(execute).to be_success
            expect(execute.message).to eq('Trial applied')
            expect(execute.payload).to eq({ namespace: group })
          end

          it 'tracks trial registration success event' do
            expect(lead_service_class).not_to receive(:new)
            expect_apply_ultimate_trial_success(
              user, group, extra_params: glm_params.merge(existing_group_attrs(group))
            )

            expect do
              execute
            end
              .to(
                trigger_internal_events('trial_registration_success')
                  .with(user: user, namespace: group, category: 'InternalEventTracking')
                  .and(
                    not_trigger_internal_events(
                      'lead_creation_success', 'lead_creation_failure', 'trial_registration_failure'
                    )
                  )
                  .and(
                    increment_usage_metrics(
                      'counts.count_total_trial_registration_success'
                    )
                  )
                  .and(
                    not_increment_usage_metrics(
                      'counts.count_total_trial_registration_failure',
                      'counts.count_total_lead_creation_success',
                      'counts.count_total_lead_creation_failure'
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
                trigger_internal_events('trial_registration_failure')
                  .with(user: user, namespace: group, category: 'InternalEventTracking')
                  .and(
                    not_trigger_internal_events(
                      'lead_creation_failure', 'trial_registration_success', 'lead_creation_success'
                    )
                  )
                  .and(
                    increment_usage_metrics(
                      'counts.count_total_trial_registration_failure'
                    )
                  )
                  .and(
                    not_increment_usage_metrics(
                      'counts.count_total_trial_registration_success',
                      'counts.count_total_lead_creation_success',
                      'counts.count_total_lead_creation_failure'
                    )
                  )
              )
          end
        end
      end

      context 'when namespace is not eligible for trial' do
        before do
          allow(GitlabSubscriptions::Trials)
            .to receive(:eligible_namespaces_for_user).with(user).and_return(Group.none)
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
