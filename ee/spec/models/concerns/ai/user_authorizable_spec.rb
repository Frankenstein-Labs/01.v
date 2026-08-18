# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UserAuthorizable, feature_category: :ai_abstraction_layer do
  let_it_be_with_refind(:user) { create(:user) }

  let(:expected_allowed) { true }
  let(:expected_namespace_ids) { [] }
  let(:expected_namespace_ids_from_all_addons) { expected_namespace_ids }
  let(:expected_enablement_type) { nil }
  let(:expected_authorized_by_duo_core) { false }
  let(:expected_response) do
    described_class::Response.new(
      allowed?: expected_allowed,
      namespace_ids: expected_namespace_ids,
      namespace_ids_from_all_addons: expected_namespace_ids_from_all_addons,
      enablement_type: expected_enablement_type,
      authorized_by_duo_core: expected_authorized_by_duo_core)
  end

  describe '#allowed_to_use' do
    shared_examples_for 'checking assigned seats' do
      context 'when the AI feature is missing' do
        let(:expected_allowed) { false }

        before do
          stub_const("Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", {})
        end

        it { is_expected.to eq expected_response }
      end

      context 'when the user has an active assigned seat' do
        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { allowed_by_namespace_ids }
        let(:expected_enablement_type) { 'duo_pro' }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: active_gitlab_purchase
          )
        end

        it { is_expected.to eq expected_response }
      end

      context 'when the user has an active assigned duo enterprise seat' do
        let_it_be_with_reload(:enterprise_gitlab_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let_it_be_with_reload(:enterprise_gitlab_purchase) do
          create(:gitlab_subscription_add_on_purchase, add_on: enterprise_gitlab_add_on)
        end

        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { Array(enterprise_gitlab_purchase.namespace_id) }
        let(:expected_enablement_type) { 'duo_enterprise' }
        let(:unit_primitive_add_ons) { %w[duo_enterprise] }

        before do
          enterprise_gitlab_purchase.update!(namespace: namespace)
          namespace&.add_owner(user)

          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: enterprise_gitlab_purchase
          )
        end

        it { is_expected.to eq expected_response }
      end

      context 'when the user has a Duo Core subscription' do
        let_it_be_with_reload(:active_gitlab_purchase) do
          create(:gitlab_subscription_add_on_purchase, :duo_core)
        end

        let(:expected_allowed) { true }
        let(:expected_enablement_type) { 'duo_core' }
        let(:expected_namespace_ids) { allowed_by_namespace_ids }
        let(:expected_authorized_by_duo_core) { true }
        let(:free_access) { false }
        let(:unit_primitive_add_ons) { %w[duo_pro duo_core] }

        it { is_expected.to eq expected_response }

        context 'when the feature requires identity verification' do
          let(:ai_feature) { :duo_agent_platform }

          before do
            allow(user).to receive(:identity_verified?).and_return(false)
          end

          it 'denies access' do
            expect(allowed_to_use).not_to be_allowed
          end

          context 'when identity verification is skipped' do
            before do
              stub_feature_flags(dap_require_identity_verification: false)
            end

            it 'allows access' do
              expect(allowed_to_use).to be_allowed
            end
          end
        end

        context 'when access is denied' do
          let(:allowed_by_namespace_ids) { [] }
          let(:expected_allowed) { false }
          let(:expected_enablement_type) { nil }
          let(:expected_authorized_by_duo_core) { false }

          context 'when user is not active' do
            let(:user) { create(:user, :blocked) }

            it { is_expected.to eq expected_response }
          end

          context 'when user is is a bot' do
            let(:user) { create(:user, :bot) }

            it { is_expected.to eq expected_response }
          end

          context 'when duo_core_features_enabled is false' do
            let(:duo_core_features_enabled) { false }

            it { is_expected.to eq expected_response }
          end

          context 'when the Duo unit primitive is not available through Duo Core' do
            let(:unit_primitive_add_ons) { %w[duo_pro] }

            it { is_expected.to eq expected_response }
          end
        end
      end

      context 'when the user has a GitLab Credits subscription' do
        let_it_be_with_reload(:active_gitlab_purchase) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_credits)
        end

        let(:expected_allowed) { true }
        let(:expected_enablement_type) { 'gitlab_credits' }
        let(:expected_namespace_ids) { allowed_by_namespace_ids }
        let(:expected_authorized_by_duo_core) { false }
        let(:free_access) { false }
        let(:unit_primitive_add_ons) { %w[duo_pro gitlab_credits] }

        it { is_expected.to eq expected_response }

        context 'when user is not active' do
          let(:user) { create(:user, :blocked) }
          let(:allowed_by_namespace_ids) { [] }
          let(:expected_allowed) { false }
          let(:expected_enablement_type) { nil }

          it { is_expected.to eq expected_response }
        end

        context 'when user is a bot' do
          let(:user) { create(:user, :bot) }
          let(:allowed_by_namespace_ids) { [] }
          let(:expected_allowed) { false }
          let(:expected_enablement_type) { nil }

          it { is_expected.to eq expected_response }
        end

        context 'when the unit primitive is not available through GitLab Credits' do
          let(:unit_primitive_add_ons) { %w[duo_pro] }
          let(:allowed_by_namespace_ids) { [] }
          let(:expected_allowed) { false }
          let(:expected_enablement_type) { nil }

          it { is_expected.to eq expected_response }
        end

        context 'when the user has no active GitLab Credits purchase' do
          let(:expected_allowed) { false }
          let(:expected_enablement_type) { nil }
          let(:expected_namespace_ids) { [] }

          before do
            active_gitlab_purchase.update!(expires_on: 1.day.ago)
          end

          it { is_expected.to eq expected_response }
        end
      end

      context "when the user doesn't have an active assigned seat and free access is not available" do
        let(:free_access) { false }
        let(:expected_allowed) { false }

        it { is_expected.to eq expected_response }

        context 'when the user has an expired seat' do
          before do
            create(
              :gitlab_subscription_user_add_on_assignment,
              user: user,
              add_on_purchase: expired_gitlab_purchase
            )
          end

          it { is_expected.to eq expected_response }
        end
      end

      context 'when checking add-on purchases with mixed add-on types' do
        let(:unit_primitive_add_ons) { %w[duo_pro] }

        context 'when user is assigned to duo_pro' do
          let(:expected_allowed) { true }
          let(:expected_namespace_ids) { [active_gitlab_purchase.namespace_id].compact }
          let(:expected_enablement_type) { 'duo_pro' }

          before do
            create(
              :gitlab_subscription_user_add_on_assignment,
              user: user,
              add_on_purchase: active_gitlab_purchase
            )
          end

          it { is_expected.to eq expected_response }
        end
      end
    end

    let(:ai_feature) { :my_feature }
    let(:duo_core_features_enabled) { true }
    let(:unit_primitive_name) { ai_feature }
    let(:maturity) { :ga }
    let(:free_access) { true }
    let(:unit_primitive_add_ons) { %w[duo_pro] }
    let(:licensed_feature) { :ai_features }
    let(:unit_primitive) do
      build(:cloud_connector_unit_primitive, name: unit_primitive_name, add_ons: unit_primitive_add_ons)
    end

    let(:root_namespace) { nil }

    let_it_be(:gitlab_add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:expired_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_add_on)
    end

    let_it_be_with_reload(:active_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: gitlab_add_on)
    end

    before do
      stub_const("Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", { ai_feature => { maturity: maturity } })

      allow(unit_primitive).to receive(:cut_off_date).and_return(free_access ? nil : (Time.current - 1.month))

      allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name).with(unit_primitive_name)
        .and_return(unit_primitive)
    end

    subject(:allowed_to_use) { user.allowed_to_use(ai_feature, root_namespace: root_namespace) }

    context 'when on Gitlab.com instance', :saas do
      let(:namespace) { active_gitlab_purchase.namespace }
      let(:allowed_by_namespace_ids) { [namespace.id] }

      before do
        namespace.add_owner(user)
      end

      context 'when user has both Duo Core and Pro, expected_namespace_ids_from_all_addons cover both' do
        let(:unit_primitive_add_ons) { %w[duo_pro duo_core] }
        let(:expected_namespace_ids) { [duo_pro_purchase.namespace.id] }
        let(:expected_namespace_ids_from_all_addons) { expected_namespace_ids + [duo_core_purchase.namespace.id] }
        let(:expected_enablement_type) { 'duo_pro' }

        let(:duo_pro_purchase) { active_gitlab_purchase }
        let_it_be_with_reload(:duo_core_purchase) do
          add_on = create(:gitlab_subscription_add_on, :duo_core)
          create(:gitlab_subscription_add_on_purchase, add_on: add_on)
        end

        before do
          duo_core_purchase.namespace.add_guest(user)
          duo_core_purchase.namespace.namespace_settings.update!(duo_core_features_enabled: true)

          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: duo_pro_purchase
          )
        end

        it { is_expected.to eq expected_response }
      end

      include_examples 'checking assigned seats' do
        before do
          namespace.namespace_settings.update!(
            duo_core_features_enabled: duo_core_features_enabled
          )
        end

        context 'when namespace access rules are in place' do
          let_it_be_with_refind(:namespace) { active_gitlab_purchase.namespace }
          let_it_be(:ns) { namespace }
          let_it_be_with_refind(:subgroup) { create(:group, parent: ns) }
          let_it_be(:rule) do
            create(
              :ai_namespace_feature_access_rules,
              :duo_classic,
              root_namespace: ns,
              through_namespace: subgroup
            )
          end

          let(:ai_feature) { :explain_vulnerability }
          let(:root_namespace) { ns }

          before_all do
            create(
              :gitlab_subscription_user_add_on_assignment,
              user: user,
              add_on_purchase: active_gitlab_purchase
            )
          end

          context 'when user has no group that would grant them access' do
            let(:expected_allowed) { false }
            let(:expected_namespace_ids) { [ns.id] }
            let(:expected_enablement_type) { 'dap_group_membership' }
            let(:authorized_by_duo_core) { false }

            it 'is not allowed and does not perform seat checks' do
              is_expected.to eq expected_response
            end
          end

          context 'when user is part of the namespace and subgroup that grants access' do
            before_all do
              subgroup.add_guest(user)
            end

            let(:expected_allowed) { true }
            let(:expected_namespace_ids) { allowed_by_namespace_ids }
            let(:expected_enablement_type) { 'duo_pro' }

            it 'performs other checks' do
              is_expected.to eq expected_response
            end
          end
        end
      end

      context "when the user doesn't have a seat but the unit primitive has free access" do
        context "when the user doesn't belong to any namespaces with eligible plans" do
          let(:expected_allowed) { false }

          it { is_expected.to eq expected_response }
        end

        context "when the user belongs to groups with eligible plans" do
          let_it_be_with_reload(:group) do
            create(:group_with_plan, plan: :ultimate_plan, guests: user)
          end

          let_it_be_with_reload(:group_without_experiment_features_enabled) do
            create(:group_with_plan, plan: :ultimate_plan, guests: user)
          end

          # TODO: Change to use context 'with ai features enabled for group'
          # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/497781
          before do
            allow(Gitlab).to receive(:org_or_com?).and_return(true)
            stub_ee_application_setting(should_check_namespace_plan: true)
            stub_licensed_features(
              ai_features: true,
              glab_ask_git_command: true,
              generate_description: true
            )
            group.namespace_settings.reload.update!(experiment_features_enabled: true)
          end

          shared_examples 'checking available groups' do
            let(:expected_namespace_ids) { [group.id, group_without_experiment_features_enabled.id] }
            let(:expected_enablement_type) { 'tier' }

            it { is_expected.to eq expected_response }

            context 'when the feature is not GA' do
              let(:expected_namespace_ids) { [group.id] }
              let(:maturity) { :beta }

              it { is_expected.to eq expected_response }

              context "when none of the user groups have experiment features enabled" do
                let(:expected_allowed) { false }
                let(:expected_namespace_ids) { [] }
                let(:expected_enablement_type) { nil }

                before do
                  group.namespace_settings.update!(experiment_features_enabled: false)
                end

                it { is_expected.to eq expected_response }
              end
            end
          end

          it_behaves_like 'checking available groups'

          describe 'returning namespace ids that allow using a feature' do
            let(:expected_enablement_type) { 'tier' }
            let(:expected_namespace_ids) { [group.id, group_without_experiment_features_enabled.id] }

            it { is_expected.to eq expected_response }

            context 'when the feature is not GA' do
              let(:maturity) { :beta }
              let(:expected_namespace_ids) { [group.id] }

              it { is_expected.to eq expected_response }
            end
          end

          context 'when specifying a unit_primitive name' do
            let(:unit_primitive_name) { :my_unit_primitive }

            subject { user.allowed_to_use(ai_feature, unit_primitive_name: unit_primitive_name) }

            it_behaves_like 'checking available groups'
          end
        end
      end

      context 'when GitLab Credits access requires DAP namespace settings' do
        shared_examples 'DAP credits enforcement' do
          let(:unit_primitive_add_ons) { %w[duo_pro gitlab_credits] }

          let_it_be(:dap_namespace) { create(:group, developers: user) }
          let_it_be(:dap_credits_purchase) do
            add_on = GitlabSubscriptions::AddOn.find_or_create_by_name(:gitlab_credits)
            create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: dap_namespace)
          end

          context 'when duo_agent_platform is enabled on the namespace' do
            let(:expected_namespace_ids) { [dap_namespace.id] }
            let(:expected_enablement_type) { 'gitlab_credits' }

            before_all do
              create(:namespace_ai_settings, namespace: dap_namespace,
                feature_settings: { duo_agent_platform_enabled: true })
            end

            it { is_expected.to eq expected_response }
          end

          context 'when duo_agent_platform is disabled on the namespace' do
            let(:expected_allowed) { false }

            before_all do
              create(:namespace_ai_settings, namespace: dap_namespace,
                feature_settings: { duo_agent_platform_enabled: false })
            end

            it { is_expected.to eq expected_response }
          end

          context 'when the namespace has no ai_settings row' do
            let(:expected_namespace_ids) { [dap_namespace.id] }
            let(:expected_enablement_type) { 'gitlab_credits' }

            it { is_expected.to eq expected_response }
          end
        end

        context 'when the unit primitive is duo_agent_platform' do
          let(:ai_feature) { :duo_agent_platform }

          it_behaves_like 'DAP credits enforcement'
        end

        context 'when the unit primitive is duo_chat' do
          let(:ai_feature) { :duo_chat }

          it_behaves_like 'DAP credits enforcement'
        end

        context 'when accessed via the classic chat feature name (:chat with unit_primitive_name: :duo_chat)' do
          let(:ai_feature) { :chat }
          let(:unit_primitive_name) { :duo_chat }
          let(:unit_primitive_add_ons) { %w[duo_pro gitlab_credits] }

          let_it_be(:dap_namespace) { create(:group, developers: user) }
          let_it_be(:dap_credits_purchase) do
            add_on = GitlabSubscriptions::AddOn.find_or_create_by_name(:gitlab_credits)
            create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: dap_namespace)
          end

          subject { user.allowed_to_use(ai_feature, unit_primitive_name: unit_primitive_name) }

          context 'when duo_agent_platform is enabled on the namespace' do
            let(:expected_allowed) { false }

            before_all do
              create(:namespace_ai_settings, namespace: dap_namespace,
                feature_settings: { duo_agent_platform_enabled: true })
            end

            it 'denies access — classic chat is never available via credits' do
              is_expected.to eq expected_response
            end
          end
        end
      end
    end

    context 'when on Self managed instance' do
      using RSpec::Parameterized::TableSyntax

      let(:namespace) { nil }

      let_it_be_with_reload(:active_gitlab_purchase) do
        create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: gitlab_add_on)
      end

      include_examples 'checking assigned seats' do
        let(:allowed_by_namespace_ids) { [] }

        before do
          # AddOnPurchase.for_user scope (used for Duo Core)
          # returns nil in SM instances if add-on
          # purchases are associated with namespaces
          active_gitlab_purchase.update!(namespace: nil)
          Ai::Setting.for_organization(user.organization).update!(duo_core_features_enabled: duo_core_features_enabled)
        end

        context 'when namespace access rules are in place' do
          let_it_be(:user) { create(:user) }
          let_it_be_with_refind(:ns) { create(:group) }

          let(:ai_feature) { :explain_vulnerability }

          before_all do
            create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: ns)
            create(
              :gitlab_subscription_user_add_on_assignment,
              user: user,
              add_on_purchase: active_gitlab_purchase
            )
          end

          context 'when user has no group that would grant them access' do
            let(:expected_allowed) { false }
            let(:expected_enablement_type) { 'dap_group_membership' }

            it 'is not allowed and does not perform seat checks' do
              is_expected.to eq expected_response
            end
          end

          context 'when user has a namespace that would grant them access' do
            before_all do
              ns.add_guest(user)
            end

            let(:expected_allowed) { true }
            let(:expected_namespace_ids) { allowed_by_namespace_ids }
            let(:expected_enablement_type) { 'duo_pro' }

            it 'still performs seat checks' do
              is_expected.to eq expected_response
            end
          end
        end
      end

      context 'when GitLab Credits access requires DAP instance settings' do
        shared_examples 'SM DAP credits enforcement' do
          let(:unit_primitive_add_ons) { %w[duo_pro gitlab_credits] }

          let_it_be(:dap_credits_purchase) do
            create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: nil)
          end

          context 'when duo_agent_platform is enabled at the instance level' do
            let(:expected_allowed) { true }
            let(:expected_enablement_type) { 'gitlab_credits' }
            let(:expected_namespace_ids) { [] }

            it { is_expected.to eq expected_response }
          end

          context 'when duo_agent_platform is disabled at the instance level' do
            let(:expected_allowed) { false }

            before do
              Ai::Setting.for_organization(user.organization).update!(duo_agent_platform_enabled: false)
            end

            it { is_expected.to eq expected_response }
          end

          context 'when there are no credits purchases' do
            let(:expected_allowed) { false }

            before do
              dap_credits_purchase.destroy!
            end

            it { is_expected.to eq expected_response }
          end
        end

        context 'when the unit primitive is duo_agent_platform' do
          let(:ai_feature) { :duo_agent_platform }

          it_behaves_like 'SM DAP credits enforcement'
        end

        context 'when the unit primitive is duo_chat' do
          let(:ai_feature) { :duo_chat }

          it_behaves_like 'SM DAP credits enforcement'
        end

        context 'when accessed via the classic chat feature name (:chat with unit_primitive_name: :duo_chat)' do
          let(:ai_feature) { :chat }
          let(:unit_primitive_name) { :duo_chat }
          let(:unit_primitive_add_ons) { %w[duo_pro gitlab_credits] }
          let(:expected_allowed) { false }

          let_it_be(:dap_credits_purchase) do
            create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: nil)
          end

          subject { user.allowed_to_use(ai_feature, unit_primitive_name: unit_primitive_name) }

          it 'denies access — classic chat is never available via credits' do
            is_expected.to eq expected_response
          end
        end
      end

      context "when the user doesn't have a seat but the unit_primitive has free access" do
        shared_examples 'when checking licensed features' do
          where(:licensed_feature_available, :free_access, :expected_allowed) do
            true  | true  | true
            true  | false | false
            false | true  | false
          end

          with_them do
            before do
              stub_licensed_features(licensed_feature => licensed_feature_available)
            end

            it { is_expected.to eq expected_response }
          end
        end

        it_behaves_like 'when checking licensed features'

        context 'when specifying a unit primitive name' do
          let(:unit_primitive_name) { :my_unit_primitive_name }

          before do
            stub_licensed_features(licensed_feature => true)
          end

          subject { user.allowed_to_use(ai_feature, unit_primitive_name: unit_primitive_name) }

          it { is_expected.to eq expected_response }
        end

        context 'when specifying a licensed feature name' do
          it_behaves_like 'when checking licensed features' do
            let(:licensed_feature) { :generate_commit_message }

            subject(:allowed_to_use) { user.allowed_to_use(ai_feature, licensed_feature: licensed_feature) }
          end
        end
      end
    end

    context 'when feature_setting is provided' do
      let_it_be(:self_hosted_model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:feature_setting) do
        create(:ai_feature_setting, feature: :duo_chat, self_hosted_model: self_hosted_model)
      end

      let(:self_hosted_unit_primitive) do
        build(:cloud_connector_unit_primitive, name: :self_hosted_models, add_ons: unit_primitive_add_ons)
      end

      subject(:allowed_to_use) do
        user.allowed_to_use(ai_feature, unit_primitive_name: :invalid_unit_primitive, feature_setting: feature_setting)
      end

      context 'for self-hosted classic feature setting' do
        before do
          stub_licensed_features(licensed_feature => true)
          allow(self_hosted_unit_primitive).to receive(:cut_off_date).and_return(
            free_access ? nil : (Time.current - 1.month)
          )
          allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name).with(:self_hosted_models)
            .and_return(self_hosted_unit_primitive)
        end

        it 'uses self_hosted_models unit primitive' do
          expect(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name).with(:self_hosted_models)
            .and_return(self_hosted_unit_primitive)

          allowed_to_use
        end

        it { is_expected.to eq expected_response }
      end

      context 'for self-hosted DAP feature setting' do
        shared_examples 'resolves DAP self-hosted via feature setting' do
          let(:expected_allowed) { true }
          let(:expected_enablement_type) { 'self_hosted_usage_billing' }

          it 'short-circuits via check_dap_self_hosted_feature without looking up a unit primitive' do
            expect(Gitlab::CloudConnector::DataModel::UnitPrimitive).not_to receive(:find_by_name)

            allowed_to_use
          end

          it { is_expected.to eq expected_response }
        end

        context 'when feature is duo_agent_platform' do
          let_it_be(:feature_setting) do
            create(:ai_feature_setting, feature: :duo_agent_platform, self_hosted_model: self_hosted_model)
          end

          it_behaves_like 'resolves DAP self-hosted via feature setting'
        end

        context 'when feature is duo_agent_platform_agentic_chat' do
          let_it_be(:feature_setting) do
            create(:ai_feature_setting, feature: :duo_agent_platform_agentic_chat, self_hosted_model: self_hosted_model)
          end

          it_behaves_like 'resolves DAP self-hosted via feature setting'
        end

        context 'when verifying no user assignment required for self-hosted DAP' do
          let(:self_hosted_unit_primitive) do
            build(:cloud_connector_unit_primitive, name: :self_hosted_models, add_ons: %w[duo_pro])
          end

          before do
            allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
              .and_call_original
          end

          it 'can check DAP feature setting' do
            result = user.allowed_to_use(ai_feature, feature_setting: feature_setting)
            expect(result).to be_a(described_class::Response)
          end
        end
      end
    end

    context 'when testing get_self_hosted_unit_primitive_name coverage' do
      let_it_be(:self_hosted_model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let(:ai_feature) { :code_generations }
      let(:maturity) { :ga }
      let(:free_access) { true }
      let(:unit_primitive_add_ons) { %w[duo_pro] }
      let(:unit_primitive) do
        build(:cloud_connector_unit_primitive, name: :code_generations, add_ons: unit_primitive_add_ons)
      end

      before do
        stub_const("Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", { ai_feature => { maturity: maturity } })
        allow(unit_primitive).to receive(:cut_off_date).and_return(free_access ? nil : (Time.current - 1.month))
      end

      shared_examples 'feature settings with unit primitive lookup' do
        let_it_be(:feature_settings) do
          feature_names.map do |feature_name|
            create(:ai_feature_setting, feature: feature_name, self_hosted_model: self_hosted_model)
          end
        end

        before do
          stub_licensed_features(ai_features: true)
          allow(resolved_unit_primitive).to receive(:cut_off_date).and_return(nil)
          allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(expected_unit_primitive_name)
            .and_return(resolved_unit_primitive)
        end

        it 'looks up the expected unit primitive for each feature setting' do
          feature_settings.each do |feature_setting|
            expect(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
              .with(expected_unit_primitive_name)
              .and_return(resolved_unit_primitive)

            user.allowed_to_use(ai_feature, unit_primitive_name: :invalid, feature_setting: feature_setting)
          end
        end

        it 'returns the expected response for each feature setting' do
          feature_settings.each do |feature_setting|
            expect(user.allowed_to_use(ai_feature, unit_primitive_name: :invalid, feature_setting: feature_setting))
              .to eq expected_response
          end
        end
      end

      shared_examples 'feature settings with early return' do
        let_it_be(:feature_settings) do
          feature_names.map do |feature_name|
            create(:ai_feature_setting, feature: feature_name, self_hosted_model: self_hosted_model)
          end
        end

        before do
          stub_licensed_features(ai_features: true)
        end

        it 'short-circuits without looking up a unit primitive for each feature setting' do
          expect(Gitlab::CloudConnector::DataModel::UnitPrimitive).not_to receive(:find_by_name)

          feature_settings.each do |feature_setting|
            user.allowed_to_use(ai_feature, unit_primitive_name: :invalid, feature_setting: feature_setting)
          end
        end

        it 'returns the expected response for each feature setting' do
          feature_settings.each do |feature_setting|
            expect(user.allowed_to_use(ai_feature, unit_primitive_name: :invalid, feature_setting: feature_setting))
              .to eq expected_response
          end
        end
      end

      context 'when feature_setting is nil' do
        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { [] }

        subject(:allowed_to_use) do
          user.allowed_to_use(ai_feature, unit_primitive_name: ai_feature, feature_setting: nil)
        end

        before do
          stub_licensed_features(ai_features: true)
          allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(ai_feature)
            .and_return(unit_primitive)
        end

        it 'uses the provided unit_primitive_name' do
          expect(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(ai_feature)
            .and_return(unit_primitive)

          allowed_to_use
        end

        it { is_expected.to eq expected_response }
      end

      context 'when feature_setting exists but is not self-hosted' do
        let_it_be(:non_self_hosted_feature_setting) do
          build(:ai_feature_setting, feature: :code_generations, self_hosted_model: nil)
        end

        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { [] }

        subject(:allowed_to_use) do
          user.allowed_to_use(ai_feature, unit_primitive_name: ai_feature,
            feature_setting: non_self_hosted_feature_setting)
        end

        before do
          stub_licensed_features(ai_features: true)
          allow(non_self_hosted_feature_setting).to receive(:self_hosted?).and_return(false)
          allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(ai_feature)
            .and_return(unit_primitive)
        end

        it 'uses the provided unit_primitive_name instead of self-hosted override' do
          expect(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(ai_feature)
            .and_return(unit_primitive)

          allowed_to_use
        end

        it { is_expected.to eq expected_response }
      end

      context 'when feature_setting is self-hosted but feature is not DAP' do
        let_it_be(:non_dap_feature_setting) do
          create(:ai_feature_setting, feature: :duo_chat, self_hosted_model: self_hosted_model)
        end

        let(:self_hosted_unit_primitive) do
          build(:cloud_connector_unit_primitive, name: :self_hosted_models, add_ons: %w[duo_pro])
        end

        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { [] }

        subject(:allowed_to_use) do
          user.allowed_to_use(ai_feature, unit_primitive_name: :invalid, feature_setting: non_dap_feature_setting)
        end

        before do
          stub_licensed_features(ai_features: true)
          allow(self_hosted_unit_primitive).to receive(:cut_off_date).and_return(nil)
          allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(:self_hosted_models)
            .and_return(self_hosted_unit_primitive)
        end

        it 'returns :self_hosted_models for non-DAP self-hosted features' do
          expect(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(:self_hosted_models)
            .and_return(self_hosted_unit_primitive)

          allowed_to_use
        end

        it { is_expected.to eq expected_response }
      end

      context 'when feature_setting is self-hosted DAP' do
        let_it_be(:feature_names) do
          [:duo_agent_platform, :duo_agent_platform_agentic_chat]
        end

        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { [] }
        let(:expected_enablement_type) { 'self_hosted_usage_billing' }

        it_behaves_like 'feature settings with early return'
      end

      context 'when feature_setting is self-hosted Code Suggestions' do
        let_it_be(:feature_names) do
          [:code_generations, :code_completions]
        end

        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { [] }
        let(:expected_enablement_type) { 'self_hosted_usage_billing' }

        # Code Suggestion feature are considered DAP feature for online cloud licenses
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/593893#note_3214359210 for more details
        context 'when cloud license is offline' do
          let(:license_double) do
            instance_double(License, offline_cloud_license?: true, online_cloud_license?: false)
          end

          let(:expected_unit_primitive_name) { :self_hosted_models }
          let(:expected_enablement_type) { nil }
          let(:resolved_unit_primitive) do
            build(:cloud_connector_unit_primitive, name: :self_hosted_models, add_ons: %w[duo_pro])
          end

          before do
            allow(license_double).to receive(:feature_available?).with(:amazon_q).and_return(false)
            allow(License).to receive(:current).and_return(license_double)
          end

          it_behaves_like 'feature settings with unit primitive lookup'
        end

        context 'when cloud license is online' do
          let(:license_double) do
            instance_double(License, offline_cloud_license?: false, online_cloud_license?: true)
          end

          let(:expected_enablement_type) { 'self_hosted_usage_billing' }

          before do
            allow(license_double).to receive(:feature_available?).with(:amazon_q).and_return(false)
            allow(License).to receive(:current).and_return(license_double)
          end

          it_behaves_like 'feature settings with early return'
        end
      end
    end

    context 'when testing self-hosted DAP without user assignment' do
      let(:ai_feature) { :duo_agent_platform }

      let_it_be(:self_hosted_model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:dap_feature_setting) do
        create(:ai_feature_setting, feature: :duo_agent_platform, self_hosted_model: self_hosted_model)
      end

      let_it_be(:dap_add_on) { create(:gitlab_subscription_add_on, :self_hosted_dap) }
      let_it_be(:dap_purchase) do
        create(:gitlab_subscription_add_on_purchase, :self_managed,
          add_on: dap_add_on,
          namespace: nil,
          expires_on: 1.year.from_now,
          quantity: 10)
      end

      before do
        stub_licensed_features(ai_features: true)
      end

      it 'allows access to DAP without user assignment check' do
        result = user.allowed_to_use(ai_feature, feature_setting: dap_feature_setting)
        expect(result).to be_a(described_class::Response)
        expect(result.allowed?).to be(true)
        expect(result.enablement_type).to eq('self_hosted_usage_billing')
      end

      it 'identifies duo_agent_platform as DAP feature' do
        result = user.allowed_to_use(ai_feature, feature_setting: dap_feature_setting)
        expect(result).to be_a(described_class::Response)
      end

      # rubocop:disable RSpec/MultipleMemoizedHelpers -- we need these variables
      # Hit the branch where feature_setting is not a DAP feature
      context 'with non-DAP self-hosted feature' do
        let_it_be(:non_dap_feature_setting) do
          create(:ai_feature_setting, feature: :code_generations, self_hosted_model: self_hosted_model)
        end

        let(:regular_unit_primitive) do
          build(:cloud_connector_unit_primitive, name: :self_hosted_models, add_ons: %w[duo_pro])
        end

        before do
          allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(:self_hosted_models)
            .and_return(regular_unit_primitive)
          allow(regular_unit_primitive).to receive(:cut_off_date).and_return(nil)
        end

        it 'uses self_hosted_models for non-DAP features' do
          result = user.allowed_to_use(:code_generations, feature_setting: non_dap_feature_setting)
          expect(result).to be_a(described_class::Response)
        end
      end

      context 'when user is not assigned to non-DAP add-on' do
        let_it_be(:product_analytics_add_on) do
          create(:gitlab_subscription_add_on, :product_analytics)
        end

        let_it_be(:product_analytics_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_managed,
            add_on: product_analytics_add_on,
            namespace: nil,
            expires_on: 1.year.from_now)
        end

        let(:product_analytics_unit_primitive) do
          build(:cloud_connector_unit_primitive,
            name: :product_analytics_feature,
            add_ons: %w[product_analytics])
        end

        before do
          allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .with(:product_analytics_feature)
            .and_return(product_analytics_unit_primitive)
          allow(product_analytics_unit_primitive).to receive(:cut_off_date).and_return(nil)
        end

        it 'denies access to non-DAP add-on without user assignment' do
          result = user.allowed_to_use(:product_analytics_feature, unit_primitive_name: :product_analytics_feature)
          expect(result.allowed?).to be(false)
        end
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers
    end

    context 'when unit_primitive data is missing' do
      let(:expected_allowed) { false }
      let(:unit_primitive) { nil }

      it { is_expected.to eq expected_response }
    end

    context 'with the DAP identity verification gate', :saas do
      let_it_be_with_reload(:dap_user) { create(:user) }
      let_it_be_with_reload(:trial_group) do
        create(:group_with_plan, :public, plan: :ultimate_trial_plan, developers: dap_user)
      end

      let(:identity_verified) { false }

      before do
        # Exemptions (paid namespace, enterprise, etc.) live in #identity_verified?,
        # covered in identity_verifiable_spec.rb; stub it to test the gate alone.
        allow(dap_user).to receive(:identity_verified?).and_return(identity_verified)
      end

      describe '#apply_identity_verification_gate' do
        def gate(response, feature: :duo_agent_platform)
          dap_user.send(:apply_identity_verification_gate, response, feature, trial_group)
        end

        def response_for(enablement_type, allowed: true)
          described_class::Response.new(
            allowed?: allowed, namespace_ids: [trial_group.id],
            enablement_type: enablement_type, authorized_by_duo_core: false
          )
        end

        it 'denies UNPAID (duo_core / tier) access when verification is required', :aggregate_failures do
          expect(gate(response_for('duo_core')).allowed?).to be false
          expect(gate(response_for('tier')).allowed?).to be false
        end

        it 'allows PAID access (add-ons, credits) even when verification would be required', :aggregate_failures do
          %w[duo_pro duo_enterprise gitlab_credits].each do |paid|
            expect(gate(response_for(paid)).allowed?).to be true
          end
        end

        it 'does not gate unpaid access for a non-DAP feature' do
          expect(gate(response_for('duo_core'), feature: :duo_chat).allowed?).to be true
        end

        it 'passes an already-denied response through unchanged' do
          expect(gate(response_for('duo_core', allowed: false)).allowed?).to be false
        end
      end
    end
  end

  context 'when amazon q integration is connected with duo_enterprise addon' do
    subject { user.allowed_to_use(ai_feature) }

    let_it_be(:gitlab_subscription_user_add_on_assignment) do
      duo_pro_purchase = create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_enterprise)
      create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: duo_pro_purchase)
    end

    using RSpec::Parameterized::TableSyntax

    where(:amazon_q_connected, :ai_feature, :expected_enablement_type) do
      false | :duo_chat | 'duo_enterprise'
      true | :review_merge_request | 'duo_enterprise'
      true | :summarize_new_merge_request | 'duo_enterprise'
      true | :generate_description | 'duo_enterprise'
    end

    with_them do
      before do
        stub_current_organization(user.organization)
        Ai::Setting.for_organization(user.organization).update!(amazon_q_ready: amazon_q_connected)
        stub_licensed_features(amazon_q: true)
      end

      it 'checks whether the feature is available in Amazon Q' do
        is_expected.to eq(expected_response)
      end
    end
  end

  context 'when amazon q integration is connected with amazon_q addon' do
    subject { user.allowed_to_use(ai_feature) }

    let_it_be(:amazon_q_unit_primitive) do
      build(:cloud_connector_unit_primitive,
        name: 'amazon_q_integration',
        cut_off_date: Time.current - 1.month,
        add_ons: build_list(:cloud_connector_add_on, 1, name: 'duo_amazon_q')
      )
    end

    let_it_be(:gitlab_subscription_add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_amazon_q)
    end

    using RSpec::Parameterized::TableSyntax

    where(:amazon_q_connected, :ai_feature, :expected_enablement_type) do
      true  | :duo_chat | 'duo_amazon_q'
      true  | :code_suggestions | 'duo_amazon_q'
      true  | :troubleshoot_job | 'duo_amazon_q'
      true  | :explain_vulnerability | 'duo_amazon_q'
      true  | :glab_ask_git_command | 'duo_amazon_q'
      true  | :resolve_vulnerability | 'duo_amazon_q'
      true  | :summarize_comments | 'duo_amazon_q'
      true  | :generate_commit_message | 'duo_amazon_q'
      true  | :generate_description | 'duo_amazon_q'
      true  | :summarize_review | 'duo_amazon_q'
      true  | :summarize_new_merge_request | 'duo_amazon_q'
    end

    with_them do
      before do
        stub_current_organization(user.organization)
        Ai::Setting.for_organization(user.organization).update!(amazon_q_ready: amazon_q_connected)
        stub_licensed_features(amazon_q: true)

        allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:find_by_name)
            .and_return(amazon_q_unit_primitive)
      end

      it 'checks whether the feature is available in Amazon Q' do
        is_expected.to eq(expected_response)
      end
    end

    context 'when user is a composite identity service account' do
      let_it_be(:scoped_user) { create(:user) }
      let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

      before do
        identity = instance_double(::Gitlab::Auth::Identity, linked?: true, scoped_user: scoped_user)
        allow(::Gitlab::Auth::Identity).to receive(:currently_linked).and_return(identity)
      end

      it 'delegates to the scoped human user' do
        scoped_response = described_class::Response.new(
          allowed?: true, namespace_ids: [], authorized_by_duo_core: false
        )
        allow(scoped_user).to receive(:duo_entitlement).and_return(scoped_response)

        expect(service_account.allowed_to_use(:chat)).to eq(scoped_response)
      end
    end

    context 'when user is a composite identity service account without a linked identity' do
      let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

      before do
        allow(::Gitlab::Auth::Identity).to receive(:currently_linked).and_return(nil)
      end

      it 'does not delegate and evaluates normally' do
        expect(service_account.allowed_to_use(:chat).allowed?).to be(false)
      end
    end

    context 'when user is a regular service account without composite identity enforced' do
      let_it_be(:service_account) { create(:user, :service_account) }

      it 'does not delegate and evaluates normally' do
        expect(service_account.allowed_to_use(:chat).allowed?).to be(false)
      end
    end
  end

  describe '#allowed_to_use?' do
    let(:ai_feature) { :my_feature }

    subject { user.allowed_to_use?(ai_feature, unit_primitive_name: :duo_chat, licensed_feature: :ai_features) }

    it 'checks allowed_to_use object' do
      expect(user).to receive(:allowed_to_use).with(
        ai_feature,
        unit_primitive_name: :duo_chat,
        licensed_feature: :ai_features,
        root_namespace: nil
      ).and_return(expected_response)

      is_expected.to be(true)
    end
  end

  describe '#dap_identity_verification_required?' do
    let_it_be_with_reload(:container) { create(:group, guests: user) }

    let(:identity_verified) { false }
    let(:entitled) { true }
    let(:enablement_type) { 'duo_core' }
    let(:entitlement) do
      described_class::Response.new(
        allowed?: entitled, namespace_ids: [], enablement_type: enablement_type, authorized_by_duo_core: false
      )
    end

    subject(:verification_required) { user.dap_identity_verification_required?(container) }

    before do
      allow(user).to receive(:identity_verified?).and_return(identity_verified)
      allow(user).to receive(:duo_entitlement)
        .with(:duo_agent_platform, root_namespace: container).and_return(entitlement)
    end

    context 'when access is unpaid and the user has not verified' do
      let(:identity_verified) { false }
      let(:entitled) { true }
      let(:enablement_type) { 'duo_core' }

      it { is_expected.to be(true) }
    end

    context 'when duo features are disabled for the container' do
      before do
        container.namespace_settings.update!(duo_features_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is no container' do
      let(:container) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the user has already verified' do
      let(:identity_verified) { true }

      it { is_expected.to be(false) }
    end

    context 'when access is paid' do
      let(:enablement_type) { 'gitlab_credits' }

      it { is_expected.to be(false) }
    end

    context 'when not entitled to the platform' do
      let(:entitled) { false }

      it { is_expected.to be(false) }
    end

    context 'when `dap_require_identity_verification` feature flag is disabled' do
      before do
        stub_feature_flags(dap_require_identity_verification: false)
      end

      it { is_expected.to be(false) }
    end

    context 'with more than one container' do
      let_it_be_with_reload(:other_container) { create(:group, guests: user) }

      before do
        other_container.namespace_settings.update!(duo_features_enabled: false)
      end

      it 'evaluates each container independently' do
        expect(user.dap_identity_verification_required?(container)).to be(true)
        expect(user.dap_identity_verification_required?(other_container)).to be(false)
      end
    end

    it 'resolves the entitlement once for repeated calls' do
      expect(user).to receive(:duo_entitlement).once.and_return(entitlement)

      2.times { user.dap_identity_verification_required?(container) }
    end
  end

  describe '#allowed_by_namespace_ids' do
    let(:ai_feature) { :my_feature }

    subject { user.allowed_by_namespace_ids(ai_feature) }

    context "when allowed_to_use doesn't return any namespace ids" do
      before do
        allow(user).to receive(:allowed_to_use).with(ai_feature)
          .and_return(described_class::Response.new(allowed?: true, namespace_ids: []))
      end

      it { is_expected.to eq([]) }
    end

    context 'when allowed_to_use returns namespace ids' do
      let(:namespace_ids) { [1, 2] }

      before do
        allow(user).to receive(:allowed_to_use).with(ai_feature)
          .and_return(described_class::Response.new(allowed?: true, namespace_ids: namespace_ids))
      end

      it { is_expected.to eq(namespace_ids) }
    end
  end

  describe '#any_group_with_ai_available?', :saas, :use_clean_rails_redis_caching do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_reload(:bronze_group) { create(:group_with_plan, plan: :bronze_plan) }
    let_it_be_with_reload(:free_group) { create(:group_with_plan, plan: :free_plan) }
    let_it_be_with_reload(:group_without_plan) { create(:group) }
    let_it_be_with_reload(:trial_group) do
      create(
        :group_with_plan,
        plan: :ultimate_plan,
        trial: true,
        trial_starts_on: Date.current,
        trial_ends_on: 1.day.from_now
      )
    end

    let_it_be_with_reload(:ultimate_sub_group) { create(:group, parent: ultimate_group, guests: user) }
    let_it_be_with_reload(:bronze_sub_group) { create(:group, parent: bronze_group, guests: user) }

    subject(:group_with_ai_enabled) { user.any_group_with_ai_available? }

    where(:group, :result) do
      ref(:bronze_group)       | false
      ref(:free_group)         | false
      ref(:group_without_plan) | false
      ref(:ultimate_group)     | true
      ref(:trial_group)        | true
    end

    with_them do
      context 'when member of the root group' do
        before do
          group.add_guest(user)
        end

        context 'when ai features are enabled' do
          include_context 'with ai features enabled for group'

          it { is_expected.to eq(result) }

          it 'caches the result' do
            group_with_ai_enabled

            expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to eq(result)
          end
        end

        context 'when ai features are not enabled' do
          it { is_expected.to be(false) }
        end
      end
    end

    context 'when member of a sub-group only' do
      include_context 'with ai features enabled for group'

      context 'with eligible group' do
        let(:group) { ultimate_group }

        it { is_expected.to be(true) }
      end

      context 'with not eligible group' do
        let(:group) { bronze_group }

        it { is_expected.to be(false) }
      end
    end

    context 'when member of a project only' do
      include_context 'with ai features enabled for group'

      context 'with eligible group' do
        let(:group) { ultimate_group }
        let_it_be(:project) { create(:project, group: ultimate_group, guests: user) }

        it { is_expected.to be(true) }
      end

      context 'with not eligible group' do
        let(:group) { bronze_group }
        let_it_be(:project) { create(:project, group: bronze_group, guests: user) }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#any_group_with_mcp_server_enabled?', :saas, :use_clean_rails_redis_caching do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:premium_group) { create(:group_with_plan, plan: :premium_plan) }
    let_it_be_with_reload(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_reload(:bronze_group) { create(:group_with_plan, plan: :bronze_plan) }
    let_it_be_with_reload(:free_group) { create(:group_with_plan, plan: :free_plan) }
    let_it_be_with_reload(:group_without_plan) { create(:group) }
    let_it_be_with_reload(:trial_group) do
      create(
        :group_with_plan,
        plan: :ultimate_plan,
        trial: true,
        trial_starts_on: Date.current,
        trial_ends_on: 1.day.from_now
      )
    end

    let_it_be_with_reload(:ultimate_sub_group) { create(:group, parent: ultimate_group) }
    let_it_be_with_reload(:bronze_sub_group) { create(:group, parent: bronze_group) }

    subject(:group_with_mcp_server_enabled) { user.any_group_with_mcp_server_enabled? }

    context 'when user is not member of any group' do
      it { is_expected.to be(false) }
    end

    context 'when SaaS', :saas do
      let_it_be(:user, freeze: false) { create(:user) }
      let_it_be(:group, freeze: false) { create(:group) }

      before_all do
        group.add_developer(user)
      end

      before do
        allow(user).to receive(:authorized_root_ancestor_ids).and_return([group.id])
      end

      context 'when group has mcp_server_enabled = true' do
        before do
          allow(Group).to receive(:with_mcp_server_enabled).and_return(
            Group.where(id: group.id)
          )
        end

        it 'returns true' do
          expect(user.any_group_with_mcp_server_enabled?).to be true
        end

        it 'caches the result with the MCP server cache key' do
          user.any_group_with_mcp_server_enabled?

          expect(
            Rails.cache.fetch(['users', user.id, described_class::GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY])
          ).to be true
        end
      end

      context 'when group has mcp_server_enabled = false' do
        before do
          allow(Group).to receive(:with_mcp_server_enabled).and_return(Group.none)
        end

        it 'returns false' do
          expect(user.any_group_with_mcp_server_enabled?).to be false
        end
      end

      it 'uses the expected cache key' do
        expect(described_class::GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY).to eq('group_with_mcp_server_enabled')
      end

      it 'uses the expected cache period' do
        expect(described_class::GROUP_WITH_MCP_SERVER_ENABLED_CACHE_PERIOD).to eq(1.hour)
      end
    end
  end

  shared_examples 'returns IDs of namespaces with duo add-on' do
    let_it_be(:gitlab_duo_add_on) { create(:gitlab_subscription_add_on, add_on_type) }

    let_it_be(:expired_gitlab_duo_purchase) do
      create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_duo_add_on)
    end

    let_it_be_with_reload(:active_gitlab_duo_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_add_on)
    end

    context 'when the user has an active assigned duo seat' do
      it 'returns the namespace ID' do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_purchase
        )

        expect(duo_namespace_ids).to eq([active_gitlab_duo_purchase.namespace_id])
      end
    end

    context 'when the user belongs to multiple namespaces with an active assigned duo seat' do
      let_it_be(:active_gitlab_duo_pro_purchase_2) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_add_on)
      end

      it 'returns the namespace IDs' do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_purchase
        )

        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_2
        )

        expect(duo_namespace_ids)
          .to contain_exactly(active_gitlab_duo_purchase.namespace_id,
            active_gitlab_duo_pro_purchase_2.namespace_id)
      end
    end

    context 'when the user has an expired assigned duo seat' do
      it 'returns empty' do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: expired_gitlab_duo_purchase
        )

        expect(duo_namespace_ids).to be_empty
      end
    end

    context 'when the user has no add on seat assignments' do
      it 'returns empty' do
        expect(duo_namespace_ids).to be_empty
      end
    end
  end

  describe '#duo_available_namespace_ids' do
    context 'when user has duo pro add-on' do
      it_behaves_like 'returns IDs of namespaces with duo add-on' do
        subject(:duo_namespace_ids) { user.duo_available_namespace_ids }

        let_it_be(:add_on_type) { :duo_pro }
      end
    end

    context 'when user has duo enterprise add-on' do
      it_behaves_like 'returns IDs of namespaces with duo add-on' do
        subject(:duo_namespace_ids) { user.duo_available_namespace_ids }

        let_it_be(:add_on_type) { :duo_enterprise }
      end
    end

    context 'when user has duo core add-on' do
      it_behaves_like 'returns IDs of namespaces with duo add-on' do
        subject(:duo_namespace_ids) { user.duo_available_namespace_ids }

        let_it_be(:add_on_type) { :duo_core }
      end
    end
  end

  describe '#duo_core_ids_via_namespace_settings' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:group1) { create(:group) }
    let_it_be(:group2) { create(:group) }
    let_it_be(:group3) { create(:group) }

    context 'when user has groups with duo core enabled' do
      before do
        allow(user).to receive(:groups_with_duo_core_enabled).and_return(
          class_double(Namespace, present?: true, ids: [group1.id, group2.id, group3.id])
        )
      end

      it 'returns the group IDs' do
        expect(user.duo_core_ids_via_namespace_settings).to match_array([group1.id, group2.id, group3.id])
      end
    end

    context 'when user has no groups with duo core enabled' do
      before do
        allow(user).to receive(:groups_with_duo_core_enabled).and_return(
          class_double(Namespace, present?: false, ids: [])
        )
      end

      it 'returns an empty array' do
        expect(user.duo_core_ids_via_namespace_settings).to eq([])
      end
    end

    context 'when groups_with_duo_core_enabled returns nil' do
      before do
        allow(user).to receive(:groups_with_duo_core_enabled).and_return(nil)
      end

      it 'returns an empty array' do
        expect(user.duo_core_ids_via_namespace_settings).to eq([])
      end
    end

    context 'when groups_with_duo_core_enabled returns empty collection' do
      before do
        allow(user).to receive(:groups_with_duo_core_enabled).and_return(Group.none)
      end

      it 'returns an empty array' do
        expect(user.duo_core_ids_via_namespace_settings).to eq([])
      end
    end
  end

  describe '#eligible_for_self_managed_gitlab_duo_pro?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:active_user) { create(:user) }
    let_it_be(:bot) { create(:user, :bot) }
    let_it_be(:ghost) { create(:user, :ghost) }
    let_it_be(:blocked_user) { create(:user, :blocked) }
    let_it_be(:banned_user) { create(:user, :banned) }
    let_it_be(:pending_approval_user) { create(:user, :blocked_pending_approval) }
    let_it_be(:group) { create(:group) }
    let_it_be(:guest_user) { create(:group_member, :guest, source: group).user }

    context 'when on gitlab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns false by default' do
        expect(active_user.eligible_for_self_managed_gitlab_duo_pro?).to be_falsey
      end
    end

    context 'when on self managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      # True for human users, excluding bots, blocked, banned, and pending_approval users.
      where(:user, :result) do
        ref(:bot)                     | false
        ref(:ghost)                   | false
        ref(:blocked_user)            | false
        ref(:banned_user)             | false
        ref(:pending_approval_user)   | false
        ref(:active_user)             | true
        ref(:guest_user)              | true
      end

      with_them do
        subject { user.eligible_for_self_managed_gitlab_duo_pro? }

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#gitlab_com_root_group_ids', :use_clean_rails_redis_caching do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:root_group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: root_group) }
    let_it_be(:group_project) { create(:project, group: root_group) }
    let_it_be(:sub_group_project) { create(:project, group: sub_group) }

    subject { user.gitlab_com_root_group_ids }

    context 'when on gitlab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      shared_examples 'excludes root group ids for banned user' do
        context 'when the user is banned' do
          let(:result) { [] }

          before do
            create(:namespace_ban, namespace: root_group, user: user)
          end

          it { is_expected.to eq(result) }
        end
      end

      where(:access_level, :include_group) do
        :guest      | true
        :reporter   | true
        :developer  | true
        :maintainer | true
        :owner      | true
      end

      with_them do
        let(:result) { include_group ? [root_group.id] : [] }

        context 'when the user is a member of the top level group' do
          before do
            root_group.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it 'caches the result' do
            user.gitlab_com_root_group_ids

            expect(
              Rails.cache.fetch(['users', user.id, described_class::ROOT_GROUP_IDS_CACHE_KEY])
            ).to eq(result)
          end
        end

        context 'when the user is a member of a sub group of the top level group' do
          before do
            sub_group.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it_behaves_like 'excludes root group ids for banned user'
        end

        context 'when the user is a member of a project within the top level group' do
          before do
            group_project.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it_behaves_like 'excludes root group ids for banned user'
        end

        context 'when the user is a member of a project within a sub group of the top level group' do
          before do
            sub_group_project.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it_behaves_like 'excludes root group ids for banned user'
        end

        context 'when the user is a member of an invited group' do
          let_it_be(:invited_group) { create(:group) }

          before do
            invited_group.add_member(user, access_level)
          end

          where(:shared_group_access_level, :include_group_via_link) do
            :guest      | false
            :reporter   | true
            :developer  | true
            :maintainer | true
            :owner      | true
          end

          context 'when the group is invited to a project' do
            with_them do
              let(:result) { include_group && include_group_via_link ? [root_group.id] : [] }

              before do
                create(:project_group_link, project: project, group: invited_group)
              end

              it { is_expected.to eq(result) }
            end
          end

          context 'when the group is invited to a group' do
            with_them do
              let(:result) { include_group && include_group_via_link ? [root_group.id] : [] }

              before do
                create(:group_group_link, shared_group: group, shared_with_group: invited_group)
              end

              it { is_expected.to eq(result) }
            end
          end
        end
      end
    end

    context 'when on self managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#duo_pro_cache_key_formatted' do
    it 'formats the cache key correctly' do
      formatted_cache_key = user.duo_pro_cache_key_formatted
      expected_cache_key = "user-#{user.id}-code-suggestions-add-on-cache"

      expect(formatted_cache_key).to eq(expected_cache_key)
    end
  end

  describe '.clear_group_with_ai_available_cache', :use_clean_rails_redis_caching do
    let_it_be(:other_user) { create(:user) }
    let_it_be(:yet_another_user) { create(:user) }
    let_it_be(:billable_groups_user) { create(:user) }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)

      user.any_group_with_ai_available?
      other_user.any_group_with_ai_available?

      billable_groups_user.gitlab_com_root_group_ids
    end

    it 'clears cache from users with the given ids', :aggregate_failures do
      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to be(false)
      expect(Rails.cache.fetch(['users', other_user.id, 'group_with_ai_enabled'])).to be(false)
      expect(Rails.cache.fetch(['users', billable_groups_user.id,
        described_class::ROOT_GROUP_IDS_CACHE_KEY])).to eq([])

      User.clear_group_with_ai_available_cache([user.id, yet_another_user.id, billable_groups_user.id])

      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to be_nil
      expect(Rails.cache.fetch(['users', other_user.id, 'group_with_ai_enabled'])).to be(false)
      expect(Rails.cache.fetch(['users', billable_groups_user.id,
        described_class::ROOT_GROUP_IDS_CACHE_KEY])).to be_nil
    end

    it 'clears cache when given a single id', :aggregate_failures do
      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to be(false)

      User.clear_group_with_ai_available_cache(user.id)

      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to be_nil
    end

    it 'does not clear the MCP server cache key' do
      cache_key = ['users', user.id, described_class::GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY]
      Rails.cache.write(cache_key, true)

      User.clear_group_with_ai_available_cache(user.id)

      expect(Rails.cache.fetch(cache_key)).to be(true)
    end
  end

  describe '.clear_group_with_mcp_server_enabled_cache', :use_clean_rails_redis_caching do
    let_it_be(:other_user) { create(:user) }

    let(:user_cache_key) { ['users', user.id, described_class::GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY] }
    let(:other_user_cache_key) { ['users', other_user.id, described_class::GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY] }

    before do
      Rails.cache.write(user_cache_key, true)
      Rails.cache.write(other_user_cache_key, true)
    end

    it 'clears the MCP cache only for the given ids', :aggregate_failures do
      User.clear_group_with_mcp_server_enabled_cache([user.id])

      expect(Rails.cache.fetch(user_cache_key)).to be_nil
      expect(Rails.cache.fetch(other_user_cache_key)).to be(true)
    end

    it 'accepts a single id' do
      User.clear_group_with_mcp_server_enabled_cache(user.id)

      expect(Rails.cache.fetch(user_cache_key)).to be_nil
    end

    it 'does not clear the AI cache keys', :aggregate_failures do
      ai_cache_key = ['users', user.id, described_class::GROUP_WITH_AI_ENABLED_CACHE_KEY]
      root_groups_cache_key = ['users', user.id, described_class::ROOT_GROUP_IDS_CACHE_KEY]
      Rails.cache.write(ai_cache_key, true)
      Rails.cache.write(root_groups_cache_key, [1])

      User.clear_group_with_mcp_server_enabled_cache(user.id)

      expect(Rails.cache.fetch(ai_cache_key)).to be(true)
      expect(Rails.cache.fetch(root_groups_cache_key)).to eq([1])
    end
  end

  describe '.duo_pro_cache_key_formatted' do
    it 'formats the cache key correctly' do
      formatted_cache_key = User.duo_pro_cache_key_formatted(123)
      expected_cache_key = 'user-123-code-suggestions-add-on-cache'

      expect(formatted_cache_key).to eq(expected_cache_key)
    end
  end

  describe '#default_duo_namespace' do
    it 'delegates to user_preference.duo_default_namespace_with_fallback' do
      expect(user.user_preference).to receive(:duo_default_namespace_with_fallback)

      user.default_duo_namespace
    end
  end

  describe '#code_suggestions_blocked_for?' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:root_group) { create(:group, developers: user) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be_with_reload(:project) { create(:project, group: subgroup) }

    context 'when not on SaaS' do
      before do
        root_group.namespace_settings.update!(duo_availability: "never_on")
      end

      it 'is not blocked, because the instance setting governs self-managed' do
        expect(user.code_suggestions_blocked_for?(project)).to be(false)
      end

      # The result is `false` with and without the `saas?` guard, so only a message
      # expectation can tell whether the guard still short-circuits.
      it 'does not resolve the governing namespace' do
        expect(user).not_to receive(:governing_namespace)

        user.code_suggestions_blocked_for?(project)
      end
    end

    context 'when on SaaS', :saas do
      context 'with a project' do
        # project_settings.duo_features_enabled is NOT NULL, so a project always has
        # its own value; Ai::CascadeDuoSettingsService writes the group's choice into
        # every descendant. These are the states a project is really in.
        it 'is blocked when the project has Duo turned off' do
          project.project_setting.update!(duo_features_enabled: false)

          expect(user.code_suggestions_blocked_for?(project)).to be(true)
        end

        it 'is not blocked when the project has Duo turned on' do
          project.project_setting.update!(duo_features_enabled: true)

          expect(user.code_suggestions_blocked_for?(project)).to be(false)
        end

        context 'when the root group is "Off by default" but the project opts back in' do
          before do
            root_group.namespace_settings.update!(duo_availability: "default_off")
            project.project_setting.update!(duo_features_enabled: true)
          end

          it 'is not blocked, because the setting is not locked' do
            expect(user.code_suggestions_blocked_for?(project)).to be(false)
          end
        end

        context 'when the root group is "Always off" and the project tries to opt back in' do
          before do
            root_group.namespace_settings.update!(duo_availability: "never_on")
          end

          it 'stays blocked, because the locked ancestor wins' do
            project.project_setting.update!(duo_features_enabled: true)

            expect(user.code_suggestions_blocked_for?(project)).to be(true)
          end
        end

        context 'when the project has Duo off but the default Duo namespace has it on' do
          let_it_be_with_reload(:other_root_group) { create(:group, developers: user) }

          before do
            allow(user.user_preference).to receive(:duo_default_namespace_with_fallback)
              .and_return(other_root_group)
            project.project_setting.update!(duo_features_enabled: false)
          end

          it 'is blocked, because the project the request is about wins' do
            expect(user.code_suggestions_blocked_for?(project)).to be(true)
          end
        end
      end

      context 'without a project' do
        before do
          allow(user).to receive(:governing_namespace).with(nil).and_return(governing_namespace)
        end

        context 'when the governing namespace has Duo turned off' do
          let(:governing_namespace) { root_group }

          before do
            root_group.namespace_settings.update!(duo_availability: "never_on")
          end

          it { expect(user.code_suggestions_blocked_for?(nil)).to be(true) }
        end

        context 'when the governing namespace has Duo turned on' do
          let(:governing_namespace) { root_group }

          it { expect(user.code_suggestions_blocked_for?(nil)).to be(false) }
        end

        context 'when there is no governing namespace' do
          let(:governing_namespace) { nil }

          it 'is not blocked, because the request cannot be attributed to a namespace' do
            expect(user.code_suggestions_blocked_for?(nil)).to be(false)
          end
        end
      end

      context 'when the feature flag is disabled for the governing namespace' do
        before do
          stub_feature_flags(block_code_suggestions_when_duo_disabled: create(:group))
          project.project_setting.update!(duo_features_enabled: false)
        end

        it 'is not blocked' do
          expect(user.code_suggestions_blocked_for?(project)).to be(false)
        end
      end
    end
  end

  describe '#governing_namespace' do
    let_it_be_with_refind(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:project) { create(:project, group: subgroup) }
    let_it_be(:default_namespace) { create(:group) }

    before do
      allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
    end

    context 'when scope is nil' do
      it 'returns the default duo namespace' do
        expect(user.governing_namespace).to eq(default_namespace)
      end

      context 'when ApplicationContext has a group' do
        before_all do
          root_group.add_developer(user)
        end

        it 'returns the root namespace of the context group when user is a member' do
          Gitlab::ApplicationContext.with_raw_context(group: subgroup.full_path) do
            expect(user.governing_namespace).to eq(root_group)
          end
        end

        it 'returns the default duo namespace when user is not a member of the context group' do
          other_group = create(:group)

          Gitlab::ApplicationContext.with_raw_context(group: other_group.full_path) do
            expect(user.governing_namespace).to eq(default_namespace)
          end
        end

        it 'returns the default duo namespace when the context group does not exist' do
          Gitlab::ApplicationContext.with_raw_context(group: 'non/existent/group') do
            expect(user.governing_namespace).to eq(default_namespace)
          end
        end
      end

      context 'when ApplicationContext has a project' do
        before_all do
          root_group.add_developer(user)
        end

        it 'returns the root namespace of the context project when user is a member' do
          Gitlab::ApplicationContext.with_raw_context(project: project.full_path) do
            expect(user.governing_namespace).to eq(root_group)
          end
        end

        it 'returns the default duo namespace when user is not a member of the context project namespace' do
          other_project = create(:project, group: create(:group))

          Gitlab::ApplicationContext.with_raw_context(project: other_project.full_path) do
            expect(user.governing_namespace).to eq(default_namespace)
          end
        end

        it 'returns the default duo namespace when the context project does not exist' do
          Gitlab::ApplicationContext.with_raw_context(project: 'non/existent/project') do
            expect(user.governing_namespace).to eq(default_namespace)
          end
        end
      end
    end

    context 'when scope is user ia a UserNamespace' do
      it 'returns the default duo namespace' do
        expect(user.governing_namespace(create(:namespace))).to eq(default_namespace)
      end
    end

    context 'when scope is provided' do
      context 'when user is a member of the root namespace' do
        before_all do
          root_group.add_developer(user)
        end

        it 'returns the root namespace of the scope' do
          expect(user.governing_namespace(project)).to eq(root_group)
        end

        it 'returns the root namespace when scope is a subgroup' do
          expect(user.governing_namespace(subgroup)).to eq(root_group)
        end

        it 'returns the root namespace when scope is the root group itself' do
          expect(user.governing_namespace(root_group)).to eq(root_group)
        end
      end

      context 'when user is not a member of the root namespace' do
        it 'returns the default duo namespace' do
          expect(user.governing_namespace(project)).to eq(default_namespace)
        end
      end
    end

    context 'when default_duo_namespace returns nil' do
      before do
        allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(nil)
      end

      it 'returns nil' do
        expect(user.governing_namespace).to be_nil
      end
    end
  end

  describe '#billable_duo_namespace' do
    let_it_be(:namespace) { create(:group) }

    before do
      allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(namespace)
    end

    it 'is an alias for governing_namespace' do
      expect(user.billable_duo_namespace).to eq(namespace)
      expect(user.billable_duo_namespace).to eq(user.governing_namespace)
    end

    it 'passes scope parameter through' do
      scope_group = create(:group)
      scope_group.add_developer(user)

      expect(user.billable_duo_namespace(scope_group)).to eq(scope_group)
      expect(user.billable_duo_namespace(scope_group)).to eq(user.governing_namespace(scope_group))
    end
  end

  describe '#duo_foundational_agents_container' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:organization) { create(:organization) }

    before do
      allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(namespace)
    end

    context 'on self-managed' do
      before do
        allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
        allow(::Organizations::Organization).to receive(:default_organization).and_return(organization)
      end

      it 'returns the default organization' do
        expect(user.duo_foundational_agents_container).to eq(organization)
      end

      it 'ignores the scope argument' do
        scope_group = create(:group)
        expect(user.duo_foundational_agents_container(scope_group)).to eq(organization)
      end
    end

    context 'on SaaS' do
      before do
        allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
      end

      it 'returns the governing namespace' do
        expect(user.duo_foundational_agents_container).to eq(namespace)
      end

      it 'passes the scope through to governing_namespace' do
        scope_group = create(:group)
        scope_group.add_developer(user)

        expect(user.duo_foundational_agents_container(scope_group)).to eq(scope_group)
      end
    end
  end

  describe '#foundational_agent_available?' do
    let_it_be(:organization) { create(:organization) }
    let(:container) { organization }

    context 'without a scope (global check)' do
      before do
        allow(user).to receive(:can?).with(:access_duo_agentic_chat, :global).and_return(agentic_allowed)
        allow(user).to receive(:duo_foundational_agents_container).with(nil).and_return(container)
        allow(container).to receive(:foundational_agent_enabled?).with('some_agent').and_return(agent_enabled)
      end

      subject { user.foundational_agent_available?('some_agent') }

      context 'when agentic mode is available and the agent is enabled' do
        let(:agentic_allowed) { true }
        let(:agent_enabled) { true }

        it { is_expected.to be(true) }
      end

      context 'when agentic mode is not available' do
        let(:agentic_allowed) { false }
        let(:agent_enabled) { true }

        it { is_expected.to be(false) }
      end

      context 'when the agent is disabled' do
        let(:agentic_allowed) { true }
        let(:agent_enabled) { false }

        it { is_expected.to be(false) }
      end

      context 'when there is no governing namespace (SaaS user without Duo)' do
        let(:container) { nil }
        let(:agentic_allowed) { true }
        let(:agent_enabled) { false }

        it { is_expected.to be(false) }
      end
    end

    context 'with a scope' do
      let_it_be(:group) { create(:group) }

      before do
        allow(user).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(agentic_allowed)
        allow(user).to receive(:duo_foundational_agents_container).with(group).and_return(container)
        allow(container).to receive(:foundational_agent_enabled?).with('some_agent').and_return(agent_enabled)
      end

      subject { user.foundational_agent_available?('some_agent', group) }

      context 'when agentic mode is available and the agent is enabled' do
        let(:agentic_allowed) { true }
        let(:agent_enabled) { true }

        it { is_expected.to be(true) }
      end

      context 'when agentic mode is not available for the scope' do
        let(:agentic_allowed) { false }
        let(:agent_enabled) { true }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '.allowed_to_use_through_namespace?' do
    let_it_be(:user) { create(:user) }

    before do
      allow(user).to receive(:check_access_through_namespace)
      .with(:duo_agent_platform, nil).and_return(check_response)
    end

    subject(:is_allowed) { user.allowed_to_use_through_namespace?(:duo_agent_platform) }

    context 'when check_access_through_namespace_at_instance is allowed' do
      let(:check_response) { described_class::Response.new(allowed?: true) }

      it { is_expected.to be true }
    end

    context 'when check_access_through_namespace_at_instance is false' do
      let(:check_response) { described_class::Response.new(allowed?: false) }

      it { is_expected.to be false }
    end

    context 'when check_access_through_namespace_at_instance is nil' do
      let(:check_response) { nil }

      it { is_expected.to be true }
    end
  end

  describe '#allowed_to_use_for_resource?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:resource) { create(:project, group: group) }

    let(:allowed_by_namespace_ids) { [group.id] }

    let(:allowed_response) do
      described_class::Response.new(
        allowed?: true,
        namespace_ids: allowed_by_namespace_ids,
        enablement_type: 'duo_pro',
        authorized_by_duo_core: false
      )
    end

    let(:denied_response) do
      described_class::Response.new(
        allowed?: false,
        namespace_ids: [],
        enablement_type: nil,
        authorized_by_duo_core: false
      )
    end

    before do
      allow(user).to receive(:allowed_to_use).and_return(allowed_response)
    end

    subject { user.allowed_to_use_for_resource?(:my_feature, resource: resource) }

    context 'when on Gitlab.com instance', :saas do
      shared_examples 'checking for fallback namespace' do
        let(:fallback_namespace) { build(:group) }

        context 'when user has duo_default_namespace' do
          before do
            allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(fallback_namespace)
          end

          it { is_expected.to be(true) }
        end

        context 'when user does not have duo_default_namespace' do
          it { is_expected.to be(false) }
        end
      end

      context 'when allowed_to_use returns allowed' do
        context 'when resource responds to root_ancestor' do
          context 'when resource root_ancestor is in allowed namespace_ids' do
            before do
              allow(allowed_response).to receive(:namespace_ids).and_return([group.id])
            end

            it { is_expected.to be(true) }
          end

          context 'when resource root_ancestor is not in allowed namespace_ids' do
            let(:allowed_by_namespace_ids) { [999] }

            it_behaves_like 'checking for fallback namespace'
          end
        end

        context 'when resource does not respond to root_ancestor' do
          let(:resource) { build(:user) }

          it_behaves_like 'checking for fallback namespace'
        end
      end

      context 'when allowed_to_use returns denied' do
        before do
          allow(user).to receive(:allowed_to_use).and_return(denied_response)
        end

        it { is_expected.to be(false) }
      end

      context 'when user has both Duo Core and Duo Pro subscriptions' do
        let_it_be(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
        let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

        let_it_be_with_refind(:duo_core_purchase) do
          create(:gitlab_subscription_add_on_purchase, add_on: duo_core_add_on)
        end

        let_it_be_with_refind(:duo_pro_purchase) do
          create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on)
        end

        let(:resource) { duo_core_purchase.namespace }

        subject(:result) { user.allowed_to_use_for_resource?(:duo_chat, resource: resource) }

        before do
          allow(user).to receive(:allowed_to_use).and_call_original

          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: duo_pro_purchase
          )
          [duo_core_purchase.namespace, duo_pro_purchase.namespace].each do |namespace|
            namespace.add_guest(user)
            namespace.namespace_settings.update!(duo_core_features_enabled: true)
          end
        end

        it 'returns true' do
          expect(result).to be(true)
        end
      end
    end

    context 'when on Self managed instance' do
      context 'when allowed_to_use returns allowed' do
        it { is_expected.to be(true) }
      end

      context 'when allowed_to_use returns denied' do
        before do
          allow(user).to receive(:allowed_to_use).and_return(denied_response)
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#get_self_hosted_feature_setting' do
    let_it_be(:user) { create(:user) }

    subject(:result) { user.send(:get_self_hosted_feature_setting, unit_primitive_name) }

    context 'when on SaaS', :saas do
      let(:unit_primitive_name) { :code_generations }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when on self-managed' do
      let(:unit_primitive_name) { :code_generations }

      it 'delegates to FeatureSetting.feature_for_unit_primitive' do
        expect(::Ai::FeatureSetting).to receive(:feature_for_unit_primitive).with(:code_generations)
        result
      end
    end
  end

  describe '#check_dap_self_hosted_feature' do
    let_it_be(:user) { create(:user) }
    let_it_be(:self_hosted_model) do
      create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
    end

    subject(:check_dap) { user.send(:check_dap_self_hosted_feature, feature_setting) }

    context 'when feature_setting is nil' do
      let(:feature_setting) { nil }

      it { is_expected.to be_nil }
    end

    context 'when feature_setting is not self-hosted' do
      let_it_be(:feature_setting) do
        build(:ai_feature_setting, feature: :code_generations, self_hosted_model: nil)
      end

      before do
        allow(feature_setting).to receive(:self_hosted?).and_return(false)
      end

      it { is_expected.to be_nil }
    end

    context 'when feature_setting is self-hosted but not a DAP feature' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, feature: :code_generations, self_hosted_model: self_hosted_model)
      end

      it { is_expected.to be_nil }
    end

    context 'when feature_setting is self-hosted DAP (duo_agent_platform)' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, feature: :duo_agent_platform, self_hosted_model: self_hosted_model)
      end

      context 'with offline cloud license' do
        let(:license_double) do
          instance_double(License, offline_cloud_license?: true, online_cloud_license?: false)
        end

        before do
          allow(License).to receive(:current).and_return(license_double)
        end

        context 'when no self-hosted DAP purchases exist' do
          let(:expected_allowed) { false }

          it { is_expected.to eq expected_response }
        end

        context 'when self-hosted DAP add-on exist' do
          let_it_be(:dap_add_on) { create(:gitlab_subscription_add_on, :self_hosted_dap) }
          let_it_be(:dap_purchase) do
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: dap_add_on)
          end

          let(:expected_allowed) { true }
          let(:expected_enablement_type) { "self_hosted_dap" }

          it { is_expected.to eq expected_response }
        end
      end

      context 'with online cloud license' do
        let(:expected_allowed) { true }
        let(:expected_enablement_type) { "self_hosted_usage_billing" }

        let(:license_double) do
          instance_double(License, offline_cloud_license?: false, online_cloud_license?: true)
        end

        it { is_expected.to eq expected_response }
      end
    end

    context 'when feature_setting is self-hosted DAP (duo_agent_platform_agentic_chat)' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, feature: :duo_agent_platform_agentic_chat, self_hosted_model: self_hosted_model)
      end

      let(:expected_allowed) { true }
      let(:expected_enablement_type) { "self_hosted_usage_billing" }

      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it { is_expected.to eq expected_response }
    end

    context 'when feature_setting is self-hosted code generation feature' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, feature: :code_generations, self_hosted_model: self_hosted_model)
      end

      context 'with online cloud license' do
        let(:expected_allowed) { true }
        let(:expected_enablement_type) { "self_hosted_usage_billing" }

        let(:license_double) do
          instance_double(License, offline_cloud_license?: false, online_cloud_license?: true)
        end

        before do
          allow(License).to receive(:current).and_return(license_double)
        end

        it { is_expected.to eq expected_response }
      end

      context 'without online cloud license' do
        let(:license_double) do
          instance_double(License, offline_cloud_license?: true, online_cloud_license?: false)
        end

        before do
          allow(License).to receive(:current).and_return(license_double)
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#check_access_through_namespace', :use_clean_rails_redis_caching do
    let_it_be(:user) { create(:user) }

    let(:feature_name) { :explain_vulnerability }
    let(:current_namespace) { nil }

    subject(:check) { user.check_access_through_namespace(feature_name, current_namespace) }

    context 'when ai_feature does not exist' do
      let(:feature_name) { :invalid_feature }

      it { is_expected.to be_nil }
    end

    context 'when on SaaS' do
      shared_examples 'checking namespace access rules', :request_store do
        context 'when namespace has group-based rules' do
          let_it_be_with_refind(:subgroup) { create(:group, parent: namespace_to_check) }

          let_it_be(:rule) do
            create(
              :ai_namespace_feature_access_rules,
              :duo_classic,
              root_namespace: namespace_to_check,
              through_namespace: subgroup
            )
          end

          context 'when user is part of group that gives them access' do
            before_all do
              subgroup.add_guest(user)
            end

            it 'returns allowed response' do
              expect(check).to be_allowed
              expect(check.namespace_ids).to match_array([namespace_to_check.id])

              cache_key = ['users', user.id, described_class::DUO_FEATURE_ENABLED_THROUGH_NAMESPACE_CACHE_KEY,
                namespace_to_check.id, :duo_classic]

              expect(Rails.cache.fetch(cache_key)).to be true
            end
          end

          context 'when user is not part of any configured group' do
            it { is_expected.not_to be_allowed }
          end
        end

        context 'when namespace does not have group-based rules' do
          it { is_expected.to be_nil }
        end
      end

      let_it_be(:default_namespace) { create(:group).tap { |ns| ns.add_guest(user) } }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when current namespace is provided' do
        let_it_be(:root_namespace) { create(:group) }

        let(:current_namespace) { root_namespace }

        context 'when user is part of current namespace' do
          before_all do
            root_namespace.add_guest(user)
          end

          it_behaves_like 'checking namespace access rules' do
            let_it_be(:namespace_to_check) { root_namespace }
          end
        end

        context 'when user is not part of current namespace' do
          context 'when user has default namespace' do
            before do
              allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
            end

            it_behaves_like 'checking namespace access rules' do
              let_it_be(:namespace_to_check) { default_namespace }
            end

            context 'when user does not have default namespace' do
              before do
                allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(nil)
              end

              it { is_expected.to be_nil }
            end
          end
        end
      end

      context 'when current namespace is not provided' do
        context 'when user has default namespace' do
          before do
            allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
          end

          it_behaves_like 'checking namespace access rules' do
            let_it_be(:namespace_to_check) { default_namespace }
          end

          context 'when user does not have default namespace' do
            before do
              allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(nil)
            end

            it { is_expected.to be_nil }
          end
        end
      end

      context 'when checking multiple features for the same namespace' do
        let_it_be(:root_namespace) { create(:group, guests: user) }
        let_it_be(:subgroup) { create(:group, parent: root_namespace, guests: user) }

        before do
          allow(user).to receive(:governing_namespace).and_return(root_namespace)

          create(
            :ai_namespace_feature_access_rules,
            :duo_classic,
            root_namespace: root_namespace,
            through_namespace: subgroup
          )
        end

        it 'does not issue additional queries after the first check', :request_store, :use_sql_query_cache do
          ApplicationRecord.uncached { user.check_access_through_namespace(:explain_vulnerability, root_namespace) }

          queries = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            ApplicationRecord.uncached { user.check_access_through_namespace(:summarize_review, root_namespace) }
          end

          expect(queries.count).to eq(0)
        end
      end
    end

    context 'when on self-managed' do
      let_it_be(:ns) { create(:group).tap { |n| n.add_guest(user) } }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when no rules exist' do
        it { is_expected.to be_nil }
      end

      context 'with existing rules' do
        let_it_be(:rule) do
          create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace: ns)
        end

        context 'when ai feature rules exist' do
          subject(:is_allowed) { check.allowed? }

          context 'when allowed by an existing rule' do
            it { is_expected.to be true }
          end

          context 'when no existing rules allow the user' do
            let(:feature_name) { :duo_workflow }

            it { is_expected.to be false }
          end
        end
      end
    end
  end

  describe '#duo_agent_platform_enabled_via_credits?' do
    subject(:result) { user.duo_agent_platform_enabled_via_credits? }

    context 'when self-managed' do
      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: nil)
        Ai::Setting.for_organization(user.organization).update!(duo_agent_platform_enabled: dap_enabled)
      end

      context 'when duo_agent_platform is enabled at the instance level' do
        let(:dap_enabled) { true }

        it { is_expected.to be true }
      end

      context 'when duo_agent_platform is disabled at the instance level' do
        let(:dap_enabled) { false }

        it { is_expected.to be false }
      end

      context 'when there are no credits purchases' do
        let(:dap_enabled) { true }

        before do
          GitlabSubscriptions::AddOnPurchase.for_gitlab_credits.delete_all
        end

        it { is_expected.to be false }
      end
    end

    context 'when SaaS', :saas do
      let_it_be(:group) { create(:group, developers: user) }
      let_it_be(:purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: group)
      end

      context 'when duo_agent_platform is enabled on the namespace' do
        before_all do
          create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: true })
        end

        it { is_expected.to be true }
      end

      context 'when duo_agent_platform is disabled on the namespace' do
        before_all do
          create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: false })
        end

        it { is_expected.to be false }
      end

      context 'when a purchase has a nil namespace' do
        before do
          nil_namespace_purchase = instance_double(GitlabSubscriptions::AddOnPurchase, namespace: nil)
          allow(user).to receive(:gitlab_credits_purchases).and_return([nil_namespace_purchase])
        end

        it { is_expected.to be false }
      end

      it 'does not cause N+1 queries when multiple purchases exist', :request_store, :use_sql_query_cache do
        gitlab_credits_add_on = purchase.add_on
        group2 = create(:group)
        group2.add_developer(user)
        create(:gitlab_subscription_add_on_purchase, :active, namespace: group2, add_on: gitlab_credits_add_on)
        create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: false })
        create(:namespace_ai_settings, namespace: group2, feature_settings: { duo_agent_platform_enabled: false })

        # Warm-up to flush one-time initialization queries
        ApplicationRecord.uncached { user.duo_agent_platform_enabled_via_credits? }
        user.remove_instance_variable(:@gitlab_credits_purchases)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          ApplicationRecord.uncached { user.duo_agent_platform_enabled_via_credits? }
        end

        group3 = create(:group)
        group3.add_developer(user)
        create(:gitlab_subscription_add_on_purchase, :active, namespace: group3, add_on: gitlab_credits_add_on)
        create(:namespace_ai_settings, namespace: group3, feature_settings: { duo_agent_platform_enabled: false })
        user.remove_instance_variable(:@gitlab_credits_purchases)

        expect do
          ApplicationRecord.uncached { user.duo_agent_platform_enabled_via_credits? }
        end.to issue_same_number_of_queries_as(control)
      end
    end
  end
end
