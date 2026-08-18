# frozen_string_literal: true

RSpec.shared_context 'with group on GitLab.com' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
  end
end

RSpec.shared_context 'with self-managed instance' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
  end
end

RSpec.shared_context 'with duo add-on seat helper' do
  def duo_add_on_seat_user
    if defined?(current_user) && current_user.present?
      current_user
    elsif defined?(user) && user.present?
      user
    end
  end

  def assign_duo_add_on_seat(add_on_purchase)
    seat_user = duo_add_on_seat_user
    return unless seat_user

    active_assignment = GitlabSubscriptions::UserAddOnAssignment.find_by(
      user: seat_user, add_on_purchase: add_on_purchase)

    return if active_assignment

    create(:gitlab_subscription_user_add_on_assignment, user: seat_user, add_on_purchase: add_on_purchase)
  end
end

RSpec.shared_context 'with ai features enabled for group' do
  include_context 'with group on GitLab.com'
  include_context 'with duo pro addon'

  before do
    allow(group.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
    stub_licensed_features(
      ai_features: true,
      glab_ask_git_command: true,
      generate_description: true
    )
    group.namespace_settings.reload.update!(experiment_features_enabled: true)
  end
end

RSpec.shared_context 'with experiment features disabled for group' do
  include_context 'with group on GitLab.com'
  include_context 'with duo pro addon'

  before do
    allow(group.namespace_settings)
      .to receive_messages(experiment_settings_allowed?: true, prompt_cache_settings_allowed?: true)
    stub_licensed_features(
      glab_ask_git_command: true,
      ai_features: true,
      generate_description: true
    )
    group.namespace_settings.update!(experiment_features_enabled: false)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat available for self-managed' do
  include_context 'with self-managed instance'
  include_context 'with duo pro self-managed addon'

  before do
    stub_application_setting(duo_features_enabled: true)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features enabled and agentic chat available for self-managed' do
  include_context 'with self-managed instance'
  include_context 'with duo pro self-managed addon'

  before do
    stub_application_setting(duo_features_enabled: true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat not available for self-managed' do
  include_context 'with self-managed instance'
  include_context 'with duo pro self-managed addon'

  before do
    stub_application_setting(duo_features_enabled: true)
    stub_licensed_features(ai_chat: false)
  end
end

RSpec.shared_context 'with duo features disabled and ai chat available for self-managed' do
  include_context 'with self-managed instance'
  include_context 'with duo pro self-managed addon'

  before do
    stub_application_setting(duo_features_enabled: false)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features always off for self-managed' do
  include_context 'with self-managed instance'
  include_context 'with duo pro self-managed addon'

  before do
    stub_application_setting(duo_features_enabled: false, lock_duo_features_enabled: true)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat available for group on SaaS' do
  include_context 'with group on GitLab.com'
  include_context 'with duo pro addon'
  include_context 'without ai usage quota check'

  before do
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: true)
    create(:cloud_connector_keys)
  end
end

RSpec.shared_context 'with duo features enabled and agentic chat available for group on SaaS' do
  include_context 'with group on GitLab.com'
  include_context 'with duo pro addon'
  include_context 'without ai usage quota check'

  before do
    stub_licensed_features(agentic_chat: true, troubleshoot_job: true)
    group.namespace_settings.reload.update!(duo_features_enabled: true, experiment_features_enabled: true)
    create(:cloud_connector_keys)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat not available for group on SaaS' do
  include_context 'with group on GitLab.com'
  include_context 'with duo pro addon'

  before do
    stub_licensed_features(ai_chat: false)
    group.namespace_settings.reload.update!(duo_features_enabled: true)
  end
end

RSpec.shared_context 'with duo features disabled and ai chat available for group on SaaS' do
  include_context 'with group on GitLab.com'
  include_context 'with duo pro addon'

  before do
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: false)
  end
end

RSpec.shared_context 'with duo pro addon' do
  include_context 'with duo add-on seat helper'

  # To accommodate existing specs that use this config
  # this helper assign seat in an addon for both
  # current_user or user depends on which one is defined
  before do
    next unless duo_add_on_seat_user

    # As this context could be included in tests multiple times,
    # we first search by active purchases and are trying to not create
    # entities twice because it will cause an ActiveRecord error in tests
    active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: group)
    add_on = GitlabSubscriptions::AddOn.find_or_create_by_name(:code_suggestions, group)
    active_purchase ||= create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: group)

    assign_duo_add_on_seat(active_purchase)
  end
end

RSpec.shared_context 'with duo pro self-managed addon' do
  include_context 'with duo add-on seat helper'

  # To accommodate existing specs that use this config
  # this helper assign seat in an addon for both
  # current_user or user depends on which one is defined
  before do
    next unless duo_add_on_seat_user

    # As this context could be included in tests multiple times,
    # we first search by active purchases and are trying to not create
    # entities twice because it will cause an ActiveRecord error in tests
    active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: nil)
    add_on = GitlabSubscriptions::AddOn.find_or_create_by_name(:code_suggestions)
    active_purchase ||= create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: nil)

    assign_duo_add_on_seat(active_purchase)
  end
end

# This context is the same as the one for Duo Pro
# only difference is the purchased addon
RSpec.shared_context 'with duo enterprise addon' do
  include_context 'with duo add-on seat helper'

  before do
    next unless duo_add_on_seat_user

    active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: group)
    active_purchase ||= create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)

    assign_duo_add_on_seat(active_purchase)
  end
end

RSpec.shared_context 'with duo enterprise trial addon' do
  include_context 'with duo add-on seat helper'

  before do
    next unless duo_add_on_seat_user

    active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: group)
    add_on = GitlabSubscriptions::AddOn.find_or_create_by_name(:duo_enterprise)
    active_purchase ||= create(:gitlab_subscription_add_on_purchase, :trial, add_on: add_on, namespace: group)

    assign_duo_add_on_seat(active_purchase)
  end
end

RSpec.shared_context 'with agentic chat for duo enterprise trial on SaaS' do
  include_context 'with group on GitLab.com'
  include_context 'with duo enterprise trial addon'
  include_context 'without ai usage quota check'

  before do
    stub_licensed_features(agentic_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: true, experiment_features_enabled: true)
    create(:cloud_connector_keys)
  end
end

# This context is the same as the ones for Duo Pro and Enterprise
# only difference is the purchased addon
RSpec.shared_context 'with duo core addon' do
  include_context 'with duo add-on seat helper'

  before do
    next unless duo_add_on_seat_user

    active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: group)
    active_purchase || create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group)
  end
end

RSpec.shared_context 'without ai usage quota check' do
  let(:bypass_ai_usage_quota_check) { true }

  before do
    next unless bypass_ai_usage_quota_check

    allow_next_instance_of(::Ai::UsageQuotaService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.success)
    end
  end
end
