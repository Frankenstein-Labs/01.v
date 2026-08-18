# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::GroupDetail do
  describe 'unique_project_download_limit attributes', feature_category: :insider_threat do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    let(:feature_enabled) { true }

    subject { described_class.new(group, current_user: user).as_json }

    before do
      allow(group).to receive(:unique_project_download_limit_enabled?) { feature_enabled }

      group&.namespace_settings&.update!(
        unique_project_download_limit: 1,
        unique_project_download_limit_interval_in_seconds: 2,
        unique_project_download_limit_allowlist: [user.username],
        unique_project_download_limit_alertlist: [user.id],
        auto_ban_user_on_excessive_projects_download: true
      )
    end

    it 'exposes the attributes' do
      group.add_owner(user)

      expect(subject[:unique_project_download_limit]).to eq 1
      expect(subject[:unique_project_download_limit_interval_in_seconds]).to eq 2
      expect(subject[:unique_project_download_limit_allowlist]).to contain_exactly(user.username)
      expect(subject[:unique_project_download_limit_alertlist]).to contain_exactly(user.id)
      expect(subject[:auto_ban_user_on_excessive_projects_download]).to be true
    end

    shared_examples 'does not expose the attributes' do
      it 'does not expose the attributes' do
        expect(subject.keys).not_to include(
          :unique_project_download_limit,
          :unique_project_download_limit_interval,
          :unique_project_download_limit_allowlist,
          :unique_project_download_limit_alertlist,
          :auto_ban_user_on_excessive_projects_download
        )
      end
    end

    context 'when group has no associated settings record' do
      before do
        group.add_owner(user)
        group.namespace_settings.destroy!
        group.reload
      end

      it_behaves_like 'does not expose the attributes'
    end

    context 'when feature is not enabled' do
      let(:feature_enabled) { false }

      before do
        group.add_owner(user)
      end

      it_behaves_like 'does not expose the attributes'
    end

    context 'when user is not an owner' do
      before do
        group.add_maintainer(user)
      end

      it_behaves_like 'does not expose the attributes'
    end
  end

  describe 'service_account_tokens_expiration_enforced' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:service_account_user) { create(:user, :service_account) }

    subject(:group_detail_entity) { described_class.new(group, current_user: service_account_user).as_json }

    before do
      group.namespace_settings.update!(service_access_tokens_expiration_enforced: false)
    end

    it 'exposes attributes' do
      expect(group_detail_entity[:service_access_tokens_expiration_enforced]).to be(false)
    end

    context 'when not root group' do
      before do
        group.parent = create(:group)
        group.save!
      end

      it 'does not expose the attributes' do
        expect(group_detail_entity.keys).not_to include(:service_access_tokens_expiration_enforced)
      end
    end
  end

  describe 'allowed_email_domains_list' do
    let_it_be(:owner) { create(:user) }
    let_it_be(:guest) { create(:user) }
    let_it_be_with_reload(:group) do
      create(:group, owners: owner, guests: guest) do |group|
        update_group_attrs(group, owner, { allowed_email_domains_list: "example.com,example.org" })
      end
    end

    let(:user) { guest }

    subject { described_class.new(group, current_user: user).as_json }

    context 'when allowed_email_domains feature is not enabled' do
      it 'does not expose allowed_email_domains_list attr' do
        expect(subject.keys).not_to include(:allowed_email_domains_list)
      end
    end

    context 'when allowed_email_domains feature is enabled' do
      before do
        stub_licensed_features(group_allowed_email_domains: true)
      end

      it 'exposes the allowed_email_domains_list attr' do
        expect(subject[:allowed_email_domains_list]).to eq("example.com,example.org")
      end
    end
  end

  describe 'ip_restriction_ranges attribute' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    subject { described_class.new(group, current_user: user).as_json }

    before do
      update_group_attrs(group, user, { ip_restriction_ranges: "192.168.0.0/24,10.0.0.0/8" })
    end

    context 'when ip_restriction feature is enabled' do
      before do
        stub_licensed_features(group_ip_restriction: true)
      end

      it 'exposes the attributes' do
        expect(subject[:ip_restriction_ranges]).to eq("192.168.0.0/24,10.0.0.0/8")
      end
    end

    context 'when ip_restriction feature is not enabled' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'does not expose ip_restriction_ranges attributes' do
        expect(subject.keys).not_to include(
          :ip_restriction_ranges
        )
      end

      context 'for instances that have the usage_ping_features activated' do
        before do
          stub_application_setting(usage_ping_enabled: true)
          stub_application_setting(usage_ping_features_enabled: true)
        end

        it 'exposes the attributes' do
          expect(subject[:ip_restriction_ranges]).to eq("192.168.0.0/24,10.0.0.0/8")
        end
      end
    end
  end

  describe 'merge request settings' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    subject { described_class.new(group, current_user: user).as_json }

    before do
      group.add_owner(user)
    end

    context 'with group_level_merge_checks_setting license' do
      before do
        stub_licensed_features(group_level_merge_checks_setting: true)
        group.namespace_settings.update!(
          only_allow_merge_if_pipeline_succeeds: true,
          allow_merge_on_skipped_pipeline: false,
          only_allow_merge_if_all_discussions_are_resolved: true
        )
      end

      it 'exposes merge request settings' do
        expect(subject[:only_allow_merge_if_pipeline_succeeds]).to be(true)
        expect(subject[:allow_merge_on_skipped_pipeline]).to be(false)
        expect(subject[:only_allow_merge_if_all_discussions_are_resolved]).to be(true)
      end
    end

    context 'without group_level_merge_checks_setting license' do
      before do
        stub_licensed_features(group_level_merge_checks_setting: false)
        group.namespace_settings.update!(
          only_allow_merge_if_pipeline_succeeds: true,
          allow_merge_on_skipped_pipeline: false,
          only_allow_merge_if_all_discussions_are_resolved: true
        )
      end

      it 'does not expose merge request settings' do
        expect(subject.keys).not_to include(
          :only_allow_merge_if_pipeline_succeeds,
          :allow_merge_on_skipped_pipeline,
          :only_allow_merge_if_all_discussions_are_resolved
        )
      end
    end

    context 'when group has no associated settings record' do
      before do
        stub_licensed_features(group_level_merge_checks_setting: true)
        group.namespace_settings.destroy!
        group.reload
      end

      it 'does not expose merge request settings' do
        expect(subject[:only_allow_merge_if_pipeline_succeeds]).to be_nil
        expect(subject[:allow_merge_on_skipped_pipeline]).to be_nil
        expect(subject[:only_allow_merge_if_all_discussions_are_resolved]).to be_nil
      end
    end
  end

  describe 'experiment_features_enabled', feature_category: :ai_abstraction_layer do
    let_it_be_with_reload(:group) { create(:group) }

    let(:user) { create(:user, developer_of: group) }

    subject(:json) { described_class.new(group, current_user: user).as_json }

    context 'when the licensed_ai_features are not available' do
      it 'does not expose experiment_features_enabled' do
        expect(json.keys).not_to include(:experiment_features_enabled)
      end
    end

    context 'when the licensed_ai_features are available' do
      before do
        stub_licensed_features(ai_features: true)
      end

      it 'exposes experiment_features_enabled' do
        expect(json.keys).to include(:experiment_features_enabled)
      end

      context 'on SaaS', :saas do
        it 'returns the governing namespace setting value when enabled' do
          group.namespace_settings.update!(experiment_features_enabled: true)

          expect(json[:experiment_features_enabled]).to be(true)
        end

        it 'returns the governing namespace setting value when disabled' do
          group.namespace_settings.update!(experiment_features_enabled: false)

          expect(json[:experiment_features_enabled]).to be(false)
        end

        context 'when user is not a member of the group hierarchy' do
          let(:user) { create(:user) }

          it 'returns false' do
            group.namespace_settings.update!(experiment_features_enabled: true)

            expect(json[:experiment_features_enabled]).to be(false)
          end
        end
      end

      context 'on self-managed' do
        it 'returns the instance-level setting value when enabled' do
          stub_application_setting(instance_level_ai_beta_features_enabled: true)

          expect(json[:experiment_features_enabled]).to be(true)
        end

        it 'returns the instance-level setting value when disabled' do
          stub_application_setting(instance_level_ai_beta_features_enabled: false)

          expect(json[:experiment_features_enabled]).to be(false)
        end
      end

      context 'on Dedicated' do
        before do
          stub_application_setting(gitlab_dedicated_instance: true)
        end

        it 'returns the instance-level setting value when enabled' do
          stub_application_setting(instance_level_ai_beta_features_enabled: true)

          expect(json[:experiment_features_enabled]).to be(true)
        end

        it 'returns the instance-level setting value when disabled' do
          stub_application_setting(instance_level_ai_beta_features_enabled: false)

          expect(json[:experiment_features_enabled]).to be(false)
        end
      end

      context 'when user is nil' do
        let(:user) { nil }

        it 'does not expose experiment_features_enabled' do
          expect(json.keys).not_to include(:experiment_features_enabled)
        end
      end
    end
  end

  def update_group_attrs(group, user, params)
    ::Groups::UpdateService.new(group, user, params).execute
  end
end
