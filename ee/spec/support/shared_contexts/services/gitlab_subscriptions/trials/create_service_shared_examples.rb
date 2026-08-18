# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'successful lead creation for one eligible namespace' do |plan_name|
  context 'when there is only one trial eligible namespace' do
    let_it_be(:group, freeze: false) { create(:group_with_plan, plan: plan_name, name: 'gitlab', owners: user) }

    it 'starts a trial and tracks the event' do
      expect_create_lead_success(trial_user_params)
      expect_apply_trial_success(user, group, extra_params: existing_group_attrs(group))

      expect(execute).to be_success
      expect(execute.payload).to eq({ namespace: group, add_on_purchase: add_on_purchase })
      expect_snowplow_event(category: described_class.name, action: 'create_trial', namespace: group, user: user)
    end

    it 'errors when trying to apply a trial' do
      expect_create_lead_success(trial_user_params)
      expect_apply_trial_fail(user, group, extra_params: existing_group_attrs(group))

      expect(execute).to be_error
      expect(execute.reason).to eq(:trial_failed)
      expect(execute.payload).to eq({ namespace_id: group.id })
      expect_no_snowplow_event(
        category: described_class.name, action: 'create_trial', namespace: group, user: user
      )
    end
  end
end

RSpec.shared_examples 'successful lead creation for no eligible namespaces' do
  context 'when there are no trial eligible namespaces' do
    it 'does not create a trial and returns that there is no namespace' do
      stub_lead_without_trial(trial_user_params)

      expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
    end

    context 'with glm params' do
      let(:extra_lead_params) { { glm_content: '_glm_content_', glm_source: '_glm_source_' } }

      it 'does not create a trial and returns that there is no namespace' do
        stub_lead_without_trial(trial_user_params)

        expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
      end
    end
  end
end

RSpec.shared_examples 'successful lead creation for multiple eligible namespaces' do |plan_name|
  context 'when there are multiple trial eligible namespaces' do
    let_it_be(:group, freeze: false) { create(:group_with_plan, plan: plan_name, name: 'gitlab', owners: user) }
    # Caching case needs all groups named for reference
    let_it_be(:another_group, freeze: false) { create(:group_with_plan, plan: plan_name, owners: user) }

    it 'does not create a trial and returns that there is no namespace' do
      stub_lead_without_trial(trial_user_params)

      expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
    end

    context 'with glm params' do
      let(:extra_lead_params) { { glm_content: '_glm_content_', glm_source: '_glm_source_' } }

      it 'does not create a trial and returns that there is no namespace' do
        stub_lead_without_trial(trial_user_params)

        expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
      end
    end
  end
end

RSpec.shared_examples 'lead creation fails' do
  context 'when lead creation fails' do
    it 'returns and error indicating lead failed' do
      expect_create_lead_fail(trial_user_params)
      expect(apply_trial_service_class).not_to receive(:new)

      expect(execute).to be_error
      expect(execute.reason).to eq(:lead_failed)
    end
  end
end

RSpec.shared_examples 'performing the lead step' do |plan_name|
  it_behaves_like 'successful lead creation for one eligible namespace', plan_name
  it_behaves_like 'successful lead creation for no eligible namespaces'
  it_behaves_like 'successful lead creation for multiple eligible namespaces', plan_name
  it_behaves_like 'lead creation fails'
end

