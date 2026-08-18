# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespace, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  include EE::GeoHelpers
  include NamespaceStorageHelpers

  let_it_be(:organization) { create(:organization) }
  let(:namespace) { create(:namespace, organization: organization) }
  let_it_be_with_reload(:ultimate_plan) { create(:ultimate_plan) }

  it { is_expected.to have_one(:namespace_limit) }
  it { is_expected.to have_one(:elasticsearch_indexed_namespace) }

  it 'has one security_orchestration_policy_configuration' do
    is_expected.to have_one(:security_orchestration_policy_configuration)
      .class_name('Security::OrchestrationPolicyConfiguration').with_foreign_key(:namespace_id)
  end

  it { is_expected.to have_one :upcoming_reconciliation }
  it { is_expected.to have_one(:storage_limit_exclusion) }
  it { is_expected.to have_one(:system_access_microsoft_application) }
  it { is_expected.to have_one(:group_system_access_microsoft_application) }
  it { is_expected.to have_many(:ci_minutes_additional_packs) }
  it { is_expected.to have_many(:member_roles) }
  it { is_expected.to have_many(:subscription_add_on_purchases).class_name('GitlabSubscriptions::AddOnPurchase') }
  it { is_expected.to have_one :onboarding_progress }
  it { is_expected.to have_one(:audit_event_http_namespace_filter) }
  it { is_expected.to have_one(:audit_event_http_instance_namespace_filter) }
  it { is_expected.to have_one(:zoekt_enabled_namespace) }
  it { is_expected.to have_many(:work_items_colors) }

  it 'has many audit_events_streaming_group_namespace_filters' do
    is_expected.to have_many(:audit_events_streaming_group_namespace_filters)
      .class_name('AuditEvents::Group::NamespaceFilter')
  end

  it 'has many audit_events_streaming_instance_namespace_filters' do
    is_expected.to have_many(:audit_events_streaming_instance_namespace_filters)
      .class_name('AuditEvents::Instance::NamespaceFilter')
  end

  it { is_expected.to have_many(:custom_lifecycles).class_name('WorkItems::Statuses::Custom::Lifecycle') }
  it { is_expected.to have_one(:ai_settings).class_name('Ai::NamespaceSetting') }

  it 'has many foundational_agents_status_records' do
    is_expected.to have_many(:foundational_agents_status_records).class_name('Ai::NamespaceFoundationalAgentStatus')
  end

  it { is_expected.to have_many(:custom_statuses).class_name('WorkItems::Statuses::Custom::Status') }
  it { is_expected.to have_many(:converted_statuses).class_name('WorkItems::Statuses::Custom::Status') }
  it { is_expected.to have_many(:type_custom_lifecycles).class_name('WorkItems::TypeCustomLifecycle') }
  it { is_expected.to have_many(:enabled_foundational_flow_records).class_name('Ai::Catalog::EnabledFoundationalFlow') }
  it { is_expected.to have_many(:accessible_ai_features_on_instance).class_name('Ai::FeatureAccessRule') }
  it { is_expected.to have_many(:ai_feature_rules_through_namespace).class_name('Ai::NamespaceFeatureAccessRule') }
  it { is_expected.to have_many(:ai_feature_rules).class_name('Ai::NamespaceFeatureAccessRule') }

  it { is_expected.to delegate_method(:trial?).to(:gitlab_subscription) }
  it { is_expected.to delegate_method(:trial_ends_on).to(:gitlab_subscription) }
  it { is_expected.to delegate_method(:trial_starts_on).to(:gitlab_subscription) }
  it { is_expected.to delegate_method(:start_date).to(:gitlab_subscription).with_prefix.allow_nil }
  it { is_expected.to delegate_method(:end_date).to(:gitlab_subscription).with_prefix.allow_nil }
  it { is_expected.to delegate_method(:upgradable?).to(:gitlab_subscription) }
  it { is_expected.to delegate_method(:trial_extended_or_reactivated?).to(:gitlab_subscription) }
  it { is_expected.to delegate_method(:email).to(:owner).with_prefix.allow_nil }
  it { is_expected.to delegate_method(:additional_purchased_storage_size=).to(:namespace_limit).with_arguments(:args) }
  it { is_expected.to delegate_method(:additional_purchased_storage_ends_on).to(:namespace_limit) }

  it 'delegates additional_purchased_storage_ends_on= to namespace_limit' do
    is_expected.to delegate_method(:additional_purchased_storage_ends_on=).to(:namespace_limit).with_arguments(:args)
  end

  it { is_expected.to delegate_method(:experiment_features_enabled).to(:namespace_settings).allow_nil }

  it 'delegates experiment_features_enabled= to namespace_settings' do
    is_expected.to delegate_method(:experiment_features_enabled=).to(:namespace_settings)
      .with_arguments(:args).allow_nil
  end

  it { is_expected.to delegate_method(:duo_core_features_enabled).to(:namespace_settings).allow_nil }
  it { is_expected.to delegate_method(:duo_features_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_duo_features_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:ai_audit_events_storage_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_ai_audit_events_storage_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:duo_availability).to(:namespace_settings) }
  it { is_expected.to delegate_method(:auto_duo_code_review_enabled).to(:namespace_settings).allow_nil }

  it 'delegates auto_duo_code_review_enabled= to namespace_settings' do
    is_expected.to delegate_method(:auto_duo_code_review_enabled=).to(:namespace_settings)
      .with_arguments(:args).allow_nil
  end

  it { is_expected.to delegate_method(:duo_remote_flows_enabled).to(:namespace_settings).allow_nil }
  it { is_expected.to delegate_method(:lock_duo_remote_flows_enabled).to(:namespace_settings).allow_nil }
  it { is_expected.to delegate_method(:duo_custom_agents_enabled).to(:namespace_settings).allow_nil }
  it { is_expected.to delegate_method(:lock_duo_custom_agents_enabled).to(:namespace_settings).allow_nil }
  it { is_expected.to delegate_method(:duo_custom_flows_enabled).to(:namespace_settings).allow_nil }
  it { is_expected.to delegate_method(:lock_duo_custom_flows_enabled).to(:namespace_settings).allow_nil }

  it 'delegates security_policy_management_project to security_orchestration_policy_configuration' do
    is_expected.to delegate_method(:security_policy_management_project).to(:security_orchestration_policy_configuration)
  end

  it 'delegates allow_enterprise_bypass_placeholder_confirmation to namespace_settings' do
    is_expected.to delegate_method(:allow_enterprise_bypass_placeholder_confirmation).to(:namespace_settings).allow_nil
  end

  it 'delegates allow_enterprise_bypass_placeholder_confirmation= to namespace_settings' do
    is_expected.to delegate_method(:allow_enterprise_bypass_placeholder_confirmation=).to(:namespace_settings)
      .with_arguments(:args)
  end

  it { is_expected.to delegate_method(:enterprise_bypass_expires_at).to(:namespace_settings).allow_nil }
  it { is_expected.to delegate_method(:enterprise_bypass_expires_at=).to(:namespace_settings).with_arguments(:args) }
  it { is_expected.to delegate_method(:foundational_agents_default_enabled).to(:ai_settings) }
  it { is_expected.to delegate_method(:foundational_agents_default_enabled=).to(:ai_settings).with_arguments(:args) }
  it { is_expected.to delegate_method(:prompt_injection_protection_level).to(:ai_settings) }
  it { is_expected.to delegate_method(:prompt_injection_protection_level=).to(:ai_settings).with_arguments(:args) }
  it { is_expected.to delegate_method(:duo_workflow_mcp_enabled).to(:ai_settings) }
  it { is_expected.to delegate_method(:duo_workflow_mcp_enabled=).to(:ai_settings).with_arguments(:args) }
  it { is_expected.to delegate_method(:duo_agent_platform_enabled).to(:ai_settings) }
  it { is_expected.to delegate_method(:duo_agent_platform_enabled=).to(:ai_settings).with_arguments(:args) }
  it { is_expected.to delegate_method(:ai_usage_data_collection_enabled).to(:ai_settings) }
  it { is_expected.to delegate_method(:ai_usage_data_collection_enabled=).to(:ai_settings).with_arguments(:args) }
  it { is_expected.to delegate_method(:duo_remote_flows_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_duo_remote_flows_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:duo_foundational_flows_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_duo_foundational_flows_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:duo_custom_agents_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_duo_custom_agents_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:duo_custom_flows_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_duo_custom_flows_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:built_in_project_templates_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_built_in_project_templates_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:tool_approval_for_session_enabled).to(:namespace_settings) }
  it { is_expected.to delegate_method(:lock_tool_approval_for_session_enabled).to(:namespace_settings) }

  shared_examples 'plan helper' do |namespace_plan|
    let(:namespace) { create(:namespace_with_plan, plan: "#{plan_name}_plan") }

    subject { namespace.public_send(:"#{namespace_plan}_plan?") }

    context "for a #{namespace_plan} plan" do
      let(:plan_name) { namespace_plan }

      it { is_expected.to be(true) }
    end

    context "for a plan that isn't #{namespace_plan}" do
      where(plan_name: ::Plan.all_plans - [namespace_plan])

      with_them do
        it { is_expected.to be(false) }
      end
    end
  end

  # Test only plans that have corresponding methods (excluding removed bronze, silver, gold methods)
  active_plan_methods = ::Plan.all_plans - %w[bronze silver gold]
  active_plan_methods.each do |namespace_plan|
    describe "#{namespace_plan}_plan?", :saas do
      it_behaves_like 'plan helper', namespace_plan
    end
  end

  describe '#free_personal?' do
    let_it_be_with_reload(:namespace) { create(:namespace, organization: organization) }

    where(:user, :paid, :expected) do
      true  | false | true
      false | false | false
      false | true  | false
    end

    with_them do
      before do
        allow(namespace).to receive_messages(user_namespace?: user, paid?: paid)
      end

      it 'returns expected boolean value' do
        expect(namespace.free_personal?).to eq(expected)
      end
    end
  end

  describe '#linked_to_subscription?' do
    let_it_be_with_reload(:namespace) { create(:namespace, organization: organization) }

    where(:paid, :trial, :expected) do
      true  | false | true
      false | false | false
      false | true  | false
      true  | true  | false
    end

    with_them do
      before do
        allow(namespace).to receive_messages(trial?: trial, paid?: paid)
      end

      it 'returns expected boolean value' do
        expect(namespace.linked_to_subscription?).to eq(expected)
      end
    end
  end

  describe '#use_elasticsearch?' do
    let_it_be(:namespace) { create :namespace }

    it 'returns false if elasticsearch indexing is disabled' do
      stub_ee_application_setting(elasticsearch_indexing: false)

      expect(namespace.use_elasticsearch?).to be(false)
    end

    it 'returns true if elasticsearch indexing enabled but limited indexing disabled' do
      stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: false)

      expect(namespace.use_elasticsearch?).to be(true)
    end

    it 'returns true if it is enabled specifically' do
      stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: true)

      expect(namespace.use_elasticsearch?).to be(false)

      create :elasticsearch_indexed_namespace, namespace: namespace

      expect(namespace.use_elasticsearch?).to be(true)
    end
  end

  describe '#use_zoekt?', feature_category: :global_search do
    it 'delegates to ::Search::Zoekt' do
      expect(::Search::Zoekt).to receive(:index?).with(namespace).and_return(true)

      expect(namespace.use_zoekt?).to be(true)
    end
  end

  describe '#hashed_root_namespace_id', feature_category: :global_search do
    it 'delegates to Search.hash_namespace_id' do
      expect(::Search).to receive(:hash_namespace_id).with(namespace.root_ancestor.id).and_return 8_675_309
      expect(namespace.hashed_root_namespace_id).to eq(8_675_309)
    end
  end

  describe '#invalidate_elasticsearch_indexes_cache!' do
    let(:namespace) { create :namespace }

    it 'clears the cache for the namespace' do
      expect(::Search::Elastic::ElasticsearchEnabledCache).to receive(:delete_record).with(:namespace, namespace.id)

      namespace.invalidate_elasticsearch_indexes_cache!
    end
  end

  describe '#has_subscription?' do
    subject { namespace.has_subscription? }

    context 'when namespace does not have a subscription associated' do
      it { is_expected.to be(false) }
    end

    context 'when namespace has a subscription associated', :saas do
      before do
        create(:gitlab_subscription, namespace: namespace, hosted_plan: ultimate_plan)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#actual_plan_name' do
    let_it_be_with_refind(:namespace) { create(:namespace) }

    subject(:actual_plan_name) { namespace.actual_plan_name }

    context 'when namespace does not have a subscription associated' do
      it 'returns default plan' do
        expect(actual_plan_name).to eq('default')
      end
    end

    context 'when running on Gitlab.com', :saas do
      context 'when namespace has a subscription associated' do
        before do
          create(:gitlab_subscription, namespace: namespace, hosted_plan: ultimate_plan)
        end

        it 'returns the associated plan name' do
          expect(actual_plan_name).to eq 'ultimate'
        end
      end

      context 'when namespace does not have subscription associated' do
        it 'returns a free plan name' do
          expect(actual_plan_name).to eq 'free'
        end
      end

      context 'when the database is read-only' do
        before do
          allow(Gitlab::Database).to receive(:read_only?).and_return(true)
        end

        it 'returns free plan' do
          expect(Gitlab::Database).to receive(:read_only?)

          expect(actual_plan_name).to eq('free')
        end

        it 'does not create a gitlab_subscription' do
          expect(Gitlab::Database).to receive(:read_only?)

          expect { actual_plan_name }.not_to change { GitlabSubscription.count }
        end
      end

      context 'when namespace is not persisted' do
        let(:namespace) { build(:namespace) }

        it 'returns free plan' do
          expect(actual_plan_name).to eq('free')
        end

        it 'does not create a gitlab_subscription' do
          expect { actual_plan_name }.not_to change { GitlabSubscription.count }
        end
      end

      context 'when the database is not read-only' do
        it 'returns free plan' do
          expect(actual_plan_name).to eq('free')
        end

        it 'creates a gitlab_subscription' do
          expect { actual_plan_name }.to change { GitlabSubscription.count }.by(1)
        end
      end
    end
  end

  context 'when using scopes' do
    describe '.id_greater_than' do
      let_it_be(:namespace1) { create(:group) }
      let_it_be(:namespace2) { create(:group) }
      let_it_be(:namespace3) { create(:group) }

      it 'returns namespaces with id greater than the specified value' do
        expect(described_class.id_greater_than(namespace1.id)).to include(namespace2, namespace3)
      end

      it 'returns empty when no records have greater id' do
        expect(described_class.id_greater_than(namespace3.id)).not_to include(namespace1, namespace2, namespace3)
      end
    end

    describe '.with_feature_available_in_plan', :saas do
      let(:starter_feature) { :audit_events }
      let(:premium_feature) { :epics }
      let(:ultimate_feature) { :dast }

      context 'when Bronze plan has Starter features' do
        let_it_be(:bronze_namespace) { create(:namespace_with_plan, plan: :bronze_plan) }

        it 'returns namespaces with plan' do
          create(:namespace_with_plan, plan: :free_plan)

          expect(described_class.with_feature_available_in_plan(starter_feature)).to match_array([bronze_namespace])
        end

        it 'includes namespace from higher plans' do
          ultimate_namespace = create(:namespace_with_plan, plan: :ultimate_plan)

          expect(described_class.with_feature_available_in_plan(starter_feature))
            .to include(ultimate_namespace)
        end
      end

      context 'when Silver, Premium and Premium_trial plans have Premium license features' do
        let_it_be(:silver_namespace) { create(:namespace_with_plan, plan: :silver_plan) }
        let_it_be(:premium_namespace) { create(:namespace_with_plan, plan: :premium_plan) }
        let_it_be(:premium_trial_namespace) { create(:namespace_with_plan, plan: :premium_trial_plan) }
        let_it_be(:not_included_namespace) { create(:namespace_with_plan, plan: :bronze_plan) }

        it 'returns namespaces with matching plans' do
          expect(described_class.with_feature_available_in_plan(premium_feature))
            .to contain_exactly(silver_namespace, premium_namespace, premium_trial_namespace)
        end

        it 'includes namespace from higher plans' do
          ultimate_namespace = create(:namespace_with_plan, plan: :ultimate_plan)

          expect(described_class.with_feature_available_in_plan(premium_feature))
            .to include(ultimate_namespace)
        end
      end

      context 'when Gold, Ultimate, Ultimate_trial and OpenSource plans have Ultimate license features' do
        let_it_be(:gold_namespace) { create(:namespace_with_plan, plan: :gold_plan) }
        let_it_be(:ultimate_namespace) { create(:namespace_with_plan, plan: :ultimate_plan) }
        let_it_be(:ultimate_trial_namespace) { create(:namespace_with_plan, plan: :ultimate_trial_plan) }
        let_it_be(:opensource_namespace) { create(:namespace_with_plan, plan: :opensource_plan) }

        it 'returns namespaces with matching plans' do
          create(:gitlab_subscription, :bronze, namespace: namespace)

          expect(described_class.with_feature_available_in_plan(ultimate_feature))
            .to contain_exactly(gold_namespace, ultimate_namespace, ultimate_trial_namespace, opensource_namespace)
        end
      end

      context 'when no namespace matches the feature' do
        let_it_be(:bronze_namespace) { create(:namespace_with_plan, plan: :bronze_plan) }
        let_it_be(:silver_namespace) { create(:namespace_with_plan, plan: :silver_plan) }

        it 'returns an empty list' do
          expect(described_class.with_feature_available_in_plan(ultimate_feature)).to be_empty
        end
      end
    end

    describe '.join_gitlab_subscription', :saas do
      let_it_be(:namespace) { create(:namespace) }

      subject do
        described_class.join_gitlab_subscription.select('gitlab_subscriptions.hosted_plan_id').first.hosted_plan_id
      end

      context 'when there is no subscription' do
        it 'returns namespace with nil subscription' do
          is_expected.to be_nil
        end
      end

      context 'when there is a subscription' do
        let_it_be(:subscription) do
          create(:gitlab_subscription, namespace: namespace, hosted_plan_id: ultimate_plan.id)
        end

        it 'returns namespace with subscription set' do
          is_expected.to eq(ultimate_plan.id)
        end
      end
    end

    describe '.not_in_active_trial', :saas do
      let_it_be(:namespaces) do
        [
          create(:namespace),
          create(:namespace_with_plan),
          create(
            :namespace_with_plan,
            trial: true,
            trial_starts_on: 1.month.ago,
            trial_ends_on: Date.yesterday
          )
        ]
      end

      it 'is consistent with !trial_active? method' do
        namespaces.each do |ns|
          consistent = described_class.not_in_active_trial.include?(ns) == !ns.trial_active?

          expect(consistent).to be true
        end
      end
    end

    describe '.in_specific_plans', :saas do
      let_it_be(:free_namespace) { create(:group_with_plan, plan: :free_plan) }
      let_it_be(:premium_namespace) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:ultimate_namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      it 'returns namespaces with the specified plan names' do
        result = described_class.in_specific_plans(%w[ultimate premium])

        expect(result).to include(ultimate_namespace, premium_namespace)
        expect(result).not_to include(free_namespace)
      end

      it 'returns an empty relation when no matching plans are found' do
        result = described_class.in_specific_plans('gold')

        expect(result).to be_empty
      end

      it 'returns all namespaces when all plan names are specified' do
        result = described_class.in_specific_plans(%w[free ultimate premium])

        expect(result).to include(free_namespace, ultimate_namespace, premium_namespace)
      end

      it 'does not return namespaces without subscriptions' do
        namespace_without_subscription = create(:namespace)
        result = described_class.in_specific_plans(%w[free ultimate premium])

        expect(result).not_to include(namespace_without_subscription)
      end

      it 'allows chaining with other scopes' do
        result = described_class.id_in(ultimate_namespace).in_specific_plans(['ultimate'])

        expect(result).to contain_exactly(ultimate_namespace)
      end

      it 'does not return subgroups' do
        subgroup = create(:group, parent: ultimate_namespace)

        result = described_class.id_in(subgroup).in_specific_plans([nil])

        expect(result).to be_empty
      end
    end

    describe '.not_free', :saas do
      let_it_be(:free_namespace) { create(:group_with_plan, plan: :free_plan) }
      let_it_be(:premium_namespace) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:ultimate_namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      it 'returns namespaces not on the free plan' do
        result = described_class.not_free

        expect(result).to contain_exactly(ultimate_namespace, premium_namespace)
      end

      it 'does not return namespaces without subscriptions' do
        create(:namespace)
        result = described_class.not_free

        expect(result).to contain_exactly(ultimate_namespace, premium_namespace)
      end

      it 'allows chaining with other scopes' do
        result = described_class.id_in(premium_namespace).not_free

        expect(result).to contain_exactly(premium_namespace)
      end

      it 'does not return subgroups' do
        subgroup = create(:group, parent: ultimate_namespace)

        result = described_class.id_in(subgroup).not_free

        expect(result).to be_empty
      end
    end

    describe '.namespace_settings_with_ai_features_enabled' do
      subject { described_class.namespace_settings_with_ai_features_enabled }

      let_it_be_with_reload(:namespace) { create(:namespace, :with_namespace_settings) }

      before do
        allow(namespace.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
        namespace.namespace_settings.update!(
          experiment_features_enabled: experiment_features_enabled
        )
      end

      context 'when experimental features are enabled' do
        let(:experiment_features_enabled) { true }

        it { is_expected.to contain_exactly(namespace) }
      end

      context 'when experimental features are disabled' do
        let(:experiment_features_enabled) { false }

        it { is_expected.to be_empty }
      end
    end

    describe '.namespace_settings_with_duo_core_features_enabled' do
      subject { described_class.namespace_settings_with_duo_core_features_enabled }

      let_it_be_with_reload(:group) { create(:group) }

      before do
        group.namespace_settings.update!(
          duo_core_features_enabled: duo_core_features_enabled
        )
      end

      context 'when duo_core_features_enabled is true' do
        let(:duo_core_features_enabled) { true }

        it { is_expected.to contain_exactly(group) }
      end

      context 'when duo_core_features_enabled is false' do
        let(:duo_core_features_enabled) { false }

        it { is_expected.to be_empty }
      end

      context 'when duo_core_features_enabled is null' do
        let(:duo_core_features_enabled) { nil }

        it { is_expected.to be_empty }
      end
    end

    describe '.namespace_settings_with_experiment_duo_features_enabled' do
      subject { described_class.namespace_settings_with_experiment_duo_features_enabled }

      let_it_be_with_reload(:group) { create(:group) }

      where(:experiment_features_enabled, :duo_features_enabled, :included_in_results) do
        true  | true  | true
        true  | false | false
        false | true  | false
        false | false | false
        true  | nil   | false
        false | nil   | false
      end

      with_them do
        before do
          allow(group.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
          group.namespace_settings.update!(
            experiment_features_enabled: experiment_features_enabled,
            duo_features_enabled: duo_features_enabled
          )
        end

        it 'returns the correct namespaces' do
          if included_in_results
            is_expected.to contain_exactly(group)
          else
            is_expected.to be_empty
          end
        end
      end
    end

    describe '.with_ai_supported_plan', :saas do
      subject { described_class.with_ai_supported_plan }

      let_it_be(:premium_namespace) { create(:namespace_with_plan, plan: :premium_plan) }
      let_it_be(:ultimate_namespace) { create(:namespace_with_plan, plan: :ultimate_plan) }
      let_it_be(:ultimate_trial_namespace) { create(:namespace_with_plan, plan: :ultimate_trial_plan) }
      let_it_be(:opensource_namespace) { create(:namespace_with_plan, plan: :opensource_plan) }

      it { is_expected.to contain_exactly(ultimate_namespace, ultimate_trial_namespace, opensource_namespace) }

      context 'with ai_chat feature' do
        subject { described_class.with_ai_supported_plan(:ai_chat) }

        it 'returns namespaces with ai_chat supported plan' do
          is_expected.to contain_exactly(ultimate_namespace, ultimate_trial_namespace, premium_namespace,
            opensource_namespace)
        end
      end

      context 'with a credits-eligible feature' do
        subject { described_class.with_ai_supported_plan(:agentic_chat) }

        let_it_be(:free_group) { create(:group_with_plan, plan: :free_plan, organization: organization) }
        let_it_be(:no_plan_group) { create(:group, organization: organization) }
        let_it_be(:credits_purchase) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: free_group)
        end

        it 'includes namespaces with active gitlab_credits add-on' do
          is_expected.to include(free_group)
        end

        it 'does not include namespaces without eligible plan and without credits' do
          is_expected.not_to include(no_plan_group)
        end
      end
    end

    describe '.with_group_wiki_repositories' do
      subject { described_class.with_group_wiki_repositories }

      let_it_be(:namespace_without_group_wiki_repository) { create(:group) }

      let_it_be(:namespace_with_group_wiki_repository) { create(:group) }
      let_it_be(:group_wiki_repository) { create(:group_wiki_repository, group: namespace_with_group_wiki_repository) }

      it { is_expected.to contain_exactly(namespace_with_group_wiki_repository) }
    end

    describe '.root_namespaces_without_zoekt_enabled_namespace' do
      let_it_be(:sub_namespace) { create(:group, :nested) }
      let_it_be(:top_namespace) { create(:namespace) }
      let_it_be(:top_namespace2) { create(:namespace) }
      let(:results) { described_class.root_namespaces_without_zoekt_enabled_namespace }

      before do
        create(:zoekt_enabled_namespace, root_namespace_id: top_namespace2.id)
      end

      it 'returns only root namespaces without zoekt_enabled_namespace' do
        expect(results).to include(sub_namespace.root_ancestor, top_namespace)
        expect(results).not_to include(top_namespace2)
      end
    end

    describe '.in_active_trial', :saas do
      let_it_be(:namespace_with_active_trial) do
        create(:namespace_with_plan, plan: :ultimate_trial_plan,
          trial: true,
          trial_starts_on: 1.month.ago,
          trial_ends_on: 1.month.from_now)
      end

      let_it_be(:namespace_with_expired_trial) do
        create(:namespace_with_plan, plan: :ultimate_trial_plan,
          trial: true,
          trial_starts_on: 2.months.ago,
          trial_ends_on: 1.day.ago)
      end

      let_it_be(:namespace_without_trial) do
        create(:namespace_with_plan, plan: :ultimate_plan)
      end

      it 'returns only namespaces with active trials' do
        expect(described_class.in_active_trial).to contain_exactly(namespace_with_active_trial)
      end

      it 'excludes namespaces with expired trials' do
        expect(described_class.in_active_trial).not_to include(namespace_with_expired_trial)
      end

      it 'excludes namespaces without trials' do
        expect(described_class.in_active_trial).not_to include(namespace_without_trial)
      end
    end

    describe '.free_or_trial', :saas do
      let_it_be(:namespace_with_active_trial) do
        create(:namespace_with_plan, plan: :ultimate_trial_plan,
          trial: true,
          trial_starts_on: 1.month.ago,
          trial_ends_on: 1.month.from_now)
      end

      let_it_be(:namespace_with_free_plan) do
        create(:namespace_with_plan, plan: :free_plan)
      end

      let_it_be(:namespace_with_ultimate_plan) do
        create(:namespace_with_plan, plan: :ultimate_plan)
      end

      let_it_be(:namespace_without_subscription) { create(:namespace) }

      it 'returns namespaces with active trials' do
        expect(described_class.free_or_trial).to include(namespace_with_active_trial)
      end

      it 'returns namespaces with free plan' do
        expect(described_class.free_or_trial).to include(namespace_with_free_plan)
      end

      it 'excludes namespaces with paid plans' do
        expect(described_class.free_or_trial).not_to include(namespace_with_ultimate_plan)
      end
    end
  end

  context 'when validating' do
    it "ensures max_pages_size is an integer greater than 0 (or equal to 0 to indicate unlimited/maximum)" do
      is_expected.to validate_numericality_of(:max_pages_size).only_integer.is_greater_than_or_equal_to(0)
                       .is_less_than(::Gitlab::Pages::MAX_SIZE / 1.megabyte)
    end
  end

  describe 'custom validations' do
    describe '#validate_shared_runner_minutes_support' do
      context 'when changing :shared_runners_minutes_limit' do
        before do
          group.shared_runners_minutes_limit = 100
        end

        context 'when group is a subgroup' do
          let(:group) { create(:group, :nested) }

          it 'is invalid' do
            expect(group).not_to be_valid
            expect(group.errors[:shared_runners_minutes_limit]).to include('is not supported for this namespace')
          end
        end

        context 'when group is root' do
          let(:group) { create(:group) }

          it 'is valid' do
            expect(group).to be_valid
          end
        end
      end
    end
  end

  describe "foundational agents settings" do
    it_behaves_like 'settings with foundational agents statuses' do
      let_it_be(:instance) { create(:namespace, organization: organization) }
    end
  end

  describe 'keeping elasticsearch up to date' do
    it 'includes Elastic::NamespaceUpdate concern' do
      expect(described_class).to include_module(Elastic::NamespaceUpdate)
    end
  end

  describe 'after_commit :sync_name_with_customers_dot', :request_store do
    let(:owner) { create(:user) }
    let(:namespace) { create(:group, organization: organization) }
    let(:privatized_by_abuse_automation) { false }
    let(:block_namespace_name_update) { false }

    subject(:update_namespace) { namespace.update!(attributes) }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      allow(owner).to receive(:privatized_by_abuse_automation?)
        .and_return(privatized_by_abuse_automation)
      allow(::Gitlab::ApplicationRateLimiter).to receive(:peek).and_call_original
      allow(::Gitlab::ApplicationRateLimiter).to receive(:peek)
        .with(:update_namespace_name, scope: namespace)
        .and_return(block_namespace_name_update)
    end

    shared_examples 'no sync' do
      it 'does not trigger a sync with CustomersDot' do
        expect(::Namespaces::SyncNamespaceNameWorker).not_to receive(:perform_async)

        update_namespace
      end
    end

    shared_examples 'sync' do
      it 'triggers a name sync with CustomersDot' do
        expect(::Namespaces::SyncNamespaceNameWorker).to receive(:perform_async)
          .with(namespace.id).once

        update_namespace
      end
    end

    context 'when the name is not updated' do
      let(:attributes) { { path: 'Foo' } }

      before do
        namespace.add_owner(owner)
      end

      include_examples 'no sync'
    end

    context 'when the name is updated' do
      let(:attributes) { { name: 'Foo' } }

      before do
        allow(namespace).to receive(:skip_sync_with_customers_dot).and_return(false)
      end

      context 'when gitlab_com_subscriptions saas feature is not available' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        include_examples 'no sync'
      end

      context 'when project namespace' do
        let(:namespace) { create(:project_namespace, owner: owner) }

        context 'when the owner is privatized by abuse automation' do
          let(:privatized_by_abuse_automation) { true }

          include_examples 'no sync'
        end

        context 'when the owner is not privatized by abuse automation' do
          include_examples 'no sync'
        end
      end

      context 'when group namespace' do
        before do
          namespace.add_owner(owner)
        end

        context 'when the namespace is not root' do
          before do
            namespace.parent = build(:group, organization: organization)
          end

          include_examples 'no sync'
        end

        context 'when the root namespace is not trial nor paid' do
          before do
            allow(namespace.actual_plan).to receive(:paid?).and_return(false)
            allow(namespace).to receive(:trial?).and_return(false)
          end

          include_examples 'no sync'
        end

        context 'when the root namespace is on a paid plan', :saas do
          let_it_be_with_reload(:namespace) do
            create(:group_with_plan, plan: :ultimate_plan, organization: organization)
          end

          context 'when the owner is privatized by abuse automation' do
            let(:privatized_by_abuse_automation) { true }

            include_examples 'sync'
          end

          context 'when the owner is not privatized by abuse automation' do
            include_examples 'sync'
          end
        end
      end

      context 'when non-free user namespace', :saas do
        let(:namespace) do
          create(:namespace_with_plan, plan: :ultimate_plan, owner: owner)
        end

        context 'when the owner is privatized by abuse automation' do
          let(:privatized_by_abuse_automation) { true }

          include_examples 'no sync'
        end

        context 'when the owner is not privatized by abuse automation' do
          include_examples 'sync'

          context 'when the update to CustomersDot is blocked ay throttle' do
            let(:block_namespace_name_update) { true }

            include_examples 'no sync'
          end
        end
      end

      context 'when free user namespace' do
        let(:namespace) { create(:namespace, owner: owner) }

        before do
          allow(namespace.actual_plan).to receive(:paid?).and_return(false)
          namespace.parent = nil
        end

        context 'when the owner is privatized by abuse automation' do
          let(:privatized_by_abuse_automation) { true }

          include_examples 'no sync'
        end

        context 'when the owner is not privatized by abuse automation' do
          include_examples 'no sync'
        end
      end
    end

    describe 'multiple name updates', :saas do
      let_it_be_with_reload(:namespace) { create(:group_with_plan, plan: :ultimate_plan, organization: organization) }

      context 'when two name updates for the same namespace happen during the same minute' do
        it 'does not trigger a CustomersDot update the second time around' do
          travel_to 2.minutes.from_now do
            expect(::Namespaces::SyncNamespaceNameWorker).to receive(:perform_async).with(namespace.id)
            namespace.update!(name: 'new name')

            expect(::Namespaces::SyncNamespaceNameWorker).not_to receive(:perform_async)
            namespace.update!(name: 'new name 2')
          end
        end
      end

      context 'when two name updates for the same namespace happen more than a minute apart' do
        it 'triggers a CustomersDot update each time' do
          travel_to 2.minutes.from_now do
            expect(::Namespaces::SyncNamespaceNameWorker).to receive(:perform_async).with(namespace.id)
            namespace.update!(name: 'new name')
          end

          travel_to 4.minutes.from_now do
            expect(::Namespaces::SyncNamespaceNameWorker).to receive(:perform_async).with(namespace.id)
            namespace.update!(name: 'new name 2')
          end
        end
      end
    end
  end

  shared_examples 'feature available' do
    let(:hosted_plan) { create(:bronze_plan) }
    let(:group) { create(:group) }
    let(:licensed_feature) { :epics }
    let(:feature) { licensed_feature }

    before do
      create(:gitlab_subscription, namespace: group, hosted_plan: hosted_plan)

      stub_licensed_features(licensed_feature => true)
    end

    context 'when on SaaS instance' do
      before do
        stub_application_setting_on_object(group, should_check_namespace_plan: true)
      end

      it 'combines the global setting with the group setting' do
        is_expected.to be_falsy
      end

      context 'when feature available on the plan' do
        let(:hosted_plan) { create(:ultimate_plan) }

        context 'when feature available for current group' do
          it 'returns true' do
            is_expected.to be_truthy
          end
        end

        context 'when license is applied to parent group' do
          let(:child_group) { create :group, parent: group }

          it 'child group has feature available' do
            expect(child_group.licensed_feature_available?(feature)).to be_truthy
          end
        end
      end

      context 'when feature not available in the plan' do
        let(:feature) { :cluster_deployments }
        let(:hosted_plan) { create(:bronze_plan) }

        it 'returns false' do
          is_expected.to be_falsy
        end
      end

      context 'with global feature' do
        let(:licensed_feature) { GitlabSubscriptions::Features::GLOBAL_FEATURES.first }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "with service ping features" do
        let(:feature) { :scoped_issue_board }

        before do
          stub_application_setting(usage_ping_features_enabled: usage_ping_features_enabled)
          stub_licensed_features(feature => false)
        end

        context 'when service ping features are disabled' do
          let(:usage_ping_features_enabled) { false }

          it 'is disabled' do
            is_expected.to be(false)
          end
        end

        context 'when service ping features are enabled' do
          let(:usage_ping_features_enabled) { true }

          it 'is disabled' do
            is_expected.to be(false)
          end
        end
      end
    end

    context 'when on self managed instance' do
      before do
        stub_application_setting_on_object(group, should_check_namespace_plan: false)
      end

      it 'uses the global setting when running on premise' do
        is_expected.to be_truthy
      end

      context "with service ping features" do
        let(:feature) { :coverage_fuzzing }

        before do
          stub_application_setting(usage_ping_features_enabled: usage_ping_features_enabled)
        end

        context 'when service ping features are disabled' do
          let(:usage_ping_features_enabled) { false }

          it 'is disabled' do
            is_expected.to be(false)
          end
        end

        context 'when service ping features are enabled' do
          let(:usage_ping_features_enabled) { true }

          it 'is enabled' do
            is_expected.to be(true)
          end
        end
      end
    end
  end

  describe '#feature_available?', :saas do
    subject { group.licensed_feature_available?(feature) }

    it_behaves_like 'feature available'
  end

  describe '#feature_available_non_trial?', :saas do
    subject { group.feature_available_non_trial?(feature) }

    it_behaves_like 'feature available'

    context 'when the group has an active trial' do
      let(:hosted_plan) { create(:bronze_plan) }
      let(:group) { create(:group) }
      let(:feature) { :resource_access_token }

      before do
        create(:gitlab_subscription, :active_trial, namespace: group, hosted_plan: hosted_plan)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      it { is_expected.to be_falsey }

      context 'with a subgroup' do
        let(:subgroup) { create(:group, parent: group) }

        it 'feature is not available for the subgroup' do
          expect(subgroup.feature_available_non_trial?(feature)).to be_falsey
        end
      end
    end
  end

  describe '#actual_limits' do
    subject { namespace.actual_limits }

    shared_examples 'uses an implied configuration' do
      it 'is a non persisted PlanLimits' do
        expect(subject.id).to be_nil
        expect(subject).to be_a(PlanLimits)
      end

      it 'has all limits defined' do
        limits = subject.attributes.except('id', 'plan_id', 'repository_size', 'plan_name_uid',
          'dashboard_limit_enabled_at', 'updated_at')
        limits.each_value do |limit|
          expect(limit).not_to be_nil
        end
      end
    end

    context 'when no limits are defined in the system' do
      it_behaves_like 'uses an implied configuration'
    end

    context 'when "default" plan is defined in the system' do
      let_it_be(:default_plan) { create(:default_plan) }

      context 'when no limits are set' do
        it_behaves_like 'uses an implied configuration'
      end

      context 'when limits are set for the default plan' do
        let_it_be(:default_limits) do
          create(:plan_limits,
            plan: default_plan,
            ci_pipeline_size: 2,
            ci_active_jobs: 3)
        end

        it { is_expected.to eq(default_limits) }
      end

      context 'when "free" plan is defined in the system', :saas do
        let_it_be(:free_plan) { create(:free_plan) }

        context 'when no limits are set' do
          it_behaves_like 'uses an implied configuration'
        end

        context 'when limits are set for the free plan' do
          let_it_be(:free_limits) do
            create(:plan_limits,
              plan: free_plan,
              ci_pipeline_size: 4,
              ci_active_jobs: 5)
          end

          it { is_expected.to eq(free_limits) }
        end

        context 'when subscription plan is defined in the system' do
          let!(:subscription) { create(:gitlab_subscription, namespace: namespace, hosted_plan: ultimate_plan) }

          context 'when limits are not set for the plan' do
            it_behaves_like 'uses an implied configuration'
          end

          context 'when limits are set for the plan' do
            let_it_be(:subscription_limits) do
              create(:plan_limits,
                plan: ultimate_plan,
                ci_pipeline_size: 6,
                ci_active_jobs: 7)
            end

            it { is_expected.to eq(subscription_limits) }
          end
        end
      end
    end
  end

  describe '#any_project_with_shared_runners_enabled?' do
    subject { namespace.any_project_with_shared_runners_enabled? }

    context 'without projects' do
      it { is_expected.to be_falsey }
    end

    context 'with group having shared runners enabled project' do
      let!(:project) { create(:project, namespace: namespace, shared_runners_enabled: true) }

      it { is_expected.to be_truthy }
    end

    context 'with subgroup having shared runners enabled project' do
      let(:namespace) { create(:group) }
      let(:subgroup) { create(:group, parent: namespace) }
      let!(:subproject) { create(:project, namespace: subgroup, shared_runners_enabled: true) }

      it { is_expected.to be_truthy }
    end

    context 'with project and disabled shared runners' do
      let!(:project) do
        create(:project, namespace: namespace, shared_runners_enabled: false)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#shared_runners_minutes_limit_enabled?' do
    subject { namespace.shared_runners_minutes_limit_enabled? }

    context 'with project' do
      let!(:project) do
        create(:project, namespace: namespace, shared_runners_enabled: true)
      end

      context 'when no limit defined' do
        it { is_expected.to be_falsey }
      end

      context 'when limit is defined' do
        before do
          namespace.shared_runners_minutes_limit = 500
        end

        it { is_expected.to be_truthy }

        context 'when is subgroup' do
          before do
            namespace.parent = build(:group)
          end

          it { is_expected.to be_falsey }
        end
      end
    end

    context 'without project' do
      it { is_expected.to be_falsey }
    end
  end

  describe '#paid?', :saas do
    it 'returns true for a root namespace with a paid plan' do
      create(:gitlab_subscription, :ultimate, namespace: namespace)

      expect(namespace.paid?).to be(true)
    end

    it 'returns false for a subgroup of a group with a paid plan' do
      group = create(:group)
      subgroup = create(:group, parent: group)
      create(:gitlab_subscription, :ultimate, namespace: group)

      expect(subgroup.paid?).to be(false)
    end
  end

  describe '#actual_plan' do
    context 'when namespace does not have a subscription associated' do
      it 'generates a subscription and returns default plan' do
        expect(namespace.actual_plan).to eq(Plan.default)

        expect(namespace.gitlab_subscription).to be_nil
      end
    end

    context 'when gitlab_com_subscriptions saas feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'for personal namespaces' do
        context 'when namespace has a subscription associated', :saas do
          before do
            create(:gitlab_subscription, namespace: namespace, hosted_plan: ultimate_plan)
          end

          it 'returns the plan from the subscription' do
            expect(namespace.actual_plan).to eq(ultimate_plan)
            expect(namespace.gitlab_subscription).to be_present
          end
        end

        context 'when namespace does not have a subscription associated' do
          it 'generates a subscription and returns free plan' do
            expect(namespace.actual_plan).to eq(Plan.free)
            expect(namespace.gitlab_subscription).to be_present
          end

          context 'when free plan does exist' do
            let_it_be(:free_plan) { create(:free_plan) }

            it 'generates a subscription' do
              expect(namespace.actual_plan).to eq(free_plan)
              expect(namespace.gitlab_subscription).to be_present
            end
          end
        end
      end

      context 'for groups' do
        context 'when the group is a subgroup with a parent' do
          let_it_be(:parent) { create(:group) }
          let_it_be(:subgroup) { create(:group, parent: parent) }

          context 'when free plan does exist' do
            let_it_be(:free_plan) { create(:free_plan) }

            it 'does not generates a subscription' do
              expect(subgroup.actual_plan).to eq(free_plan)
              expect(subgroup.gitlab_subscription).not_to be_present
            end
          end

          context 'when parent group has a subscription associated', :saas do
            before do
              create(:gitlab_subscription, namespace: parent, hosted_plan: ultimate_plan)
            end

            it 'returns the plan from the subscription' do
              expect(subgroup.actual_plan).to eq(ultimate_plan)
              expect(subgroup.gitlab_subscription).not_to be_present
            end
          end
        end
      end
    end
  end

  describe '#billed_user_ids' do
    let(:user) { create(:user) }

    it 'returns 1' do
      expect(user.namespace.billed_user_ids.keys).to eq(
        [
          :user_ids,
          :group_member_user_ids,
          :project_member_user_ids,
          :shared_group_user_ids,
          :shared_project_user_ids
        ])
      expect(user.namespace.billed_user_ids[:user_ids]).to eq([user.id])
    end
  end

  describe '#has_active_add_on_purchase?' do
    let_it_be(:duo_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    context 'when current gitlab instance is saas', :saas do
      let_it_be(:parent) { create(:group) }
      let_it_be(:namespace) { create(:group, parent: parent) }

      context 'when current namespace has no duo enterprise add_on' do
        it 'has no active duo enterprise add_on' do
          expect(namespace.has_active_add_on_purchase?(:duo_enterprise)).to be_falsey
        end
      end

      context 'when root parent namespace has expired duo enterprise add_on' do
        it 'has no active duo enterprise add_on' do
          create(:gitlab_subscription_add_on_purchase, :expired, namespace: parent, add_on: duo_add_on)

          expect(namespace.has_active_add_on_purchase?(:duo_enterprise)).to be_falsey
        end
      end

      context 'when root namespace has active duo enterprise add_on' do
        let_it_be(:purchase) do
          create(:gitlab_subscription_add_on_purchase,
            namespace: parent,
            add_on: duo_add_on)
        end

        it 'has active duo enterprise add_on' do
          expect(namespace.has_active_add_on_purchase?(:duo_enterprise)).to be_truthy
        end
      end
    end

    context 'when current gitlab instance is self managed' do
      context 'when current self managed instance has duo enterprise add_on' do
        let_it_be(:purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_add_on)
        end

        it 'has active duo enterprise add_on' do
          expect(namespace.has_active_add_on_purchase?(:duo_enterprise)).to be_truthy
        end
      end

      context 'when the instance has expired duo enterprise add_on' do
        let_it_be(:purchase) do
          create(:gitlab_subscription_add_on_purchase, :expired, :self_managed, add_on: duo_add_on)
        end

        it 'has no active duo enterprise add_on' do
          expect(namespace.has_active_add_on_purchase?(:duo_enterprise)).to be_falsey
        end
      end
    end
  end

  describe '#has_active_gitlab_credits_add_on?' do
    let_it_be(:namespace) { create(:group) }

    subject { namespace.has_active_gitlab_credits_add_on? }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    context 'when namespace has an active gitlab_credits add-on' do
      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: namespace)
      end

      it { is_expected.to be_truthy }
    end

    context 'when namespace has an expired gitlab_credits add-on' do
      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :expired, namespace: namespace)
      end

      it { is_expected.to be_falsey }
    end

    context 'when namespace has no gitlab_credits add-on' do
      it { is_expected.to be_falsey }
    end

    context 'on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'with active instance-level gitlab_credits add-on' do
        before do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: nil,
            started_at: 1.day.ago.to_date, expires_on: 1.year.from_now.to_date)
        end

        it { is_expected.to be_truthy }

        it 'caches the result in SafeRequestStore', :request_store do
          expect(GitlabSubscriptions::AddOnPurchase).to receive(:for_active_add_ons).once.and_call_original

          namespace.has_active_gitlab_credits_add_on?
          namespace.has_active_gitlab_credits_add_on?
        end

        it 'uses the same cache across different namespaces', :request_store do
          other_namespace = create(:group)

          # First call should query the database
          expect(namespace.has_active_gitlab_credits_add_on?).to be_truthy

          # Second call on different namespace should use cache (no additional query)
          expect(GitlabSubscriptions::AddOnPurchase).not_to receive(:for_active_add_ons)
          expect(other_namespace.has_active_gitlab_credits_add_on?).to be_truthy
        end
      end

      context 'with expired instance-level gitlab_credits add-on' do
        before do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: nil,
            started_at: 1.year.ago.to_date, expires_on: 1.month.ago.to_date)
        end

        it { is_expected.to be_falsey }
      end

      context 'with no gitlab_credits add-on' do
        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#free_plan_with_gitlab_credits_add_on?', :saas_gitlab_com_subscriptions do
    subject { namespace.free_plan_with_gitlab_credits_add_on? }

    context 'when namespace is on a free plan with an active gitlab_credits add-on' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :free_plan) }

      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: namespace)
      end

      it { is_expected.to be_truthy }
    end

    context 'when namespace is on a free plan without a gitlab_credits add-on' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :free_plan) }

      it { is_expected.to be_falsey }
    end

    context 'when namespace is not on a free plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: namespace)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#auto_duo_code_review_settings_available?' do
    let_it_be_with_reload(:namespace) { create(:group) }
    let(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
    let(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:code_review_foundational_flow) { create(:ai_catalog_item, :with_foundational_flow_reference) }

    subject { namespace.auto_duo_code_review_settings_available? }

    context 'when duo_features_enabled is false' do
      before do
        allow(namespace).to receive(:duo_features_enabled).and_return(false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when duo_features_enabled is true' do
      before do
        allow(namespace).to receive(:duo_features_enabled).and_return(true)
      end

      context 'with duo_enterprise add-on (classic flow)' do
        context 'on SaaS', :saas do
          before do
            stub_ee_application_setting(should_check_namespace_plan: true)
          end

          context 'when add-on is active' do
            before do
              create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_enterprise_add_on)
            end

            it { is_expected.to be_truthy }
          end

          context 'when add-on is expired' do
            before do
              create(:gitlab_subscription_add_on_purchase, :expired, namespace: namespace,
                add_on: duo_enterprise_add_on)
            end

            it { is_expected.to be_falsey }
          end

          context 'for a subgroup' do
            let_it_be(:parent) { create(:group) }
            let_it_be(:subgroup) { create(:group, parent: parent) }

            subject { subgroup.auto_duo_code_review_settings_available? }

            before do
              allow(subgroup).to receive(:duo_features_enabled).and_return(true)
              create(:gitlab_subscription_add_on_purchase, namespace: parent, add_on: duo_enterprise_add_on)
            end

            it 'inherits from parent namespace' do
              is_expected.to be_truthy
            end
          end
        end

        context 'on self-managed' do
          context 'when instance has duo_enterprise add-on' do
            before do
              create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
            end

            it { is_expected.to be_truthy }
          end

          context 'when instance has expired duo_enterprise add-on' do
            before do
              create(:gitlab_subscription_add_on_purchase, :expired, :self_managed, add_on: duo_enterprise_add_on)
            end

            it { is_expected.to be_falsey }
          end
        end
      end

      context 'with DAP flow' do
        before do
          allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
            .with('code_review/v1')
            .and_return(
              instance_double(::Ai::Catalog::FoundationalFlow, catalog_item: code_review_foundational_flow)
            )
        end

        context 'on SaaS', :saas do
          before do
            stub_ee_application_setting(should_check_namespace_plan: true)
          end

          context 'when duo_foundational_flows_enabled is false' do
            before do
              namespace.namespace_settings.update!(duo_foundational_flows_enabled: false)
            end

            context 'with duo_core add-on' do
              before do
                create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
              end

              it { is_expected.to be_falsey }
            end
          end

          context 'when code_review workflow definition is nil' do
            before do
              namespace.namespace_settings.update!(duo_foundational_flows_enabled: true)
              allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
                .with('code_review/v1')
                .and_return(nil)
              create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
            end

            it { is_expected.to be_falsey }
          end

          context 'when duo_foundational_flows_enabled is true' do
            before do
              namespace.namespace_settings.update!(duo_foundational_flows_enabled: true)
            end

            context 'when code_review flow is not enabled' do
              before do
                allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                  .with(namespace, :duo_workflow).and_return(true)
              end

              context 'with duo_core add-on' do
                before do
                  create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
                end

                it { is_expected.to be_falsey }
              end
            end

            context 'when code_review flow is enabled' do
              before do
                create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace,
                  catalog_item: code_review_foundational_flow)
              end

              context 'when StageCheck returns false' do
                before do
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                    .with(namespace, :duo_workflow).and_return(false)
                end

                context 'with duo_core add-on' do
                  before do
                    create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: duo_core_add_on)
                  end

                  it { is_expected.to be_falsey }
                end
              end

              context 'when StageCheck returns true' do
                where(:add_on_type, :add_on_name) do
                  [
                    ['duo_pro',        :duo_pro],
                    ['duo_core',       :duo_core],
                    ['duo_enterprise', :duo_enterprise]
                  ]
                end

                with_them do
                  before do
                    add_on = create(:gitlab_subscription_add_on, add_on_name)
                    create(:gitlab_subscription_add_on_purchase, add_on_name, namespace: namespace, add_on: add_on)
                    allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                      .with(namespace, :duo_workflow).and_return(true)
                  end

                  it "returns true for #{params[:add_on_type]}" do
                    is_expected.to be_truthy
                  end
                end

                context 'when StageCheck returns true without any paid add-on' do
                  before do
                    allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                      .with(namespace, :duo_workflow).and_return(true)
                  end

                  it 'returns true for Free tier when DAP code review is available' do
                    is_expected.to be_truthy
                  end
                end

                context 'for subgroups inheriting add-ons from parent' do
                  let_it_be(:parent) { create(:group) }
                  let_it_be_with_reload(:subgroup) { create(:group, parent: parent) }

                  subject { subgroup.auto_duo_code_review_settings_available? }

                  where(:add_on_type, :add_on_name) do
                    [
                      ['duo_core',       :duo_core],
                      ['duo_enterprise', :duo_enterprise]
                    ]
                  end

                  with_them do
                    before do
                      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(subgroup,
                        :duo_workflow).and_return(true)
                      subgroup.namespace_settings.update!(duo_foundational_flows_enabled: true,
                        duo_features_enabled: true)
                      allow(subgroup).to receive(:enabled_flow_catalog_item_ids)
                        .and_return([code_review_foundational_flow.id])

                      add_on = create(:gitlab_subscription_add_on, add_on_name)
                      create(:gitlab_subscription_add_on_purchase, add_on_name, namespace: parent, add_on: add_on)
                    end

                    it "inherits #{params[:add_on_type]} from parent namespace" do
                      is_expected.to be_truthy
                    end
                  end
                end
              end
            end
          end
        end

        context 'on self-managed' do
          context 'when duo_foundational_flows_enabled is false' do
            before do
              namespace.namespace_settings.update!(duo_foundational_flows_enabled: false)
            end

            context 'when instance has duo_core add-on' do
              before do
                create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_core)
              end

              it { is_expected.to be_falsey }
            end

            context 'when instance has self_hosted_dap add-on' do
              before do
                create(:gitlab_subscription_add_on_purchase, :self_managed, :self_hosted_dap)
              end

              it { is_expected.to be_falsey }
            end
          end

          context 'when code_review workflow definition is nil' do
            where(:add_on_factory) do
              [[:duo_core], [:self_hosted_dap]]
            end

            with_them do
              before do
                namespace.namespace_settings.update!(duo_foundational_flows_enabled: true)
                allow(::Ai::Catalog::FoundationalFlow).to receive(:[]).with('code_review/v1').and_return(nil)
                create(:gitlab_subscription_add_on_purchase, :self_managed, add_on_factory)
              end

              it "returns false for #{params[:add_on_factory]}" do
                is_expected.to be_falsey
              end
            end
          end

          context 'when duo_foundational_flows_enabled is true' do
            before do
              namespace.namespace_settings.update!(duo_foundational_flows_enabled: true)
            end

            context 'when code_review flow is not enabled' do
              before do
                allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(namespace, :duo_workflow).and_return(true)
              end

              context 'when instance has duo_core add-on' do
                before do
                  create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_core)
                end

                it { is_expected.to be_falsey }
              end

              context 'when instance has self_hosted_dap add-on' do
                before do
                  create(:gitlab_subscription_add_on_purchase, :self_managed, :self_hosted_dap)
                end

                it { is_expected.to be_falsey }
              end
            end

            context 'when code_review flow is enabled' do
              before do
                create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace,
                  catalog_item: code_review_foundational_flow)
              end

              context 'when instance has duo_enterprise add-on' do
                before do
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(namespace,
                    :duo_workflow).and_return(true)
                  create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
                end

                it { is_expected.to be_truthy }
              end

              context 'when instance has expired duo_enterprise add-on' do
                before do
                  # An expired add-on without gitlab_credits means StageCheck returns false
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(namespace,
                    :duo_workflow).and_return(false)
                  create(:gitlab_subscription_add_on_purchase, :expired, :self_managed, add_on: duo_enterprise_add_on)
                end

                it { is_expected.to be_falsey }
              end

              context 'when StageCheck returns false' do
                before do
                  allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(namespace,
                    :duo_workflow).and_return(false)
                end

                context 'when instance has duo_core add-on' do
                  before do
                    create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_core)
                  end

                  it { is_expected.to be_falsey }
                end

                context 'when instance has self_hosted_dap add-on' do
                  before do
                    create(:gitlab_subscription_add_on_purchase, :self_managed, :self_hosted_dap)
                  end

                  it { is_expected.to be_falsey }
                end
              end

              context 'when StageCheck returns true' do
                where(:add_on_factory) do
                  [[:duo_pro], [:duo_core], [:self_hosted_dap]]
                end

                with_them do
                  before do
                    create(:gitlab_subscription_add_on_purchase, :self_managed, add_on_factory)
                    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(namespace,
                      :duo_workflow).and_return(true)
                  end

                  it "returns true for #{params[:add_on_factory]}" do
                    is_expected.to be_truthy
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe '#duo_beta_flows_enabled?' do
    let(:namespace) { build_stubbed(:namespace) }

    subject { namespace.duo_beta_flows_enabled? }

    where(:saas, :experiment_features_enabled, :instance_beta_enabled, :expected) do
      true  | true  | false | true
      false | false | true  | true
      true  | false | false | false
      false | false | false | false
    end

    with_them do
      before do
        stub_saas_features(gitlab_com_subscriptions: saas)
        stub_application_setting(instance_level_ai_beta_features_enabled: instance_beta_enabled)
        allow(namespace).to receive(:experiment_features_enabled).and_return(experiment_features_enabled)
      end

      it { is_expected.to be(expected) }
    end
  end

  describe '#foundational_flows_available?' do
    let_it_be_with_reload(:namespace) { create(:group) }

    let(:stage_check_available) { true }

    subject { namespace.foundational_flows_available? }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(namespace, :foundational_flows).and_return(stage_check_available)
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        namespace.namespace_settings.update!(duo_foundational_flows_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when duo_foundational_flows_enabled is true' do
      before do
        namespace.namespace_settings.update!(duo_foundational_flows_enabled: true)
      end

      context 'when StageCheck returns false' do
        let(:stage_check_available) { false }

        it { is_expected.to be(false) }
      end

      context 'when StageCheck returns true' do
        it { is_expected.to be(true) }
      end
    end
  end

  describe '#billable_members_count' do
    let(:user) { create(:user) }

    it 'returns 1' do
      expect(user.namespace.billable_members_count).to eq(1)
    end
  end

  describe '#eligible_for_trial?' do
    let_it_be_with_reload(:namespace) { create(:namespace, organization: organization) }

    subject { namespace.eligible_for_trial? }

    where(
      subscriptions_trials_enabled: [true, false],
      has_parent: [true, false],
      never_had_trial: [true, false],
      plan_eligible_for_trial: [true, false]
    )

    with_them do
      before do
        stub_saas_features(subscriptions_trials: subscriptions_trials_enabled)
        allow(namespace).to receive_messages(
          has_parent?: has_parent,
          never_had_trial?: never_had_trial,
          plan_eligible_for_trial?: plan_eligible_for_trial,
          eligible_for_retrial?: false
        )
      end

      it 'returns true only when all conditions are met' do
        is_expected
          .to eq(subscriptions_trials_enabled && !has_parent && never_had_trial && plan_eligible_for_trial)
      end
    end

    context 'when the namespace already trialed but is eligible for a re-trial' do
      before do
        stub_saas_features(subscriptions_trials: true)
        allow(namespace).to receive_messages(
          has_parent?: false,
          never_had_trial?: false,
          plan_eligible_for_trial?: true,
          eligible_for_retrial?: true
        )
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#eligible_for_retrial?', :saas_gitlab_com_subscriptions do
    let(:namespace) { build(:group, id: non_existing_record_id, gitlab_subscription: gitlab_subscription) }
    let(:gitlab_subscription) { build(:gitlab_subscription, :expired_trial, :free) }
    let(:customers_dot_eligible) { true }

    subject(:eligible_for_retrial) { namespace.eligible_for_retrial? }

    before do
      allow(::GitlabSubscriptions::Trials)
        .to receive(:namespace_add_on_eligible?).with(namespace).and_return(customers_dot_eligible)
    end

    context 'when the flag is enabled, the trial expired, and CustomersDot reports eligible' do
      it { is_expected.to be(true) }
    end

    context 'when CustomersDot reports the namespace is not eligible' do
      let(:customers_dot_eligible) { false }

      it { is_expected.to be(false) }
    end

    context 'when the saas_ultimate_retrial flag is disabled' do
      before do
        stub_feature_flags(saas_ultimate_retrial: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when the namespace has no expired trial' do
      let(:gitlab_subscription) { build(:gitlab_subscription, :active_trial, :free) }

      it { is_expected.to be(false) }
    end
  end

  describe '#plan_eligible_for_trial?', :saas do
    let(:namespace) { create(:namespace_with_plan, plan: plan) }

    subject { namespace.eligible_for_trial? }

    where(:plan, :eligible) do
      [
        [:ultimate_plan, false],
        [:premium_plan, true],
        [:free_plan, true],
        [:default_plan, true]
      ]
    end

    with_them do
      it "#{params[:plan]} is #{params[:eligible] && 'not'} eligible for trial" do
        is_expected.to eq(eligible)
      end
    end
  end

  describe '#trial_active?', :saas do
    let(:namespace) do
      build(:namespace,
        gitlab_subscription: build(:gitlab_subscription,
          trial: trial,
          trial_starts_on: trial_starts_on,
          trial_ends_on: trial_ends_on
        )
      )
    end

    where(:trial, :trial_starts_on, :trial_ends_on, :result) do
      false  | 60.days.ago  | Date.tomorrow | false
      true   | nil          | Date.tomorrow | false
      true   | 60.days.ago  | nil           | false
      true   | 60.days.ago  | Date.current  | false
      true   | 60.days.ago  | Date.tomorrow | true
    end

    subject { namespace.trial_active? }

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#trial_expired?', :saas do
    let(:namespace) do
      build(:namespace,
        gitlab_subscription: build(:gitlab_subscription, trial_ends_on: trial_ends_on)
      )
    end

    where(:trial_ends_on, :result) do
      nil           | false
      Date.tomorrow | false
      Date.current  | true
    end

    subject { namespace.trial_expired? }

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#checked_file_template_project' do
    it 'is always nil for non-group namespaces' do
      expect(namespace.checked_file_template_project).to be_nil
    end
  end

  describe '#checked_file_template_project_id' do
    it 'is always nil for non-group namespaces' do
      expect(namespace.checked_file_template_project_id).to be_nil
    end
  end

  describe '#store_security_reports_available?' do
    let_it_be(:namespace) { create(:namespace, organization: organization) }

    subject { namespace.store_security_reports_available? }

    context 'when at least one security report feature is enabled' do
      where(report_type: [:sast, :secret_detection, :dast, :dependency_scanning, :container_scanning,
        :cluster_image_scanning])

      with_them do
        before do
          stub_licensed_features(report_type => true)
        end

        it { is_expected.to be true }
      end
    end

    context 'when no security report feature is available' do
      before do
        security_features = [
          :sast, :secret_detection, :dast, :dependency_scanning, :container_scanning,
          :cluster_image_scanning, :coverage_fuzzing, :api_fuzzing
        ]

        stub_licensed_features(security_features.index_with { false })
      end

      it { is_expected.to be false }
    end
  end

  describe '#ingest_sbom_reports_available?' do
    let_it_be(:namespace) { create(:namespace, organization: organization) }

    subject { namespace.ingest_sbom_reports_available? }

    context 'when at least one sbom-related feature is available' do
      where(:feature) { [:container_scanning, :dependency_scanning, :license_scanning] }

      before do
        stub_licensed_features(feature => true)
      end

      with_them do
        it { is_expected.to be true }
      end
    end

    context 'when sbom-related features are not available' do
      it { is_expected.to be false }
    end
  end

  describe '#over_storage_limit?', :saas do
    let_it_be(:namespace) { create(:namespace_with_plan, plan: :ultimate_plan) }

    before_all do
      create(:namespace_root_storage_statistics, namespace: namespace)
    end

    before do
      enforce_namespace_storage_limit(namespace)
      set_enforcement_limit(namespace, megabytes: 10)
    end

    it 'returns true if the namespace is over the storage limit', :saas do
      set_used_storage(namespace, megabytes: 11)

      expect(namespace.over_storage_limit?).to be(true)
    end

    it 'returns false if the namespace storage equals the limit', :saas do
      set_used_storage(namespace, megabytes: 10)

      expect(namespace.over_storage_limit?).to be(false)
    end

    it 'returns false if the namespace is under the storage limit', :saas do
      set_used_storage(namespace, megabytes: 9)

      expect(namespace.over_storage_limit?).to be(false)
    end
  end

  describe '#read_only?' do
    let(:namespace) { build(:namespace) }

    where(:over_storage_limit, :over_free_user_limit, :result) do
      true  | true  | true
      true  | false | true
      false | true  | true
      false | false | false
    end

    subject { namespace.read_only? }

    with_them do
      before do
        allow(namespace).to receive(:over_storage_limit?).and_return(over_storage_limit)
        allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, namespace) do |instance|
          allow(instance).to receive(:over_limit?).and_return(over_free_user_limit)
        end
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#total_repository_size_excess', feature_category: :consumables_cost_management do
    let_it_be(:namespace) { create(:namespace) }

    before do
      namespace.clear_memoization(:total_repository_size_excess)
    end

    context 'with projects having a variety of repository sizes and limits' do
      before_all do
        create_storage_excess_example_projects
      end

      context 'when namespace-level repository_size_limit is not set' do
        it 'returns the total excess size of projects with repositories that exceed the size limit' do
          allow(namespace).to receive(:actual_repository_size_limit).and_return(nil)

          expect(namespace.total_repository_size_excess).to eq(400)
        end
      end

      context 'when namespace-level repository_size_limit is 0 (unlimited)' do
        it 'returns the total excess size of projects with repositories that exceed the size limit' do
          allow(namespace).to receive(:actual_repository_size_limit).and_return(0)

          expect(namespace.total_repository_size_excess).to eq(400)
        end
      end

      context 'when namespace-level repository_size_limit is a positive number' do
        it 'returns the total excess size of projects with repositories that exceed the size limit' do
          allow(namespace).to receive(:actual_repository_size_limit).and_return(150)

          expect(namespace.total_repository_size_excess).to eq(560)
        end
      end
    end

    context 'when all projects have repository_size_limit of 0 (unlimited)' do
      before do
        create_project(repository_size: 100, lfs_objects_size: 0, repository_size_limit: 0)
        create_project(repository_size: 150, lfs_objects_size: 0, repository_size_limit: 0)
        create_project(repository_size: 200, lfs_objects_size: 100, repository_size_limit: 0)

        allow(namespace).to receive(:actual_repository_size_limit).and_return(150)
      end

      it 'returns zero regardless of the namespace or instance-level repository_size_limit' do
        expect(namespace.total_repository_size_excess).to eq(0)
      end
    end
  end

  describe '#repository_size_excess_project_count', feature_category: :consumables_cost_management do
    let_it_be(:namespace) { create(:namespace) }

    before do
      namespace.clear_memoization(:repository_size_excess_project_count)
    end

    context 'with projects having a variety of repository sizes and limits' do
      before_all do
        create_storage_excess_example_projects
      end

      context 'when namespace-level repository_size_limit is not set' do
        before do
          allow(namespace).to receive(:actual_repository_size_limit).and_return(nil)
        end

        it 'returns the count of projects with repositories that exceed the size limit' do
          expect(namespace.repository_size_excess_project_count).to eq(2)
        end
      end

      context 'when namespace-level repository_size_limit is 0 (unlimited)' do
        before do
          allow(namespace).to receive(:actual_repository_size_limit).and_return(0)
        end

        it 'returns the count of projects with repositories that exceed the size limit' do
          expect(namespace.repository_size_excess_project_count).to eq(2)
        end
      end

      context 'when namespace-level repository_size_limit is a positive number' do
        before do
          allow(namespace).to receive(:actual_repository_size_limit).and_return(150)
        end

        it 'returns the count of projects with repositories that exceed the size limit' do
          expect(namespace.repository_size_excess_project_count).to eq(4)
        end
      end
    end

    context 'when all projects have repository_size_limit of 0 (unlimited)' do
      before do
        create_project(repository_size: 100, lfs_objects_size: 0, repository_size_limit: 0)
        create_project(repository_size: 150, lfs_objects_size: 0, repository_size_limit: 0)
        create_project(repository_size: 200, lfs_objects_size: 100, repository_size_limit: 0)

        allow(namespace).to receive(:actual_repository_size_limit).and_return(150)
      end

      it 'returns zero regardless of the namespace or instance-level repository_size_limit' do
        expect(namespace.repository_size_excess_project_count).to eq(0)
      end
    end
  end

  describe '#projects_with_repository_size_limit_usage_ratio_greater_than' do
    let(:instance_limit) { 10.gigabytes }
    let_it_be_with_refind(:namespace) { create(:namespace) }
    let_it_be_with_refind(:project_1) { create_project(repository_size: 18.gigabytes) }
    let_it_be_with_refind(:project_2) { create_project(repository_size: 12.gigabytes) }

    before do
      stub_ee_application_setting(repository_size_limit: instance_limit)
    end

    it 'returns both projects for ratio: 1' do
      expect(namespace.projects_with_repository_size_limit_usage_ratio_greater_than(ratio: 1))
        .to match_array([project_1, project_2])
    end

    context 'when one of the projects has a bigger limit' do
      before do
        project_1.update!(repository_size_limit: 20.gigabytes)
      end

      it 'returns only one project for ratio: 1' do
        expect(namespace.projects_with_repository_size_limit_usage_ratio_greater_than(ratio: 1))
          .to match_array([project_2])
      end

      it 'returns both projects for ratio: 0.8' do
        expect(namespace.projects_with_repository_size_limit_usage_ratio_greater_than(ratio: 0.8))
        .to match_array([project_1, project_2])
      end
    end

    context 'when one of the projects has no limit' do
      before do
        project_1.update!(repository_size_limit: 0)
      end

      it 'returns only one project for ratio: 1' do
        expect(namespace.projects_with_repository_size_limit_usage_ratio_greater_than(ratio: 1))
          .to match_array([project_2])
      end

      it 'returns only one project for ratio: 0.8' do
        expect(namespace.projects_with_repository_size_limit_usage_ratio_greater_than(ratio: 0.8))
        .to match_array([project_2])
      end
    end

    context 'when namespace has a limit bigger than the instance' do
      before do
        namespace.update!(repository_size_limit: 15.gigabytes)
      end

      it 'returns only one project for ratio: 1' do
        expect(namespace.projects_with_repository_size_limit_usage_ratio_greater_than(ratio: 1))
        .to match_array([project_1])
      end

      it 'returns both projects for ratio: 0.1' do
        expect(namespace.projects_with_repository_size_limit_usage_ratio_greater_than(ratio: 0.1))
        .to match_array([project_1, project_2])
      end
    end
  end

  describe '#total_repository_size', feature_category: :consumables_cost_management do
    let(:namespace) { create(:namespace) }

    before do
      create_project(repository_size: 100, lfs_objects_size: 0, repository_size_limit: nil)
      create_project(repository_size: 150, lfs_objects_size: 100, repository_size_limit: 0)
      create_project(repository_size: 325, lfs_objects_size: 200, repository_size_limit: 400)
    end

    it 'returns the total size of all project repositories' do
      expect(namespace.total_repository_size).to eq(875)
    end
  end

  describe '#additional_purchased_storage_size', feature_category: :consumables_cost_management do
    it 'calls namespace_limit#eligible_additional_purchased_storage_size' do
      expect(namespace.namespace_limit).to receive(:eligible_additional_purchased_storage_size)
      namespace.additional_purchased_storage_size
    end
  end

  describe '#contains_locked_projects?', feature_category: :consumables_cost_management do
    let_it_be(:namespace) { create(:namespace) }

    before_all do
      create(:namespace_limit, namespace: namespace, additional_purchased_storage_size: 10)
    end

    where(:total_excess, :result) do
      5.megabytes  | false
      10.megabytes | false
      15.megabytes | true
    end

    with_them do
      before do
        allow(namespace).to receive(:total_repository_size_excess).and_return(total_excess)
      end

      it 'returns a boolean indicating whether the root namespace contains locked projects' do
        expect(namespace.contains_locked_projects?).to be result
      end
    end
  end

  describe '#actual_repository_size_limit', feature_category: :consumables_cost_management do
    let(:repository_size_limit) { 1000 }
    let(:namespace) { build(:namespace) }

    before do
      stub_ee_application_setting(repository_size_limit: repository_size_limit)
    end

    context 'when repository_size_limit is set on the namespace' do
      it 'returns the local repository_size_limit' do
        namespace.update_attribute(:repository_size_limit, 75)

        expect(namespace.actual_repository_size_limit).to eq(75)
      end
    end

    context 'when repository_size_limit is not set on the namespace' do
      it 'returns the global repository_size_limit' do
        expect(namespace.actual_repository_size_limit).to eq(repository_size_limit)
      end
    end

    context 'with repository_size_limit set in plans_limits' do
      before do
        namespace.actual_plan.actual_limits.update!(repository_size: 500)
      end

      context 'when not in gitlab.com' do
        it 'returns the global repository_size_limit' do
          expect(namespace.actual_repository_size_limit).to eq(1000)
        end
      end

      context 'when in gitlab.com', :saas do
        it 'returns plan limit' do
          expect(namespace.actual_repository_size_limit).to eq(500)
        end

        it 'returns the value set locally, overriding the plan limit' do
          namespace.update_attribute(:repository_size_limit, 75)

          expect(namespace.actual_size_limit).to eq(75)
        end
      end
    end
  end

  describe '#actual_size_limit', feature_category: :consumables_cost_management do
    context 'when in repository enforcement' do
      let(:namespace) { build(:namespace) }
      let(:repository_size_limit) { 1000 }

      before do
        stub_ee_application_setting(repository_size_limit: repository_size_limit)
      end

      it 'returns the global repository_size_limit' do
        expect(namespace.actual_size_limit).to eq(repository_size_limit)
      end

      context 'with repository_size_limit set in plans_limits' do
        before do
          namespace.actual_plan.actual_limits.update!(repository_size: 500)
        end

        context 'when not in gitlab.com' do
          it 'returns the global repository_size_limit' do
            expect(namespace.actual_size_limit).to eq(repository_size_limit)
          end

          it 'returns the value set locally, overriding the global limit' do
            namespace.update_attribute(:repository_size_limit, 75)

            expect(namespace.actual_size_limit).to eq(75)
          end
        end

        context 'when in gitlab.com', :saas do
          it 'returns plan limit' do
            expect(namespace.actual_size_limit).to eq(500)
          end

          it 'returns the value set locally, overriding the plan limit' do
            namespace.update_attribute(:repository_size_limit, 75)

            expect(namespace.actual_size_limit).to eq(75)
          end
        end
      end

      it 'returns the value set locally' do
        namespace.update_attribute(:repository_size_limit, 75)

        expect(namespace.actual_size_limit).to eq(75)
      end
    end

    context 'when in namespace enforcement', :saas do
      let(:namespace) { build(:namespace, gitlab_subscription: build(:gitlab_subscription)) }
      let(:enforceable_storage_limit) { 500 }

      before do
        enforce_namespace_storage_limit(namespace)
        set_enforcement_limit(namespace, megabytes: enforceable_storage_limit)
      end

      it 'returns the plan limit' do
        expect(namespace.actual_size_limit).to eq(enforceable_storage_limit.megabytes)
      end
    end
  end

  describe '#membership_lock with subgroups' do
    context 'when creating a subgroup' do
      let(:subgroup) { create(:group, parent: root_group) }

      context 'when under a parent with "Membership lock" enabled' do
        let(:root_group) { create(:group, membership_lock: true) }

        it 'enables "Membership lock" on the subgroup' do
          expect(subgroup.membership_lock).to be_truthy
        end
      end

      context 'when under a parent with "Membership lock" disabled' do
        let(:root_group) { create(:group) }

        it 'does not enable "Membership lock" on the subgroup' do
          expect(subgroup.membership_lock).to be_falsey
        end
      end

      context 'when enabling the parent group "Membership lock"' do
        let(:root_group) { create(:group) }
        let!(:subgroup) { create(:group, parent: root_group) }

        it 'the subgroup "Membership lock" not changed' do
          root_group.update!(membership_lock: true)

          expect(subgroup.reload.membership_lock).to be_falsey
        end
      end

      context 'when disabling the parent group "Membership lock" (which was already enabled)' do
        let(:root_group) { create(:group, membership_lock: true) }

        context 'and the subgroup "Membership lock" is enabled' do
          let(:subgroup) { create(:group, parent: root_group, membership_lock: true) }

          it 'the subgroup "Membership lock" does not change' do
            root_group.update!(membership_lock: false)

            expect(subgroup.reload.membership_lock).to be_truthy
          end
        end

        context 'when the subgroup "Membership lock" is disabled' do
          let(:subgroup) { create(:group, parent: root_group) }

          it 'the subgroup "Membership lock" does not change' do
            root_group.update!(membership_lock: false)

            expect(subgroup.reload.membership_lock?).to be_falsey
          end
        end
      end
    end

    # Note: Group transfers are not yet implemented
    context 'when a group is transferred into a root group' do
      context 'when the root group "Membership lock" is enabled' do
        let(:root_group) { create(:group, membership_lock: true, organization: organization) }

        context 'when the subgroup "Membership lock" is enabled' do
          let(:subgroup) { create(:group, membership_lock: true, organization: organization) }

          it 'the subgroup "Membership lock" does not change' do
            subgroup.parent = root_group
            subgroup.save!

            expect(subgroup.membership_lock).to be_truthy
          end
        end

        context 'when the subgroup "Membership lock" is disabled' do
          let(:subgroup) { create(:group, organization: organization) }

          it 'the subgroup "Membership lock" not changed' do
            subgroup.parent = root_group
            subgroup.save!

            expect(subgroup.membership_lock).to be_falsey
          end
        end
      end

      context 'when the root group "Membership lock" is disabled' do
        let(:root_group) { create(:group, organization: organization) }

        context 'when the subgroup "Membership lock" is enabled' do
          let(:subgroup) { create(:group, membership_lock: true, organization: organization) }

          it 'the subgroup "Membership lock" does not change' do
            subgroup.parent = root_group
            subgroup.save!

            expect(subgroup.membership_lock).to be_truthy
          end
        end

        context 'when the subgroup "Membership lock" is disabled' do
          let(:subgroup) { create(:group, organization: organization) }

          it 'the subgroup "Membership lock" does not change' do
            subgroup.parent = root_group
            subgroup.save!

            expect(subgroup.membership_lock).to be_falsey
          end
        end
      end
    end
  end

  describe '#namespace_limit', feature_category: :consumables_cost_management do
    let_it_be(:parent) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: parent) }

    context 'when there is a parent namespace' do
      subject(:namespace_limit) { subgroup.namespace_limit }

      context 'with a namespace limit' do
        it 'returns the parent namespace limit' do
          parent_limit = create(:namespace_limit, namespace: parent)

          expect(namespace_limit).to eq parent_limit
          expect(namespace_limit).to be_persisted
        end
      end

      context 'with no namespace limit' do
        it 'builds namespace limit' do
          parent.namespace_limit.destroy!

          expect(namespace_limit).to be_present
          expect(namespace_limit).not_to be_persisted
        end
      end
    end

    context 'when there is no parent ancestor' do
      context 'for personal namespaces' do
        let_it_be(:namespace) { create(:namespace) }

        subject(:namespace_limit) { namespace.namespace_limit }

        context 'with a namespace limit' do
          it 'returns the namespace limit' do
            limit = create(:namespace_limit, namespace: namespace)

            expect(namespace_limit).to be_persisted
            expect(namespace_limit).to eq limit
          end
        end

        context 'with no namespace limit' do
          it 'builds namespace limit' do
            namespace.namespace_limit.destroy!

            expect(namespace_limit).to be_present
            expect(namespace_limit).not_to be_persisted
          end
        end
      end

      context 'for groups' do
        subject(:namespace_limit) { parent.namespace_limit }

        context 'with a namespace limit' do
          it 'returns the namespace limit' do
            limit = create(:namespace_limit, namespace: parent)

            expect(namespace_limit).to be_persisted
            expect(namespace_limit).to eq limit
          end
        end

        context 'with no namespace limit' do
          it 'builds namespace limit' do
            parent.namespace_limit.destroy!

            expect(namespace_limit).to be_present
            expect(namespace_limit).not_to be_persisted
          end
        end
      end
    end
  end

  describe '#root_storage_size', :saas do
    let_it_be(:namespace) { create(:namespace_with_plan, plan: :free_plan) }

    subject(:root_storage_size) { namespace.root_storage_size }

    context 'when namespace storage limits are enabled' do
      before do
        enforce_namespace_storage_limit(namespace)
      end

      it 'returns an instance of RootSize' do
        expect(root_storage_size).to be_an_instance_of(::Namespaces::Storage::RootSize)
      end
    end

    context 'when namespace storage limits are disabled' do
      before do
        stub_application_setting(enforce_namespace_storage_limit: false)
        stub_application_setting(automatic_purchased_storage_allocation: false)
        stub_feature_flags(namespace_storage_limit: false)
      end

      it 'returns an instance of Namespaces::Storage::RepositoryLimit::Enforcement' do
        expect(root_storage_size).to be_an_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement)
      end
    end

    context 'when namespace storage limits are disabled and automatic_purchased_storage_allocation is enabled' do
      before do
        stub_application_setting(enforce_namespace_storage_limit: false)
        stub_application_setting(automatic_purchased_storage_allocation: true)
        stub_feature_flags(namespace_storage_limit: false)
      end

      it 'returns an instance of Namespaces::Storage::RepositoryLimit::Enforcement' do
        expect(root_storage_size).to be_an_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement)
      end
    end

    context 'when namespace storage limits are enabled for free namespaces and disabled for paid' do
      before do
        set_enforcement_limit(namespace, megabytes: 100)
        enforce_namespace_storage_limit(namespace)
      end

      it 'returns an instance of RootSize for a free namespace' do
        expect(root_storage_size).to be_an_instance_of(::Namespaces::Storage::RootSize)
      end

      it 'returns an instance of Namespaces::Storage::RepositoryLimit::Enforcement for a paid namespace' do
        paid_namespace = create(:namespace_with_plan, plan: :ultimate_plan)

        expect(paid_namespace.root_storage_size)
          .to be_an_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement)
      end
    end
  end

  describe 'seat_control_available?' do
    let_it_be(:namespace) { create(:group) }

    subject(:seat_control_available?) { namespace.seat_control_available? }

    where(:user_cap, :block_overages, :expected) do
      true  | true  | true
      true  | false | true
      false | true  | true
      false | false | false
    end

    with_them do
      before do
        allow(namespace).to receive_messages(user_cap_available?: user_cap, block_overages_available?: block_overages)
      end

      it { is_expected.to be expected }
    end
  end

  describe '#user_cap_available?' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:subgroup) {  create(:group, parent: namespace) }

    let(:gitlab_com_subscriptions_enabled) { true }

    subject(:user_cap_available?) { namespace.user_cap_available? }

    before do
      stub_saas_features(gitlab_com_subscriptions: gitlab_com_subscriptions_enabled)
    end

    context 'when not on Gitlab.com' do
      let(:gitlab_com_subscriptions_enabled) { false }

      it { is_expected.to be false }
    end

    context 'when the namespace is not a group' do
      let(:user) { create(:user) }
      let(:namespace) { user.namespace }

      it { is_expected.to be false }
    end
  end

  describe '#block_overages_available?', :saas do
    let_it_be(:namespace) { create(:group) }

    let(:end_date) { 5.days.from_now }

    subject(:block_overages_available?) { namespace.block_overages_available? }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)

      create(:gitlab_subscription, namespace: namespace, hosted_plan: ultimate_plan, end_date: end_date)
    end

    context 'when not on Gitlab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it { is_expected.to be false }
    end

    context 'when the namespace is not a group' do
      let(:user) { create(:user) }
      let(:namespace) { user.namespace }

      it { is_expected.to be false }
    end

    context 'with no subscription' do
      before do
        allow(namespace).to receive(:gitlab_subscription).and_return(nil)
      end

      it { is_expected.to be false }
    end

    context 'without a paid plan' do
      before do
        allow(namespace.gitlab_subscription).to receive(:has_a_paid_hosted_plan?).and_return(false)
      end

      it { is_expected.to be false }
    end

    context 'with an expired subscription' do
      let(:end_date) { 1.day.ago }

      it { is_expected.to be false }
    end

    it { is_expected.to be true }
  end

  describe '#capacity_left_for_user?' do
    let(:namespace) { build(:namespace) }

    subject { namespace.capacity_left_for_user?(anything) }

    it { is_expected.to be(true) }
  end

  describe '#exclude_guests?' do
    let(:namespace) { build(:namespace) }

    it 'returns false' do
      expect(namespace.exclude_guests?).to be(false)
    end
  end

  describe '#designated_as_csp?' do
    include Security::PolicyCspHelpers

    subject { group.designated_as_csp? }

    let(:group) { create(:group) }

    it { is_expected.to be(false) }

    context 'when the group is designated as a CSP group' do
      before do
        stub_csp_group(group)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#all_projects_with_csp_in_batches' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:group_project) { create(:project, group: group) }
    let_it_be(:subgroup_project) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }
    let_it_be(:archived_project) { create(:project, :archived, group: group) }
    let_it_be(:project_marked_for_deletion) { create(:project, group: group, marked_for_deletion_at: Time.zone.now) }

    def yielded_projects(group, **args)
      results = []
      group.all_projects_with_csp_in_batches(**args) { |projects| results += projects }

      results
    end

    it 'yields all projects' do
      expect(yielded_projects(group))
        .to contain_exactly(group_project, subgroup_project, archived_project, project_marked_for_deletion)
    end

    context 'with only_active: true' do
      it 'yields only active projects' do
        expect(yielded_projects(group, only_active: true)).to contain_exactly(group_project, subgroup_project)
      end
    end

    context 'when used for a CSP group' do
      include_context 'with csp group configuration'

      it 'yields all projects' do
        expect(yielded_projects(csp_group))
          .to contain_exactly(group_project, subgroup_project, other_project, csp_policy_project,
            archived_project, project_marked_for_deletion)
      end

      context 'with only_active: true' do
        it 'yields only active projects' do
          expect(yielded_projects(csp_group, only_active: true))
            .to contain_exactly(group_project, subgroup_project, other_project, csp_policy_project)
        end
      end
    end
  end

  describe '#organization_csp_namespace' do
    include Security::PolicyCspHelpers

    subject { group.organization_csp_namespace }

    let(:group) { create(:group) }

    it { is_expected.to be_nil }

    context 'when the group is designated as a CSP group' do
      before do
        stub_csp_group(group)
      end

      it { is_expected.to eq(group) }
    end
  end

  describe '#all_project_ids_with_csp_in_batches' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:group_project) { create(:project, group: group) }
    let_it_be(:subgroup_project) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    def yielded_projects(group)
      results = []
      group.all_project_ids_with_csp_in_batches { |projects| results += projects }

      results
    end

    it 'yields projects' do
      expect(yielded_projects(group)).to contain_exactly(group_project, subgroup_project)
    end

    context 'when used for a CSP group' do
      include_context 'with csp group configuration'

      it 'yields projects' do
        expect(yielded_projects(csp_group))
          .to contain_exactly(group_project, subgroup_project, other_project, csp_policy_project)
      end
    end
  end

  describe '#self_ancestor_ids_with_csp' do
    subject { subgroup.self_and_ancestor_ids_with_csp }

    let_it_be(:group) { create(:group) }
    let_it_be_with_refind(:subgroup) { create(:group, parent: group) }
    let_it_be(:sub_subgroup) { create(:group, parent: subgroup) }

    it { is_expected.to match([subgroup.id, group.id]) }

    context 'with a CSP group' do
      include_context 'with csp group configuration'

      it { is_expected.to match([subgroup.id, group.id, csp_group.id]) }
    end
  end

  describe '#ancestor_ids_with_csp' do
    subject { subgroup.ancestor_ids_with_csp }

    let_it_be(:group) { create(:group) }
    let_it_be_with_refind(:subgroup) { create(:group, parent: group) }
    let_it_be(:sub_subgroup) { create(:group, parent: subgroup) }

    it { is_expected.to contain_exactly(group.id) }

    context 'with a CSP group' do
      include_context 'with csp group configuration'

      it { is_expected.to match([group.id, csp_group.id]) }
    end
  end

  describe '#all_security_orchestration_policy_configurations' do
    subject(:configurations) { child_group_2.all_security_orchestration_policy_configurations }

    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: parent_group) }
    let_it_be_with_refind(:child_group_2) { create(:group, parent: child_group) }

    let_it_be(:parent_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: parent_group)
    end

    let_it_be(:child_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: child_group_2)
    end

    context 'when configuration is invalid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 2) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(false)
        end
      end

      it 'returns empty list' do
        expect(configurations).to be_empty
      end

      context 'when including invalid configurations' do
        subject { child_group_2.all_security_orchestration_policy_configurations(include_invalid: true) }

        it 'returns all configurations including invalid ones' do
          is_expected.to contain_exactly(parent_security_orchestration_policy_configuration,
            child_security_orchestration_policy_configuration)
        end
      end
    end

    context 'when configuration is valid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 3) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      it 'returns security policy configurations for all valid parent groups' do
        expect(configurations).to match_array(
          [
            parent_security_orchestration_policy_configuration,
            child_security_orchestration_policy_configuration
          ]
        )
      end

      context 'with a designated CSP group' do
        include_context 'with csp group configuration'

        it 'returns security policy configurations including the CSP configuration' do
          expect(configurations).to match_array(
            [
              csp_security_orchestration_policy_configuration,
              parent_security_orchestration_policy_configuration,
              child_security_orchestration_policy_configuration
            ]
          )
        end
      end
    end
  end

  describe '#all_inherited_security_orchestration_policy_configurations' do
    subject(:configurations) { child_group_2.all_inherited_security_orchestration_policy_configurations }

    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: parent_group) }
    let_it_be_with_refind(:child_group_2) { create(:group, parent: child_group) }

    let_it_be(:parent_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: parent_group)
    end

    let_it_be(:child_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: child_group_2)
    end

    context 'when there is no configuration for group ancestors' do
      subject(:configurations) { parent_group.all_inherited_security_orchestration_policy_configurations }

      it 'returns empty list' do
        expect(configurations).to be_empty
      end
    end

    context 'when configuration is invalid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 2) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(false)
        end
      end

      it 'returns empty list' do
        expect(configurations).to be_empty
      end
    end

    context 'when configuration is valid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 3) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      it 'returns security policy configurations for all valid parent groups' do
        expect(configurations).to match_array(
          [
            parent_security_orchestration_policy_configuration
          ]
        )
      end

      context 'with a designated CSP group' do
        include_context 'with csp group configuration'

        it 'returns security policy configurations including the CSP configuration' do
          expect(configurations).to match_array(
            [
              csp_security_orchestration_policy_configuration,
              parent_security_orchestration_policy_configuration
            ]
          )
        end
      end
    end
  end

  describe '#all_descendant_security_orchestration_policy_configurations' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: parent_group) }
    let_it_be(:child_group_2) { create(:group, parent: child_group) }
    let_it_be(:child_group_project) { create(:project, group: child_group) }

    let_it_be(:parent_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: parent_group)
    end

    let_it_be(:child_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: child_group_2)
    end

    let_it_be(:child_project_security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, project: child_group_project)
    end

    let_it_be(:include_invalid) { false }

    subject do
      parent_group.all_descendant_security_orchestration_policy_configurations(include_invalid: include_invalid)
    end

    context 'when configuration is invalid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 3) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(false)
        end
      end

      it 'returns empty list' do
        is_expected.to be_empty
      end

      context 'when including invalid configurations' do
        let_it_be(:include_invalid) { true }

        it 'returns all configurations including invalid ones' do
          is_expected.to contain_exactly(
            parent_security_orchestration_policy_configuration,
            child_security_orchestration_policy_configuration,
            child_project_security_orchestration_policy_configuration
          )
        end
      end
    end

    context 'when configuration is valid' do
      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 3) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      it 'returns valid security policy configurations for all parent groups' do
        is_expected.to match_array(
          [parent_security_orchestration_policy_configuration, child_security_orchestration_policy_configuration,
            child_project_security_orchestration_policy_configuration]
        )
      end
    end
  end

  describe '#all_projects_pages_domains' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: namespace) }
    let_it_be(:project1) { create(:project, group: namespace) }
    let_it_be(:project2) { create(:project, group: subgroup) }

    let_it_be(:verified_domain) { create(:pages_domain, project: project1) }
    let_it_be(:unverified_domain) { create(:pages_domain, :unverified, project: project2) }

    it 'finds all pages domains by default' do
      expect(namespace.all_projects_pages_domains).to match_array([verified_domain, unverified_domain])
    end

    it 'finds only verified domains when param is true' do
      expect(namespace.all_projects_pages_domains(only_verified: true)).to match_array(verified_domain)
    end

    context 'when projects are outside the top-level group hierarchy' do
      before do
        outside_namespace = create(:group)
        outside_project = create(:project, group: outside_namespace)
        create(:pages_domain, project: outside_project)
      end

      it 'does not include the outside domain' do
        expect(namespace.all_projects_pages_domains).to match_array([verified_domain, unverified_domain])
      end
    end
  end

  describe '#domain_verification_available?' do
    let_it_be(:namespace) { create(:group) }

    context 'when the feature is not licensed' do
      before do
        stub_licensed_features(domain_verification: false)
      end

      it 'is not available' do
        expect(namespace.domain_verification_available?).to be(false)
      end

      context 'on GitLab.com', :saas do
        it 'is not available' do
          expect(namespace.domain_verification_available?).to be(false)
        end
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(domain_verification: true)
      end

      it 'is not available' do
        expect(namespace.domain_verification_available?).to be(false)
      end

      context 'on GitLab.com', :saas do
        it 'is available' do
          expect(namespace.domain_verification_available?).to be(true)
        end

        context 'with a subgroup' do
          let(:subgroup) { create(:group, :nested) }

          it 'is not available' do
            expect(subgroup.domain_verification_available?).to be(false)
          end
        end
      end
    end
  end

  describe '#any_enterprise_users?' do
    let_it_be(:group) { create(:group) }

    subject { group.any_enterprise_users? }

    before do
      stub_licensed_features(domain_verification: true)
      allow(::Gitlab).to receive(:com?).and_return(true)
    end

    context 'when there are enterprise users for the group' do
      let_it_be(:enterprise_user) { create(:user, enterprise_group: group) }

      it { is_expected.to be(true) }

      context 'when domain_verification_available? is false' do
        before do
          stub_licensed_features(domain_verification: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when there are enterprise users for another group' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:enterprise_user) { create(:user, enterprise_group: other_group) }

      it { is_expected.to be(false) }
    end

    context 'when there are no enterprise users' do
      it { is_expected.to be(false) }
    end
  end

  describe '#enforce_ssh_certificates?' do
    let(:namespace) { create(:group) }

    before do
      namespace.enforce_ssh_certificates = true
    end

    it 'delegates the field to namespace settings' do
      expect(namespace.namespace_settings).to receive(:enforce_ssh_certificates?).and_call_original

      expect(namespace.enforce_ssh_certificates?).to be(true)
    end

    context 'with a subgroup' do
      let(:namespace) { create(:group, :nested) }

      it 'returns false' do
        expect(namespace.enforce_ssh_certificates?).to be(false)
      end
    end
  end

  describe '#ssh_certificates_available?' do
    let_it_be(:namespace) { create(:group) }

    context 'when the feature is not licensed' do
      before do
        stub_licensed_features(ssh_certificates: false)
      end

      it 'is not available' do
        expect(namespace.ssh_certificates_available?).to be(false)
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(ssh_certificates: true)
      end

      it 'is available' do
        expect(namespace.ssh_certificates_available?).to be(true)
      end

      context 'with a subgroup' do
        let(:subgroup) { create(:group, :nested) }

        it 'is not available' do
          expect(subgroup.ssh_certificates_available?).to be(false)
        end
      end
    end
  end

  describe '#custom_roles_enabled?', feature_category: :permissions do
    let_it_be(:namespace) { create(:group) }

    let(:licensed_feature_available) { true }

    before do
      stub_licensed_features(custom_roles: licensed_feature_available)
    end

    subject { namespace.custom_roles_enabled? }

    it { is_expected.to be true }

    context 'when licensed feature is not available' do
      let(:licensed_feature_available) { false }

      it { is_expected.to be false }
    end

    context 'when sub-group' do
      let(:subgroup) { create(:group, parent: namespace) }

      subject { subgroup.custom_roles_enabled? }

      it { is_expected.to be true }
    end
  end

  describe '#should_process_custom_roles?', feature_category: :system_access do
    let_it_be_with_refind(:namespace) { create(:group) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    subject { namespace.should_process_custom_roles? }

    it { is_expected.to be true }

    context 'when licensed feature is not available' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it { is_expected.to be false }
    end

    context 'when on SaaS', :saas do
      context 'when namespace does not have a custom role' do
        it { is_expected.to be false }
      end

      context 'when namespace has a custom role' do
        before_all do
          create(:member_role, namespace: namespace)
        end

        it { is_expected.to be true }

        context 'when namespace is a sub-group' do
          let(:subgroup) { create(:group, parent: namespace) }

          it 'returns true' do
            expect(subgroup.should_process_custom_roles?).to be true
          end
        end
      end
    end
  end

  describe '#allow_stale_runner_pruning?' do
    subject { namespace.allow_stale_runner_pruning? }

    let(:ci_cd_settings) { ::NamespaceCiCdSetting.find_or_initialize_by(namespace_id: namespace.id) }

    it { is_expected.to be false }

    context 'with ci_cd_setting.allow_stale_runner_pruning set to false' do
      before do
        ci_cd_settings.update!(allow_stale_runner_pruning: false)
      end

      it { is_expected.to be false }
    end

    context 'with ci_cd_setting.allow_stale_runner_pruning set to true' do
      before do
        ci_cd_settings.update!(allow_stale_runner_pruning: true)
      end

      it { is_expected.to be true }
    end
  end

  describe '#allow_stale_runner_pruning=' do
    context 'with no existing ci_cd_setting association' do
      context 'when value is set to false' do
        it 'does not build new association' do
          namespace.update!(allow_stale_runner_pruning: false)
          namespace.reload

          expect(namespace.ci_cd_settings).to be_nil
        end
      end

      context 'when value is set to true' do
        it 'builds association' do
          namespace.update!(allow_stale_runner_pruning: true)
          namespace.reload

          expect(namespace.ci_cd_settings).not_to be_nil
          expect(namespace.ci_cd_settings.allow_stale_runner_pruning?).to be true
        end
      end
    end

    context 'with existing ci_cd_setting association' do
      let(:ci_cd_settings) do
        ::NamespaceCiCdSetting.find_or_initialize_by(namespace_id: namespace.id, allow_stale_runner_pruning: false)
      end

      context 'when value is set to true' do
        it 'updates association' do
          namespace.update!(allow_stale_runner_pruning: true)
          namespace.reload

          expect(namespace.ci_cd_settings.allow_stale_runner_pruning?).to be true
        end
      end
    end
  end

  describe '#reached_project_access_token_limit?' do
    it 'returns false' do
      expect(namespace.reached_project_access_token_limit?).to be(false)
    end
  end

  describe '#block_seat_overages?' do
    it 'returns false' do
      expect(namespace.block_seat_overages?).to be(false)
    end
  end

  describe '#duo_core_features_enabled?' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }

    subject(:result) { group.duo_core_features_enabled? }

    it { is_expected.to be(false) }

    context 'when namespace_settings has duo_core_features enabled' do
      before do
        group.namespace_settings.update!(
          duo_core_features_enabled: true
        )
      end

      it { is_expected.to be(true) }

      context 'with sub-group' do
        it 'checks the namespace_settings of root_namespace' do
          expect(sub_group.duo_core_features_enabled?).to be(true)
        end
      end
    end

    context 'when namespace_settings has duo_core_features disabled' do
      before do
        group.namespace_settings.update!(
          duo_core_features_enabled: false
        )
      end

      it { is_expected.to be(false) }

      context 'with sub-group' do
        it 'checks the namespace_settings of root_namespace' do
          expect(sub_group.duo_core_features_enabled?).to be(false)
        end
      end
    end

    context 'when namespace_settings has duo_core_features as null' do
      before do
        group.namespace_settings.update!(
          duo_core_features_enabled: nil
        )
      end

      it { is_expected.to be(false) }

      context 'with sub-group' do
        it 'checks the namespace_settings of root_namespace' do
          expect(sub_group.duo_core_features_enabled?).to be(false)
        end
      end
    end
  end

  describe '#foundational_agents_default_enabled' do
    it 'provides safe defaults when there is no ai_settings record exists' do
      expect(namespace.ai_settings).not_to be_persisted
      expect(namespace.foundational_agents_default_enabled).to be(true)
    end
  end

  describe '#foundational_agents_default_enabled=' do
    it 'persists ai_settings record via nested attributes' do
      expect(namespace.ai_settings).not_to be_persisted

      namespace.update!(ai_settings_attributes: { foundational_agents_default_enabled: false })

      expect(namespace.ai_settings).to be_persisted
      expect(namespace.ai_settings.reload.foundational_agents_default_enabled).to be(false)
    end
  end

  describe '#prompt_injection_protection_level' do
    it 'provides safe defaults when there is no ai_settings record exists' do
      expect(namespace.ai_settings).not_to be_persisted
      expect(namespace.prompt_injection_protection_level).to eq('log_only')
    end
  end

  describe '#prompt_injection_protection_level=' do
    it 'persists ai_settings record via nested attributes' do
      expect(namespace.ai_settings).not_to be_persisted

      namespace.update!(ai_settings_attributes: { prompt_injection_protection_level: 'interrupt' })

      expect(namespace.ai_settings).to be_persisted
      expect(namespace.ai_settings.reload.prompt_injection_protection_level).to eq('interrupt')
    end
  end

  describe '#duo_workflow_mcp_enabled' do
    it 'provides safe defaults when there is no ai_settings record exists' do
      expect(namespace.ai_settings).not_to be_persisted
      expect(namespace.duo_workflow_mcp_enabled).to be(false)
    end
  end

  describe '#duo_workflow_mcp_enabled=' do
    it 'persists ai_settings record via nested attributes' do
      expect(namespace.ai_settings).not_to be_persisted

      namespace.update!(ai_settings_attributes: { duo_workflow_mcp_enabled: true })

      expect(namespace.ai_settings).to be_persisted
      expect(namespace.ai_settings.reload.duo_workflow_mcp_enabled).to be(true)
    end
  end

  describe '#duo_agent_platform_enabled' do
    it 'provides safe defaults when there is no ai_settings record exists' do
      expect(namespace.ai_settings).not_to be_persisted
      expect(namespace.duo_agent_platform_enabled).to be true
    end
  end

  describe '#duo_agent_platform_enabled=' do
    it 'persists ai_settings record via nested attributes' do
      expect(namespace.ai_settings).not_to be_persisted

      namespace.update!(ai_settings_attributes: { duo_agent_platform_enabled: false })

      expect(namespace.ai_settings).to be_persisted
      expect(namespace.ai_settings.reload.duo_agent_platform_enabled).to be false
    end
  end

  describe '#lifecycles' do
    context 'with system-defined lifecycles' do
      let_it_be(:system_defined_lifecycles_names) do
        ::WorkItems::Statuses::SystemDefined::Lifecycle.all.map(&:name)
      end

      it 'returns system-defined lifecycles' do
        expect(namespace.lifecycles.map(&:name)).to eq(system_defined_lifecycles_names)
      end
    end

    context 'with custom lifecycles' do
      let!(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

      it 'returns custom lifecycles' do
        expect(namespace.lifecycles).to contain_exactly(custom_lifecycle)
      end

      context 'when called on a descendant namespace' do
        let_it_be_with_reload(:root_group) { create(:group, organization: organization) }
        let_it_be_with_reload(:subgroup) { create(:group, parent: root_group, organization: organization) }
        let_it_be_with_reload(:project) { create(:project, group: subgroup, organization: organization) }
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: root_group) }

        it 'returns custom lifecycles from the root ancestor for a subgroup' do
          expect(subgroup.lifecycles).to contain_exactly(custom_lifecycle)
        end

        it 'returns custom lifecycles from the root ancestor for a project namespace' do
          expect(project.project_namespace.lifecycles).to contain_exactly(custom_lifecycle)
        end
      end
    end
  end

  describe '#statuses' do
    context 'with system-defined statuses' do
      let_it_be(:system_defined_statuses_names) do
        ::WorkItems::Statuses::SystemDefined::Status.all.map(&:name)
      end

      it 'returns system-defined statuses' do
        expect(namespace.statuses.map(&:name)).to eq(system_defined_statuses_names)
      end
    end

    context 'with custom statuses' do
      let!(:custom_status_1) { create(:work_item_custom_status, namespace: namespace) }
      let!(:custom_status_2) { create(:work_item_custom_status, :closed, namespace: namespace) }

      it 'returns custom statuses' do
        expect(namespace.statuses).to contain_exactly(custom_status_1, custom_status_2)
      end

      context 'when called on a descendant namespace' do
        let_it_be_with_reload(:root_group) { create(:group, organization: organization) }
        let_it_be_with_reload(:subgroup) { create(:group, parent: root_group, organization: organization) }
        let_it_be_with_reload(:project) { create(:project, group: subgroup, organization: organization) }
        let_it_be(:custom_status_1) { create(:work_item_custom_status, namespace: root_group) }
        let_it_be(:custom_status_2) { create(:work_item_custom_status, :closed, namespace: root_group) }

        it 'returns custom statuses from the root ancestor for a subgroup' do
          expect(subgroup.statuses).to contain_exactly(custom_status_1, custom_status_2)
        end

        it 'returns custom statuses from the root ancestor for a project namespace' do
          expect(project.project_namespace.statuses).to contain_exactly(custom_status_1, custom_status_2)
        end
      end
    end
  end

  describe '#compliance_framework_ids_with_csp' do
    include Security::PolicyCspHelpers

    let_it_be_with_refind(:namespace) { create(:group) }
    let_it_be(:csp_group) { create(:group) }

    let_it_be(:direct_framework) { create(:compliance_framework, namespace: namespace) }

    subject(:framework_ids_with_csp) { namespace.compliance_framework_ids_with_csp }

    before do
      stub_csp_group(csp_group)
    end

    context 'when CSP namespace has frameworks along with the current group' do
      it 'returns combined compliance framework IDs from both namespaces' do
        csp_framework = create(:compliance_framework, namespace: csp_group)

        expect(framework_ids_with_csp).to contain_exactly(direct_framework.id, csp_framework.id)
      end
    end

    context 'when CSP namespace has no frameworks' do
      let(:empty_csp_group) { create(:group) }

      before do
        stub_csp_group(empty_csp_group)
      end

      it 'returns only direct compliance framework IDs' do
        expect(framework_ids_with_csp).to contain_exactly(direct_framework.id)
      end
    end

    context 'when organization_policy_setting is nil' do
      before do
        allow(namespace).to receive(:organization_policy_setting).and_return(nil)
      end

      it 'returns only direct compliance framework IDs' do
        expect(framework_ids_with_csp).to contain_exactly(direct_framework.id)
      end
    end
  end

  describe '#enabled_flow_catalog_item_ids' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:catalog_item_1) { create(:ai_catalog_item, :with_foundational_flow_reference) }
    let_it_be(:catalog_item_2) { create(:ai_catalog_item, :with_foundational_flow_reference) }
    let_it_be(:catalog_item_3) { create(:ai_catalog_item, :with_foundational_flow_reference) }

    subject { namespace.enabled_flow_catalog_item_ids }

    context 'when namespace has no enabled foundational flows' do
      it 'returns an empty array' do
        is_expected.to eq([])
      end
    end

    context 'when namespace has enabled foundational flows' do
      before do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace,
          catalog_item: catalog_item_1)
        create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace,
          catalog_item: catalog_item_2)
      end

      it 'returns the catalog item ids' do
        is_expected.to match_array([catalog_item_1.id, catalog_item_2.id])
      end
    end

    context 'when namespace has more than 100 enabled foundational flows' do
      before do
        allow(namespace.enabled_foundational_flow_records).to receive(:limit).with(100).and_return(
          namespace.enabled_foundational_flow_records.limit(3)
        )

        4.times do
          catalog_item = create(:ai_catalog_item, :with_foundational_flow_reference)
          create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace,
            catalog_item: catalog_item)
        end
      end

      it 'returns only the limit of catalog item ids' do
        is_expected.to have_attributes(size: 3)
      end
    end

    context 'when namespace has no flows but parent has flows' do
      let_it_be(:parent_namespace) { create(:group) }
      let_it_be(:child_namespace) { create(:group, parent: parent_namespace) }

      subject { child_namespace.enabled_flow_catalog_item_ids }

      before do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace,
          namespace: parent_namespace, catalog_item: catalog_item_1)
        create(:ai_catalog_enabled_foundational_flow, :for_namespace,
          namespace: parent_namespace, catalog_item: catalog_item_2)
      end

      it 'returns parent namespace catalog item ids' do
        is_expected.to match_array([catalog_item_1.id, catalog_item_2.id])
      end
    end

    context 'when namespace has no flows and is deeply nested' do
      let_it_be(:root_namespace) { create(:group) }
      let_it_be(:middle_namespace) { create(:group, parent: root_namespace) }
      let_it_be(:leaf_namespace) { create(:group, parent: middle_namespace) }

      subject { leaf_namespace.enabled_flow_catalog_item_ids }

      before do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace,
          namespace: root_namespace, catalog_item: catalog_item_1)
      end

      it 'traverses up hierarchy to find flows from root' do
        is_expected.to match_array([catalog_item_1.id])
      end
    end

    context 'when namespace has flows and parent also has flows' do
      let_it_be(:parent_namespace) { create(:group) }
      let_it_be(:child_namespace) { create(:group, parent: parent_namespace) }

      subject { child_namespace.enabled_flow_catalog_item_ids }

      before do
        create(:ai_catalog_enabled_foundational_flow, :for_namespace,
          namespace: child_namespace, catalog_item: catalog_item_1)
        create(:ai_catalog_enabled_foundational_flow, :for_namespace,
          namespace: parent_namespace, catalog_item: catalog_item_2)
      end

      it 'returns own flows and does not inherit from parent' do
        is_expected.to match_array([catalog_item_1.id])
      end
    end
  end

  describe '#sync_enabled_foundational_flows!' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:flow1) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
    let_it_be(:flow2) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
    let_it_be(:flow3) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }

    before do
      namespace.enabled_foundational_flow_records.delete_all
    end

    it 'creates enabled foundational flow records for given IDs' do
      namespace.sync_enabled_foundational_flows!([flow1.id, flow2.id])

      expect(namespace.enabled_foundational_flow_records.reload.pluck(:catalog_item_id)).to match_array([flow1.id,
        flow2.id])
    end

    it 'removes enabled foundational flow records not in target IDs' do
      create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: flow1)
      create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: flow2)

      namespace.sync_enabled_foundational_flows!([flow1.id])

      expect(namespace.enabled_foundational_flow_records.reload.pluck(:catalog_item_id)).to eq([flow1.id])
    end

    it 'deletes all records when target_ids is empty' do
      create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: flow1)

      namespace.sync_enabled_foundational_flows!([])

      expect(namespace.enabled_foundational_flow_records.reload).to be_empty
    end

    it 'handles duplicates idempotently' do
      namespace.sync_enabled_foundational_flows!([flow1.id, flow2.id])

      expect { namespace.sync_enabled_foundational_flows!([flow1.id, flow2.id]) }
        .not_to change { namespace.enabled_foundational_flow_records.reload.count }
    end

    it 'tracks exceptions and raises when record is invalid' do
      allow(Ai::Catalog::EnabledFoundationalFlow).to receive(:bulk_insert!)
        .and_raise(ActiveRecord::RecordInvalid.new(Ai::Catalog::EnabledFoundationalFlow.new))

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        instance_of(ActiveRecord::RecordInvalid),
        hash_including(namespace_id: namespace.id, target_ids: [flow1.id])
      )

      expect { namespace.sync_enabled_foundational_flows!([flow1.id]) }
        .to raise_error(RuntimeError, /Validation failed/)
    end
  end

  describe '#remove_foundational_flow_consumers' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:flow) do
      create(:ai_catalog_item, :with_foundational_flow_reference, :public, organization: namespace.organization)
    end

    let_it_be(:consumer) { create(:ai_catalog_item_consumer, group: namespace, item: flow) }

    it 'removes consumers for the given catalog item IDs' do
      expect { namespace.remove_foundational_flow_consumers([flow.id]) }
        .to change { namespace.configured_ai_catalog_items.count }.by(-1)
    end

    it 'does nothing when catalog_item_ids is empty' do
      expect { namespace.remove_foundational_flow_consumers([]) }
        .not_to change { namespace.configured_ai_catalog_items.count }
    end
  end

  describe '#selected_foundational_flow_references' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:flow1) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
    let_it_be(:flow2) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }

    it 'returns selected flow references' do
      create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: flow1)
      create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: namespace, catalog_item: flow2)

      expect(namespace.selected_foundational_flow_references).to match_array([
        flow1.foundational_flow_reference,
        flow2.foundational_flow_reference
      ])
    end

    it 'returns empty array when no flows are enabled' do
      expect(namespace.selected_foundational_flow_references).to eq([])
    end
  end

  describe '#ai_feature_rules=' do
    let_it_be(:root_namespace) { create(:group) }
    let_it_be(:through_namespace) { create(:group, parent: root_namespace) }
    let_it_be(:through_namespace_2) { create(:group, parent: root_namespace) }

    let(:rules) do
      [{ through_namespace: { id: through_namespace.id }, features: %w[duo_classic] }]
    end

    subject(:update_rules) { root_namespace.ai_feature_rules = rules }

    context 'when not on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not create any rules' do
        expect { update_rules }.not_to change { Ai::NamespaceFeatureAccessRule.count }
      end
    end

    context 'when on saas', :saas do
      context 'when namespace is not the root namespace' do
        let(:subgroup) { create(:group, parent: root_namespace) }

        it 'does not create any rules' do
          expect { subgroup.ai_feature_rules = rules }.not_to change { Ai::NamespaceFeatureAccessRule.count }
        end
      end

      context 'when namespace is the root namespace' do
        let(:rules) do
          [
            { through_namespace: { id: through_namespace.id }, features: ['duo_classic'] },
            { through_namespace: { id: through_namespace_2.id }, features: ['duo_agent_platform'] }
          ]
        end

        before do
          create(:ai_namespace_feature_access_rules,
            :duo_agent_platform,
            root_namespace: root_namespace,
            through_namespace: through_namespace
          )
        end

        it 'creates ai feature rules and deletes existing ones' do
          expect { update_rules }.to change { Ai::NamespaceFeatureAccessRule.count }.by(1)

          created_rules = Ai::NamespaceFeatureAccessRule.where(root_namespace_id: root_namespace.id)
          expect(created_rules.pluck(:accessible_entity)).to match_array(
            %w[duo_classic duo_agent_platform]
          )
          expect(created_rules.pluck(:through_namespace_id)).to match_array(
            [through_namespace.id, through_namespace_2.id]
          )

          # deletes previously created rules
          expect(Ai::NamespaceFeatureAccessRule.where(
            root_namespace: root_namespace,
            through_namespace: through_namespace,
            accessible_entity: 'duo_agent_platform'
          ).exists?).to be false
        end

        context 'with blank features' do
          let(:rules) do
            [
              { through_namespace: { id: through_namespace.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_2.id }, features: [''] }
            ]
          end

          it 'does not create rules for blank features' do
            update_rules

            expect(through_namespace.ai_feature_rules_through_namespace.pluck(:accessible_entity))
              .to eq(['duo_classic'])
            expect(through_namespace_2.ai_feature_rules_through_namespace).to be_empty
          end
        end

        context 'when all features are empty' do
          let(:rules) do
            [
              { through_namespace: { id: through_namespace.id }, features: [] },
              { through_namespace: { id: through_namespace_2.id }, features: [] }
            ]
          end

          it 'deletes existing rules and does not create new ones' do
            expect { update_rules }.to change { Ai::NamespaceFeatureAccessRule.count }.from(1).to(0)
          end
        end

        context 'when a through_namespace does not exist' do
          let(:rules) do
            [
              { through_namespace: { id: through_namespace.id }, features: ['duo_classic'] },
              { through_namespace: { id: -1 }, features: ['duo_classic'] }
            ]
          end

          it 'skips the namespace features' do
            expect { update_rules }.not_to change { Ai::NamespaceFeatureAccessRule.count }

            expect(through_namespace.reload.ai_feature_rules_through_namespace.pluck(:accessible_entity))
              .to eq(['duo_classic'])
          end
        end

        context 'when avoiding N+1 queries' do
          let_it_be(:through_namespace_3) { create(:group, parent: root_namespace) }
          let_it_be(:through_namespace_4) { create(:group, parent: root_namespace) }

          let(:new_rules) do
            [
              { through_namespace: { id: through_namespace.id }, features: ['duo_agent_platform'] },
              { through_namespace: { id: through_namespace_2.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_3.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_4.id }, features: ['duo_agent_platform'] }
            ]
          end

          it 'batches through_namespace lookups in a single query' do
            control_count = ActiveRecord::QueryRecorder.new { update_rules }.log.count do |query|
              query.include?('FROM "namespaces"') && query.include?('parent_id')
            end

            update_rules_recorder = ActiveRecord::QueryRecorder.new do
              root_namespace.ai_feature_rules = new_rules
            end
            update_rules_query_count = update_rules_recorder.log.count do |query|
              query.include?('FROM "namespaces"') && query.include?('parent_id')
            end

            expect(control_count).to eq(1)
            expect(update_rules_query_count).to eq(1)
          end
        end

        context 'when the through namespace is not in the namespace hierarchy' do
          let(:other_through_namespace) { create(:group) }
          let(:rules) do
            [
              { through_namespace: { id: through_namespace.id }, features: ['duo_classic'] },
              { through_namespace: { id: other_through_namespace.id }, features: ['duo_agent_platform'] }
            ]
          end

          it 'does not create rules for the through namespace' do
            update_rules

            expect(through_namespace.ai_feature_rules_through_namespace
              .pluck(:accessible_entity)).to contain_exactly('duo_classic')
            expect(other_through_namespace.ai_feature_rules_through_namespace.exists?).to be false
          end
        end

        context 'with a default rule (nil through_namespace)' do
          let(:rules) do
            [{ through_namespace: nil, features: %w[duo_classic] }]
          end

          it 'creates a default rule with through_namespace_id nil' do
            update_rules

            default_rules = Ai::NamespaceFeatureAccessRule.where(
              root_namespace_id: root_namespace.id,
              through_namespace_id: nil
            )
            expect(default_rules.pluck(:accessible_entity)).to contain_exactly('duo_classic')
          end
        end

        context 'with a default rule when through_namespace key is absent' do
          let(:rules) do
            [{ features: %w[duo_classic] }]
          end

          it 'creates a default rule' do
            update_rules

            default_rules = Ai::NamespaceFeatureAccessRule.where(
              root_namespace_id: root_namespace.id,
              through_namespace_id: nil
            )
            expect(default_rules.pluck(:accessible_entity)).to contain_exactly('duo_classic')
          end
        end

        context 'with mixed default and group-based rules' do
          let(:rules) do
            [
              { through_namespace: nil, features: %w[duo_classic] },
              { through_namespace: { id: through_namespace.id }, features: %w[duo_agent_platform] }
            ]
          end

          it 'creates both default and group-based rules' do
            update_rules

            all_rules = Ai::NamespaceFeatureAccessRule.where(root_namespace_id: root_namespace.id)
            expect(all_rules.count).to eq(2)

            default_rules = all_rules.where(through_namespace_id: nil)
            expect(default_rules.pluck(:accessible_entity)).to contain_exactly('duo_classic')

            group_rules = all_rules.where.not(through_namespace_id: nil)
            expect(group_rules.pluck(:accessible_entity)).to contain_exactly('duo_agent_platform')
            expect(group_rules.pluck(:through_namespace_id)).to contain_exactly(through_namespace.id)
          end
        end
      end
    end
  end

  def create_project(repository_size:, lfs_objects_size: 0, repository_size_limit: nil)
    create(:project, namespace: namespace, repository_size_limit: repository_size_limit).tap do |project|
      create(:project_statistics, project: project, repository_size: repository_size,
        lfs_objects_size: lfs_objects_size)
    end
  end

  def create_storage_excess_example_projects
    [
      { repository_size: 100, lfs_objects_size: 0, repository_size_limit: nil },
      { repository_size: 150, lfs_objects_size: 0, repository_size_limit: nil },
      { repository_size: 140, lfs_objects_size: 10, repository_size_limit: nil },
      { repository_size: 150, lfs_objects_size: 10, repository_size_limit: nil },
      { repository_size: 200, lfs_objects_size: 100, repository_size_limit: nil },
      { repository_size: 100, lfs_objects_size: 0, repository_size_limit: 0 },
      { repository_size: 150, lfs_objects_size: 10, repository_size_limit: 0 },
      { repository_size: 200, lfs_objects_size: 100, repository_size_limit: 0 },
      { repository_size: 300, lfs_objects_size: 0, repository_size_limit: 400 },
      { repository_size: 400, lfs_objects_size: 0, repository_size_limit: 400 },
      { repository_size: 300, lfs_objects_size: 100, repository_size_limit: 400 },
      { repository_size: 400, lfs_objects_size: 100, repository_size_limit: 400 },
      { repository_size: 500, lfs_objects_size: 100, repository_size_limit: 300 }
    ].map { |attrs| create_project(**attrs) }
  end
end
