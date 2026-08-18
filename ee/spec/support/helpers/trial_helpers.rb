# frozen_string_literal: true

module TrialHelpers
  def expect_create_lead_success(trial_user_params)
    expect_next_instance_of(lead_service_class) do |instance|
      expect(instance).to receive(:execute).with(trial_user_params).and_return(ServiceResponse.success)
    end
  end

  def expect_create_lead_fail(trial_user_params)
    expect_next_instance_of(lead_service_class) do |instance|
      expect(instance).to receive(:execute).with(trial_user_params)
                                           .and_return(ServiceResponse.error(message: '_lead_fail_'))
    end
  end

  def stub_lead_without_trial(trial_user_params)
    expect_create_lead_success(trial_user_params)
    expect(apply_trial_service_class).not_to receive(:new)
  end

  def expect_to_trigger_trial_step(execution, lead_payload_params, trial_payload_params)
    expect(execution).to be_error
    expect(execution.reason).to eq(:no_single_namespace)
    trial_selection_params = {
      step: described_class::TRIAL
    }.merge(lead_payload_params).merge(trial_payload_params.slice(:namespace_id))
    expect(execution.payload).to match(trial_selection_params: trial_selection_params)
  end

  def stub_apply_trial(user, namespace_id: anything, success: true, extra_params: {})
    trial_user_params = {
      namespace_id: namespace_id,
      gitlab_com_trial: true,
      sync_to_gl: true
    }.merge(extra_params)

    service_params = {
      trial_user_information: trial_user_params,
      uid: user.id
    }

    trial_success = if success
                      ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
                    else
                      ServiceResponse.error(message: '_trial_fail_')
                    end

    expect_next_instance_of(apply_trial_service_class, service_params) do |instance|
      expect(instance).to receive(:execute).and_return(trial_success)
    end
  end

  def expect_apply_trial_success(user, group, extra_params: {})
    stub_apply_trial(user, namespace_id: group.id, success: true, extra_params: extra_params)
  end

  def expect_apply_ultimate_trial_success(user, group, extra_params: {})
    trial_user_params = {
      namespace_id: group.id,
      gitlab_com_trial: true,
      sync_to_gl: true
    }.merge(extra_params)

    service_params = {
      trial_user_information: trial_user_params,
      uid: user.id
    }

    expect_next_instance_of(apply_trial_service_class, service_params) do |instance|
      expect(instance).to receive(:execute).and_return(ServiceResponse.success)
    end
  end

  def expect_apply_trial_async(user, namespace: nil, extra_params: {})
    trial_user_information = extra_params.merge({
      namespace_id: be_a(Integer),
      gitlab_com_trial: true,
      sync_to_gl: true,
      namespace: anything
    })

    if namespace.present?
      trial_user_information[:namespace_id] = namespace.id
      trial_user_information[:namespace] = namespace.slice(:id, :name, :path, :kind, :trial_ends_on)
      trial_user_information[:namespace][:plan] = namespace.actual_plan_name
    end

    expect(GitlabSubscriptions::Trials::ApplyTrialWorker)
      .to receive(:perform_async).with(user.id, trial_user_information.deep_stringify_keys).and_call_original
  end

  def expect_apply_trial_fail(user, group, extra_params: {})
    stub_apply_trial(user, namespace_id: group.id, success: false, extra_params: extra_params)
  end

  def existing_group_attrs(group)
    { namespace: group.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: group.actual_plan.name) }
  end

  def new_group_attrs(path: 'gitlab')
    {
      namespace: {
        id: anything,
        path: path,
        name: 'gitlab',
        kind: 'group',
        trial_ends_on: nil,
        plan: 'free'
      }
    }
  end
end
