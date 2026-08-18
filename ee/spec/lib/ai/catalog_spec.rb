# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax

  describe '.available?' do
    let_it_be(:user) { create(:user) }

    subject(:available?) { described_class.available?(user) }

    context 'when SaaS', :saas do
      let_it_be(:non_member_group) do
        create(:group, namespace_settings: build(:namespace_settings, experiment_features_enabled: true))
      end

      where(:namespace_experiment_setting_enabled, :has_premium_plan, :duo_agent_platform_enabled, :is_available) do
        false | false | false | false
        true  | false | false | false
        true  | true  | false | false
        true  | true  | true  | true
      end
      with_them do
        let!(:member_group) do
          group = create(:group, guests: user, namespace_settings: build(:namespace_settings,
            experiment_features_enabled: namespace_experiment_setting_enabled
          ))

          if has_premium_plan
            create(:gitlab_subscription, namespace: group, hosted_plan: create(:premium_plan))
            group.reload
          end

          # Create ai_settings record when we need to test the explicit false case
          if has_premium_plan && !duo_agent_platform_enabled
            create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: false })
          elsif duo_agent_platform_enabled
            create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: true })
          end

          group
        end

        it { is_expected.to eq(is_available) }
      end

      context 'when caching behavior for duo_agent_platform_available' do
        let_it_be(:group) { create(:group, guests: user) }
        let(:cache_key) { "ai_catalog:duo_agent_platform_available:#{user.id}" }

        before do
          create(:gitlab_subscription, namespace: group, hosted_plan: create(:premium_plan))
          create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: true })
        end

        context 'when in production' do
          before do
            allow(Rails.env).to receive(:production?).and_return(true)
          end

          it 'caches the result for 30 minutes' do
            # Verify the method uses Rails.cache.fetch with correct expiration
            allow(Rails.cache).to receive(:fetch).and_call_original
            available?
            expect(Rails.cache).to have_received(:fetch).with(cache_key, expires_in: 30.minutes)
          end
        end

        context 'when in development' do
          before do
            allow(Rails.env).to receive(:production?).and_return(false)
          end

          it 'does not use cache for duo_agent_platform_available' do
            allow(Rails.cache).to receive(:fetch).and_call_original
            available?
            expect(Rails.cache).not_to have_received(:fetch).with(cache_key, anything)
          end
        end
      end

      context 'when free-tier namespace has an active gitlab_credits add-on' do
        let_it_be(:free_group) { create(:group, guests: user) }

        before do
          user.instance_variable_set(:@gitlab_credits_purchases, nil)

          create(:gitlab_subscription_add_on_purchase, :gitlab_credits, namespace: free_group)
          create(:namespace_ai_settings, namespace: free_group, feature_settings: { duo_agent_platform_enabled: true })
        end

        it { is_expected.to be(true) }

        context 'when duo_agent_platform_enabled is false' do
          before do
            free_group.ai_settings.update!(feature_settings: { duo_agent_platform_enabled: false })
          end

          it { is_expected.to be(false) }
        end
      end

      context 'when group has no ai_settings record' do
        let_it_be(:group) { create(:group, guests: user) }

        before do
          create(:gitlab_subscription, namespace: group, hosted_plan: create(:premium_plan))
          # Intentionally not creating ai_settings record
        end

        it 'defaults duo_agent_platform_enabled to true' do
          is_expected.to be(true)
        end
      end
    end

    context 'when not SaaS' do
      where(:instance_duo_features_enabled, :instance_duo_agent_platform_enabled, :allowed_to_use_through_membership) do
        false | false | true
        false | true  | true
        true  | false | true
        true  | true  | false
        true  | true  | true
      end

      with_them do
        let(:true_when_all_enabled) do
          instance_duo_features_enabled && instance_duo_agent_platform_enabled && allowed_to_use_through_membership
        end

        before do
          stub_application_setting(duo_features_enabled: instance_duo_features_enabled)

          # Create or update the AI setting with the desired duo_agent_platform_enabled value
          ai_setting = ::Ai::Setting.for_organization(user.organization)
          ai_setting.update!(feature_settings: { duo_agent_platform_enabled: instance_duo_agent_platform_enabled })

          membership_rule = create(
            :ai_instance_accessible_entity_rules,
            :duo_agent_platform
          )

          membership_rule.through_namespace.add_guest(user) if allowed_to_use_through_membership
        end

        it { is_expected.to eq(true_when_all_enabled) }
      end
    end
  end

  describe '.duo_agent_platform_enabled_for_user?' do
    let_it_be_with_refind(:user) { create(:user) }

    subject { described_class.send(:duo_agent_platform_enabled_for_user?, user) }

    context 'when self-managed with no credits purchase' do
      it { is_expected.to be(false) }
    end

    context 'when self-managed with an active credits purchase' do
      before do
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: nil)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.show_gitlab_mcp_server_tools?' do
    let_it_be(:user) { create(:user) }

    subject(:show_gitlab_mcp_server_tools?) { described_class.show_gitlab_mcp_server_tools?(user) }

    context 'when user is nil' do
      let(:user) { nil }

      it { is_expected.to be(false) }
    end

    context 'when SaaS', :saas do
      where(:any_group_with_mcp_server_enabled, :result) do
        true  | true
        false | false
      end

      with_them do
        before do
          allow(user).to receive(:any_group_with_mcp_server_enabled?)
            .and_return(any_group_with_mcp_server_enabled)
        end

        it { is_expected.to be(result) }
      end
    end

    context 'when not SaaS' do
      where(:instance_mcp_server_enabled, :result) do
        true  | true
        false | false
      end

      with_them do
        before do
          stub_application_setting(mcp_server_enabled: instance_mcp_server_enabled)
        end

        it { is_expected.to be(result) }
      end
    end
  end

  describe '.mcp_servers_available?' do
    let_it_be(:user) { create(:user) }

    subject(:mcp_servers_available?) { described_class.mcp_servers_available?(user) }

    context 'when SaaS', :saas do
      # rubocop:disable Layout/LineLength -- multiple lines makes this less readable
      where(:ai_catalog_mcp_servers_ff, :namespace_experiment_setting_enabled, :has_premium_plan, :duo_agent_platform_enabled, :is_available) do
        false | false | false | false | false
        false | true  | false | false | false
        false | true  | true  | false | false
        false | true  | true  | true  | false
        true  | false | false | false | false
        true  | false | true  | true  | false
        true  | true  | false | false | false
        true  | true  | true  | false | false
        true  | true  | true  | true  | true
      end
      # rubocop:enable Layout/LineLength

      with_them do
        let!(:member_group) do
          group = create(:group, guests: user, namespace_settings: build(:namespace_settings,
            experiment_features_enabled: namespace_experiment_setting_enabled
          ))

          if has_premium_plan
            create(:gitlab_subscription, namespace: group, hosted_plan: create(:premium_plan))
            group.reload
          end

          # Create ai_settings record when we need to test the explicit false case
          if has_premium_plan && !duo_agent_platform_enabled
            create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: false })
          elsif duo_agent_platform_enabled
            create(:namespace_ai_settings, namespace: group, feature_settings: { duo_agent_platform_enabled: true })
          end

          group
        end

        before do
          stub_feature_flags(ai_catalog_mcp_servers: ai_catalog_mcp_servers_ff)
        end

        it { is_expected.to eq(is_available) }
      end
    end

    context 'when not SaaS' do
      # rubocop:disable Layout/LineLength -- More readable on single lines
      where(:ai_catalog_mcp_servers_ff, :instance_duo_features_enabled, :instance_duo_agent_platform_enabled, :instance_experiment_setting_enabled, :allowed_to_use_through_membership) do
        false | false | false | false | true
        false | false | false | true  | true
        false | false | true  | false | true
        false | false | true  | true  | true
        false | true  | false | false | true
        false | true  | false | true  | true
        false | true  | true  | true  | false
        false | true  | true  | true  | true
        true  | false | false | false | true
        true  | false | false | true  | true
        true  | false | true  | false | true
        true  | false | true  | true  | true
        true  | true  | false | false | true
        true  | true  | false | true  | true
        true  | true  | true  | true  | false
        true  | true  | true  | true  | true
      end
      # rubocop:enable Layout/LineLength -- More readable on single lines

      with_them do
        let(:true_when_all_enabled) do
          ai_catalog_mcp_servers_ff && instance_duo_features_enabled &&
            instance_duo_agent_platform_enabled && instance_experiment_setting_enabled &&
            allowed_to_use_through_membership
        end

        before do
          stub_feature_flags(ai_catalog_mcp_servers: ai_catalog_mcp_servers_ff)
          stub_application_setting(duo_features_enabled: instance_duo_features_enabled)
          stub_application_setting(instance_level_ai_beta_features_enabled: instance_experiment_setting_enabled)

          # Create or update the AI setting with the desired duo_agent_platform_enabled value
          ai_setting = ::Ai::Setting.for_organization(user.organization)
          ai_setting.update!(feature_settings: { duo_agent_platform_enabled: instance_duo_agent_platform_enabled })

          membership_rule = create(
            :ai_instance_accessible_entity_rules,
            :duo_agent_platform
          )

          membership_rule.through_namespace.add_guest(user) if allowed_to_use_through_membership
        end

        it { is_expected.to eq(true_when_all_enabled) }
      end
    end
  end
end