RSpec.shared_examples 'trial step existing namespace flow' do |plan_name|
  context 'in the existing namespace flow' do
    let_it_be(:group, freeze: false) { create(:group_with_plan, plan: plan_name, name: 'gitlab', owners: user) }
    let(:namespace_id) { group.id.to_s }
    let(:trial_params) { { namespace_id: namespace_id } }

    shared_examples 'starts a trial' do
      specify do
        expect_apply_trial_success(user, group, extra_params: existing_group_attrs(group))

        expect(execute).to be_success
        expect(execute.payload).to eq({ namespace: group, add_on_purchase: add_on_purchase })
      end
    end

    shared_examples 'returns an error of not_found and does not apply a trial' do
      specify do
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when trial creation is successful' do
      it_behaves_like 'starts a trial'

      context 'when a valid namespace_id of non zero and new_group_name is present' do
        # This can *currently* happen on validation failure for creating
        # a new namespace.
        let(:trial_params) { { new_group_name: 'gitlab', namespace_id: group.id } }

        context 'with the namespace_id' do
          it_behaves_like 'starts a trial'
        end
      end
    end

    context 'when trial creation is not successful' do
      it 'returns an error indicating trial failed' do
        expect_apply_trial_fail(user, group, extra_params: existing_group_attrs(group))

        expect(execute).to be_error
        expect(execute.reason).to eq(:trial_failed)
      end
    end

    context 'when the user does not have access to the namespace' do
      let(:namespace_id) { create(:group_with_plan, plan: plan_name).id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end

    context 'when the user is not an owner of the namespace' do
      let(:namespace_id) { create(:group_with_plan, plan: plan_name, developers: user).id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end

    context 'when there is no namespace with the namespace_id' do
      let(:namespace_id) { non_existing_record_id.to_s }

      it_behaves_like 'returns an error of not_found and does not apply a trial'
    end
  end
end

RSpec.shared_examples 'trial step error conditions' do
  context 'when namespace_id is 0 without a new_group_name' do
    let(:trial_params) { { namespace_id: '0' } }

    it 'returns an error of not_found and does not apply a trial' do
      expect(apply_trial_service_class).not_to receive(:new)

      expect(execute).to be_error
      expect(execute.reason).to eq(:not_found)
    end
  end

  context 'when neither new group name or namespace_id is present' do
    let(:trial_params) { {} }

    it 'returns an error of not_found and does not apply a trial' do
      expect(apply_trial_service_class).not_to receive(:new)

      expect(execute).to be_error
      expect(execute.reason).to eq(:not_found)
    end
  end
end

RSpec.shared_examples 'performing the trial step' do |plan_name|
  let(:step) { described_class::TRIAL }

  it_behaves_like 'trial step existing namespace flow', plan_name
  it_behaves_like 'trial step error conditions'
end

RSpec.shared_examples 'unknown step for trials' do
  let(:step) { 'bogus' }

  it_behaves_like 'returns an error of not_found and does not create lead or apply a trial'
end

RSpec.shared_examples 'no step for trials' do
  let(:step) { nil }

  it_behaves_like 'returns an error of not_found and does not create lead or apply a trial'
end

RSpec.shared_examples 'returns an error of not_found and does not create lead or apply a trial' do
  specify do
    expect(lead_service_class).not_to receive(:new)
    expect(apply_trial_service_class).not_to receive(:new)

    expect(execute).to be_error
    expect(execute.reason).to eq(:not_found)
  end
end

RSpec.shared_examples 'for tracking the lead step' do |plan_name, tracking_prefix|
  let_it_be(:namespace, freeze: false) do
    create(:group_with_plan, plan: plan_name, name: 'gitlab', owners: user)
  end

  it 'tracks when lead creation is successful', :clean_gitlab_redis_shared_state do
    expect_create_lead_success(trial_user_params)
    expect_apply_trial_fail(user, namespace, extra_params: existing_group_attrs(namespace))

    expect do
      execute
    end
      .to(
        trigger_internal_events("#{tracking_prefix}lead_creation_success")
          .with(user: user, category: 'InternalEventTracking')
          .and(
            trigger_internal_events("#{tracking_prefix}trial_registration_failure")
              .with(user: user, namespace: namespace, category: 'InternalEventTracking')
              .and(
                not_trigger_internal_events(
                  "#{tracking_prefix}trial_registration_success", "#{tracking_prefix}lead_creation_failure"
                )
              )
              .and(
                increment_usage_metrics(
                  "counts.count_total_#{tracking_prefix}lead_creation_success",
                  "counts.count_total_#{tracking_prefix}trial_registration_failure"
                )
              )
              .and(
                not_increment_usage_metrics(
                  "counts.count_total_#{tracking_prefix}trial_registration_success",
                  "counts.count_total_#{tracking_prefix}lead_creation_failure"
                )
              )
          )
      )
  end

  it 'tracks when lead creation fails', :clean_gitlab_redis_shared_state do
    expect_create_lead_fail(trial_user_params)

    expect do
      execute
    end
      .to(
        trigger_internal_events("#{tracking_prefix}lead_creation_failure")
          .with(user: user, category: 'InternalEventTracking')
          .and(
            not_trigger_internal_events(
              "#{tracking_prefix}lead_creation_success",
              "#{tracking_prefix}trial_registration_failure",
              "#{tracking_prefix}trial_registration_success"
            )
          )
          .and(increment_usage_metrics("counts.count_total_#{tracking_prefix}lead_creation_failure"))
          .and(
            not_increment_usage_metrics(
              "counts.count_total_#{tracking_prefix}lead_creation_success",
              "counts.count_total_#{tracking_prefix}trial_registration_failure",
              "counts.count_total_#{tracking_prefix}trial_registration_success"
            )
          )
      )
  end
end

RSpec.shared_examples 'for tracking the trial step' do |plan_name, tracking_prefix|
  let(:step) { described_class::TRIAL }
  let_it_be(:namespace, freeze: false) do
    create(:group_with_plan, plan: plan_name, name: 'gitlab', owners: user)
  end

  let(:namespace_id) { namespace.id.to_s }
  let(:trial_params) { { namespace_id: namespace_id } }

  it 'tracks when trial registration is successful', :clean_gitlab_redis_shared_state do
    expect_apply_trial_success(user, namespace, extra_params: existing_group_attrs(namespace))

    expect do
      execute
    end
      .to(
        trigger_internal_events("#{tracking_prefix}trial_registration_success")
          .with(user: user, namespace: namespace, category: 'InternalEventTracking')
          .and(
            not_trigger_internal_events(
              "#{tracking_prefix}lead_creation_success",
              "#{tracking_prefix}lead_creation_failure",
              "#{tracking_prefix}trial_registration_failure"
            )
          )
          .and(increment_usage_metrics("counts.count_total_#{tracking_prefix}trial_registration_success"))
          .and(
            not_increment_usage_metrics(
              "counts.count_total_#{tracking_prefix}lead_creation_success",
              "counts.count_total_#{tracking_prefix}lead_creation_failure"
            )
          )
      )
  end

  it 'tracks when trial registration fails', :clean_gitlab_redis_shared_state do
    expect_apply_trial_fail(user, namespace, extra_params: existing_group_attrs(namespace))

    expect do
      execute
    end
      .to(
        trigger_internal_events("#{tracking_prefix}trial_registration_failure")
          .with(user: user, namespace: namespace, category: 'InternalEventTracking')
          .and(
            not_trigger_internal_events(
              "#{tracking_prefix}lead_creation_success",
              "#{tracking_prefix}lead_creation_failure",
              "#{tracking_prefix}trial_registration_success"
            )
          )
          .and(increment_usage_metrics("counts.count_total_#{tracking_prefix}trial_registration_failure"))
          .and(
            not_increment_usage_metrics(
              "counts.count_total_#{tracking_prefix}lead_creation_success",
              "counts.count_total_#{tracking_prefix}lead_creation_failure",
              "counts.count_total_#{tracking_prefix}trial_registration_success"
            )
          )
      )
  end
end

RSpec.shared_examples 'creating add-on when namespace_id is provided' do |eligible_plan, ineligible_plan|
  let_it_be(:ineligible_namespace, freeze: false) do
    create(:group_with_plan, plan: ineligible_plan, name: 'gitlab_ie', owners: user)
  end

  context 'when it is an eligible namespace' do
    let_it_be(:namespace, freeze: false) { create(:group_with_plan, plan: eligible_plan, name: 'gitlab', owners: user) }
    let(:trial_params) { { namespace_id: namespace.id.to_s } }

    before do
      expect_create_lead_success(trial_user_params)
      expect_apply_trial_success(user, namespace, extra_params: existing_group_attrs(namespace))
    end

    it { is_expected.to be_success }
  end

  context 'when it is non existing namespace' do
    let(:trial_params) { { namespace_id: non_existing_record_id.to_s } }

    specify do
      expect(execute).to be_error
      expect(execute.reason).to eq(:not_found)
    end
  end

  context 'when it is an ineligible namespace' do
    let(:namespace) { ineligible_namespace }
    let(:trial_params) { { namespace_id: namespace.id.to_s } }

    specify do
      expect(execute).to be_error
      expect(execute.reason).to eq(:not_found)
    end
  end
end
