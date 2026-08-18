# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NamespaceSetting, feature_category: :groups_and_projects, type: :model do
  using RSpec::Parameterized::TableSyntax

  let(:group) { create(:group) }
  let(:setting) { group.namespace_settings }

  describe 'enums' do
    it 'defines an enum for enabled_git_access_protocol' do
      is_expected.to define_enum_for(
        :enabled_git_access_protocol
      ).with_values([:all, :ssh, :http]).with_suffix
    end
  end

  describe 'scopes' do
    describe '.requiring_dormant_member_review', :freeze_time do
      it 'returns settings with feature enabled requiring review' do
        setting_never_reviewed = create(:namespace_settings, remove_dormant_members: true, last_dormant_member_review_at: nil)
        setting_reviewed_19_hours_ago = create(:namespace_settings, remove_dormant_members: true, last_dormant_member_review_at: 19.hours.ago)
        create(:namespace_settings, last_dormant_member_review_at: 18.hours.ago) # exactly 18 hours ago
        create(:namespace_settings, remove_dormant_members: false) # feature is disabled

        expect(described_class.requiring_dormant_member_review(3))
          .to contain_exactly(setting_never_reviewed, setting_reviewed_19_hours_ago)
      end
    end

    describe '.order_by_last_dormant_member_review_asc' do
      let_it_be(:setting_never_reviewed) { create(:namespace_settings, last_dormant_member_review_at: nil) }
      let_it_be(:setting_reviewed) { create(:namespace_settings, last_dormant_member_review_at: 2.days.ago) }

      it 'orders results by last_dormant_member_review_at ASC, nulls first' do
        expect(described_class.order_by_last_dormant_member_review_asc)
          .to eq([setting_never_reviewed, setting_reviewed])
      end
    end
  end

  describe 'validations' do
    subject(:settings) { group.namespace_settings }

    it { is_expected.to validate_presence_of(:unique_project_download_limit) }
    it { is_expected.to validate_presence_of(:unique_project_download_limit_interval_in_seconds) }

    it do
      is_expected.to validate_numericality_of(:unique_project_download_limit)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(10_000)
    end

    it do
      is_expected.to validate_numericality_of(:unique_project_download_limit_interval_in_seconds)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(10.days.to_i)
    end

    describe 'experiment features' do
      let(:attr) { :experiment_features_enabled }

      before do
        allow(subject).to receive(:experiment_settings_allowed?).and_return(true)
      end

      it 'allows changing experiment_features_enabled' do
        subject[attr] = !subject[attr]

        expect(subject).to be_valid
      end

      context 'when experiment settings are not allowed' do
        before do
          allow(subject).to receive(:experiment_settings_allowed?).and_return(false)
        end

        it 'does not allow changing experiment_features_enabled' do
          subject[attr] = !subject[attr]

          expect(subject).not_to be_valid
          expect(subject.errors[attr].first).to include("Experiment features' settings not allowed.")
        end
      end
    end

    describe 'unique_project_download_limit_allowlist', feature_category: :insider_threat do
      let_it_be(:user) { create(:user) }

      let(:attr) { :unique_project_download_limit_allowlist }

      it { is_expected.to allow_value([]).for(attr) }
      it { is_expected.to allow_value([user.username]).for(attr) }
      it { is_expected.not_to allow_value(nil).for(attr) }
      it { is_expected.not_to allow_value(['unknown_user']).for(attr) }

      context 'when maximum length is exceeded' do
        it 'is not valid' do
          subject.unique_project_download_limit_allowlist = generate_list(:username, 101)

          expect(subject).not_to be_valid
          expect(subject.errors[attr]).to include("exceeds maximum length (100 usernames)")
        end
      end
    end

    describe 'unique_project_download_limit_alertlist', feature_category: :insider_threat do
      let_it_be(:user) { create(:user) }

      let(:attr) { :unique_project_download_limit_alertlist }

      it { is_expected.to allow_value([]).for(attr) }
      it { is_expected.to allow_value([user.id]).for(attr) }
      it { is_expected.to allow_value(nil).for(attr) }
      it { is_expected.not_to allow_value([non_existing_record_id]).for(attr) }

      context 'when maximum length is exceeded' do
        it 'is not valid' do
          subject.unique_project_download_limit_alertlist = Array.new(101)

          expect(subject).not_to be_valid
          expect(subject.errors[attr]).to include('exceeds maximum length (100 user ids)')
        end

        context 'when empty' do
          let(:active_user) { create(:user) }
          let(:inactive_user) { create(:user, :deactivated) }

          before do
            group.add_owner(active_user)
            group.add_owner(inactive_user)
          end

          it 'returns the user ids of the active group owners' do
            expect(subject.unique_project_download_limit_alertlist).to contain_exactly(active_user.id)
          end
        end

        context 'when not empty' do
          let(:alerted_user_ids) { [1, 2] }

          before do
            subject.update_attribute(:unique_project_download_limit_alertlist, alerted_user_ids)
          end

          it 'returns the set user ids' do
            expect(subject.unique_project_download_limit_alertlist).to eq(alerted_user_ids)
          end
        end
      end
    end

    describe 'new_user_signups_cap', :saas do
      # rubocop:disable Rails/SaveBang -- Testing validations
      describe 'validations' do
        context 'when seat_control is user_cap' do
          it 'is invalid when set to nil' do
            settings.update(seat_control: :user_cap, new_user_signups_cap: nil)

            expect(settings.errors.messages[:new_user_signups_cap]).to eq(["is not a number"])
          end

          it 'must be a positive number' do
            settings.update(seat_control: :user_cap, new_user_signups_cap: -1)

            expect(settings.errors.messages[:new_user_signups_cap]).to eq(["must be greater than or equal to 0"])
          end

          it 'must be an integer' do
            settings.update(seat_control: :user_cap, new_user_signups_cap: 2.5)

            expect(settings.errors.messages[:new_user_signups_cap]).to eq(["must be an integer"])
          end

          it 'is valid when it is a positive integer' do
            settings.update(seat_control: :user_cap, new_user_signups_cap: 1)

            expect(settings).to be_valid
          end
        end

        context 'when seat_control is off' do
          it 'can be nil' do
            settings.update(seat_control: :off, new_user_signups_cap: nil)

            expect(settings).to be_valid
          end

          it 'can be set' do
            settings.update(seat_control: :off, new_user_signups_cap: 4)

            expect(settings).to be_valid
          end
        end
      end
      # rubocop:enable Rails/SaveBang

      it 'is set to nil when seat_control is off' do
        settings.update!(seat_control: :off, new_user_signups_cap: 5)

        expect(settings.new_user_signups_cap).to be_nil
      end

      it 'is unchanged when seat_control is user_cap' do
        settings.update!(seat_control: :user_cap, new_user_signups_cap: 5)

        expect(settings.new_user_signups_cap).to eq(5)
      end
    end

    describe 'duo_core_features_enabled' do
      context 'with a new record' do
        it 'returns nil as default value' do
          expect(settings.duo_core_features_enabled).to be_nil
        end

        it 'returns nil as default value for sub-group' do
          settings = create(:group, parent: group).namespace_settings

          expect(settings.duo_core_features_enabled).to be_nil
        end
      end

      context 'with an existing record' do
        it 'accepts only boolean values for update' do
          settings.update!(duo_core_features_enabled: true)
          expect(settings).to be_valid

          settings.update!(duo_core_features_enabled: false)
          expect(settings).to be_valid

          settings.duo_core_features_enabled = nil
          expect(settings).to be_invalid
        end

        it 'does not allow update for non root group' do
          settings = create(:group, parent: group).namespace_settings

          settings.duo_core_features_enabled = true
          expect(settings).to be_invalid
        end
      end
    end

    describe 'duo_nano_features_enabled' do
      context 'with a new record' do
        it 'returns nil as default value' do
          expect(settings.duo_nano_features_enabled).to be_nil
        end

        it 'returns nil as default value for sub-group' do
          settings = create(:group, parent: group).namespace_settings

          expect(settings.duo_nano_features_enabled).to be_nil
        end
      end

      context 'with an existing record' do
        it 'accepts only boolean values for update' do
          settings.update!(duo_nano_features_enabled: true)
          expect(settings).to be_valid

          settings.update!(duo_nano_features_enabled: false)
          expect(settings).to be_valid

          settings.duo_nano_features_enabled = nil
          expect(settings).to be_invalid
        end

        it 'does not allow update for non root group' do
          settings = create(:group, parent: group).namespace_settings

          settings.duo_nano_features_enabled = true
          expect(settings).to be_invalid
        end
      end
    end

    describe 'remove_dormant_members' do
      let(:subgroup) { create(:group, :nested) }

      it { expect(subgroup.namespace_settings).to validate_inclusion_of(:remove_dormant_members).in_array([false]) }
    end

    describe 'remove_dormant_members_period' do
      it do
        expect(settings).to validate_numericality_of(:remove_dormant_members_period)
          .only_integer
          .is_greater_than_or_equal_to(90)
          .is_less_than_or_equal_to(1827)
      end
    end

    describe 'display_gitlab_credits_user_data' do
      it 'validates display_gitlab_credits_user_data' do
        expect(settings).to validate_inclusion_of(:display_gitlab_credits_user_data)
          .in_array([true, false])
      end

      it 'defaults to true' do
        new_settings = build(:namespace_settings)

        expect(new_settings.display_gitlab_credits_user_data).to be true
      end
    end

    describe 'dependency_firewall_enabled' do
      it 'validates dependency_firewall_enabled' do
        expect(settings).to validate_inclusion_of(:dependency_firewall_enabled)
          .in_array([true, false])
      end

      it 'is invalid when set to nil' do
        expect(settings).not_to allow_value(nil).for(:dependency_firewall_enabled)
      end

      it 'defaults to false' do
        new_settings = build(:namespace_settings)

        expect(new_settings.dependency_firewall_enabled).to be false
      end
    end

    describe 'for enterprise_user_settings', feature_category: :user_management do
      subject(:namespace_settings) { build(:namespace_settings) }

      it 'allows allow_enterprise_user_account_deletion with true' do
        is_expected.to allow_value({ allow_enterprise_user_account_deletion: true })
          .for(:enterprise_user_settings)
      end

      it 'allows allow_enterprise_user_account_deletion with false' do
        is_expected.to allow_value({ allow_enterprise_user_account_deletion: false })
          .for(:enterprise_user_settings)
      end

      it 'does not allow additional properties' do
        is_expected.not_to allow_value({ unknown_key: true })
          .for(:enterprise_user_settings)
      end

      it 'defaults allow_enterprise_user_account_deletion to true' do
        expect(namespace_settings.allow_enterprise_user_account_deletion).to be(true)
      end
    end
  end

  describe 'after_commit' do
    context 'for trigger_todo_creation' do
      let(:gitlab_duo_saas_only_enabled) { true }

      before do
        stub_saas_features(gitlab_duo_saas_only: gitlab_duo_saas_only_enabled)
      end

      context 'on update' do
        let_it_be_with_reload(:setting) { create(:namespace_settings, namespace: build(:group)) }

        it 'triggers the todo creation' do
          expect(GitlabSubscriptions::GitlabCom::DuoCoreTodoNotificationWorker)
            .to receive(:perform_in).with(7.days, setting.namespace_id)

          setting.update!(duo_core_features_enabled: true)
        end

        context 'when duo core features are disabled' do
          it 'does not trigger the todo creation for nil update' do
            expect(GitlabSubscriptions::GitlabCom::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

            setting.update!(duo_core_features_enabled: false)
          end

          context 'when changed from true to false' do
            before do
              setting.update!(duo_core_features_enabled: true)
            end

            it 'does not trigger the todo creation' do
              expect(GitlabSubscriptions::GitlabCom::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

              setting.update!(duo_core_features_enabled: false)
            end
          end
        end

        context 'when gitlab_duo_saas_only feature is not available' do
          let(:gitlab_duo_saas_only_enabled) { false }

          it 'does not trigger the todo creation' do
            expect(GitlabSubscriptions::GitlabCom::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

            setting.update!(duo_core_features_enabled: true)
          end
        end

        context 'when it is a different column update' do
          it 'does not trigger the todo creation' do
            expect(GitlabSubscriptions::GitlabCom::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

            setting.update!(default_branch_name: 'foo')
          end
        end
      end

      context 'on create' do
        it 'does not trigger the todo creation' do
          expect(GitlabSubscriptions::GitlabCom::DuoCoreTodoNotificationWorker).not_to receive(:perform_in)

          create(:namespace_settings, namespace: build(:group), duo_core_features_enabled: true)
        end
      end
    end

    context 'for track_restricted_access_disabled' do
      let_it_be_with_reload(:setting) { create(:namespace_settings, namespace: build(:group), seat_control: :block_overages) }

      context 'on update' do
        it 'tracks restricted_access_disabled event when seat_control changes to off' do
          expect(Gitlab::InternalEvents).to receive(:track_event).with(
            'restricted_access_disabled',
            namespace: setting.namespace,
            additional_properties: hash_including(
              subscription_tier: nil,
              seat_count: nil
            )
          )

          setting.update!(seat_control: :off)
        end

        it 'does not track event when other attributes change' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          setting.update!(default_branch_name: 'foo')
        end
      end

      context 'on create' do
        it 'does not track event' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          create(:namespace_settings, namespace: build(:group), seat_control: :off)
        end
      end
    end

    context 'for track_restricted_access_enabled' do
      let_it_be_with_reload(:setting) { create(:namespace_settings, namespace: build(:group), seat_control: :off) }

      context 'on update' do
        it 'tracks restricted_access_enabled event when seat_control changes to block_overages' do
          expect(Gitlab::InternalEvents).to receive(:track_event).with(
            'restricted_access_enabled',
            namespace: setting.namespace,
            additional_properties: hash_including(
              subscription_tier: nil,
              seat_count: nil
            )
          )

          setting.update!(seat_control: :block_overages)
        end

        it 'does not track event when other attributes change' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          setting.update!(default_branch_name: 'foo')
        end
      end

      context 'on create' do
        it 'does not track event' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          create(:namespace_settings, namespace: build(:group), seat_control: :block_overages)
        end
      end
    end
  end

  describe '.duo_features_set' do
    let_it_be(:setting_1) { create(:namespace_settings, duo_features_enabled: true) }
    let_it_be(:setting_2) { create(:namespace_settings, duo_features_enabled: false) }

    subject { described_class.duo_features_set(true) }

    it { is_expected.to contain_exactly(setting_1) }
  end

  describe '#prevent_forking_outside_group?' do
    context 'with feature available' do
      before do
        stub_licensed_features(group_forking_protection: true)
      end

      context 'when group has no associated saml provider' do
        before do
          setting.update!(prevent_forking_outside_group: true)
        end

        it 'returns namespace setting' do
          expect(setting.prevent_forking_outside_group?).to be(true)
        end
      end

      context 'when group has associated saml provider' do
        before do
          stub_licensed_features(group_saml: true, group_forking_protection: true)
        end

        context 'when it is configured to true on saml level' do
          before do
            setting.update!(prevent_forking_outside_group: true)
            create(:saml_provider, :enforced_group_managed_accounts, prohibited_outer_forks: true, group: group)
          end

          it 'returns true' do
            expect(setting.prevent_forking_outside_group?).to be(true)
          end
        end

        context 'when it is configured to false on saml level' do
          before do
            create(:saml_provider, :enforced_group_managed_accounts, prohibited_outer_forks: false, group: group)
          end

          it 'returns false' do
            expect(setting.prevent_forking_outside_group?).to be(false)
          end

          context 'when setting is configured on namespace level' do
            before do
              setting.update!(prevent_forking_outside_group: true)
            end

            it 'returns namespace setting' do
              expect(setting.prevent_forking_outside_group?).to be(true)
            end
          end
        end
      end
    end

    context 'without feature available' do
      before do
        setting.update!(prevent_forking_outside_group: true)
      end

      it 'returns false' do
        expect(setting.prevent_forking_outside_group?).to be_falsey
      end

      context 'when saml setting is available' do
        before do
          stub_licensed_features(group_saml: true)
        end

        context 'when it is configured to true on saml level' do
          before do
            create(:saml_provider, :enforced_group_managed_accounts, prohibited_outer_forks: true, group: group)
          end

          it 'returns true' do
            expect(setting.prevent_forking_outside_group?).to be(true)
          end
        end

        context 'when it is configured to false on saml level' do
          before do
            create(:saml_provider, :enforced_group_managed_accounts, prohibited_outer_forks: false, group: group)
          end

          it 'returns false' do
            expect(setting.prevent_forking_outside_group?).to be(false)
          end
        end
      end
    end
  end

  describe '#require_dpop_for_manage_api_endpoints?' do
    context 'when require_dpop_for_manage_api_endpoints = true' do
      before do
        setting.require_dpop_for_manage_api_endpoints = true
      end

      it 'returns true' do
        expect(setting.require_dpop_for_manage_api_endpoints?).to be(true)
      end
    end

    context 'when require_dpop_for_manage_api_endpoints = false' do
      before do
        setting.require_dpop_for_manage_api_endpoints = false
      end

      it 'returns false' do
        expect(setting.require_dpop_for_manage_api_endpoints?).to be(false)
      end
    end
  end

  describe "#disable_invite_members" do
    context 'when disable_invite_members = true' do
      before do
        setting.disable_invite_members = true
      end

      it 'returns true' do
        expect(setting.disable_invite_members?).to be(true)
      end
    end

    context 'when disable_invite_members = false' do
      before do
        setting.disable_invite_members = false
      end

      it 'returns false' do
        expect(setting.disable_invite_members?).to be(false)
      end
    end
  end

  describe '#user_cap_enabled?', feature_category: :consumables_cost_management do
    where(:seat_control, :new_user_signups_cap, :root_namespace, :expectation) do
      :off      | nil | false | false
      :off      | nil | true  | false
      :off      | 10  | false | false
      :off      | 10  | true  | false
      :user_cap | 10  | false | false
      :user_cap | 10  | true  | true
    end

    with_them do
      let(:setting) { build(:namespace_settings, seat_control: seat_control, new_user_signups_cap: new_user_signups_cap) }
      let(:group) { build(:group, namespace_settings: setting) }

      before do
        allow(group).to receive(:root?).and_return(root_namespace)
      end

      it 'returns the expected response' do
        expect(setting.user_cap_enabled?).to be expectation
      end
    end
  end

  describe '#duo_availability' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_features_enabled, :duo_features_enabled_locked, :expectation) do
      true  | true  | :always_on
      true  | false | :default_on
      false | false | :default_off
      false | true  | :never_on
    end

    with_them do
      before do
        setting.duo_features_enabled = duo_features_enabled
        allow(setting).to receive(:duo_features_enabled_locked?).with(include_self: true).and_return(duo_features_enabled_locked)
      end

      it 'returns the expected response' do
        expect(setting.duo_availability).to eq(expectation)
      end
    end

    context 'when value is "never_on"' do
      it 'sets experiment_features_enabled to false' do
        setting.duo_availability = "never_on"

        expect(setting.experiment_features_enabled).to be false
      end
    end
  end

  # Shared guard behaviour for the compound `*_availability=` setters, which write both
  # the `_enabled` and `lock_*_enabled` columns. The setter must be a no-op when the
  # attribute is locked by an ancestor group or an instance-level application setting,
  # and write normally otherwise.
  #
  # `setter` defaults to the `#{base_name}_availability=` convention; pass it explicitly
  # when the method name differs (e.g. `duo_availability=`). `availability_value` is any
  # value that writes the columns when unguarded; `expected_enabled`/`expected_lock` are
  # the resulting column values.
  shared_examples 'a guarded duo availability setter' do |base_name:, setter: :"#{base_name}_availability=",
    availability_value: true, expected_enabled: true, expected_lock: false|
    attr = :"#{base_name}_enabled"
    lock_attr = :"lock_#{base_name}_enabled"

    context 'when locked by an ancestor group' do
      let_it_be_with_reload(:parent_group) { create(:group) }
      let_it_be_with_reload(:child_group) { create(:group, parent: parent_group) }
      let(:child_setting) { child_group.namespace_settings }

      before do
        parent_group.namespace_settings.update_columns(
          attr => false,
          lock_attr => true
        )
      end

      it 'is a no-op and does not write any columns', :aggregate_failures do
        expect { child_setting.public_send(setter, availability_value) }
          .to not_change { child_setting.public_send(attr) }
          .and not_change { child_setting.public_send(lock_attr) }
      end
    end

    context 'when locked by an instance-level application setting' do
      before do
        stub_application_setting(attr => false, lock_attr => true)
      end

      it 'is a no-op and does not write any columns', :aggregate_failures do
        expect { setting.public_send(setter, availability_value) }
          .to not_change { setting.public_send(attr) }
          .and not_change { setting.public_send(lock_attr) }
      end
    end

    context 'when nothing above the group holds the lock' do
      it 'writes both columns', :aggregate_failures do
        setting.public_send(setter, availability_value)

        expect(setting.public_send(attr)).to be(expected_enabled)
        expect(setting.public_send(lock_attr)).to be(expected_lock)
      end
    end
  end

  describe '#duo_availability=' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_availability, :duo_features_enabled_expectation, :lock_duo_features_enabled_expectation) do
      "always_on"   | true  | true
      "default_on"  | true  | false
      "default_off" | false | false
      "never_on"    | false | true
    end

    with_them do
      before do
        setting.duo_availability = duo_availability
      end

      it 'returns the expected response' do
        expect(setting.duo_features_enabled).to be duo_features_enabled_expectation
        expect(setting.lock_duo_features_enabled).to be lock_duo_features_enabled_expectation
      end
    end

    it_behaves_like 'a guarded duo availability setter',
      base_name: :duo_features,
      setter: :"duo_availability=",
      availability_value: "always_on",
      expected_lock: true
  end

  describe '#duo_remote_flows_availability=' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_remote_flows_availability, :duo_remote_flows_enabled_expectation, :lock_duo_remote_flows_enabled_expectation) do
      true  | true  | false
      false | false | true
    end

    with_them do
      before do
        setting.duo_remote_flows_availability = duo_remote_flows_availability
      end

      it 'returns the expected response' do
        expect(setting.duo_remote_flows_enabled).to be duo_remote_flows_enabled_expectation
        expect(setting.lock_duo_remote_flows_enabled).to be lock_duo_remote_flows_enabled_expectation
      end
    end

    it_behaves_like 'a guarded duo availability setter', base_name: :duo_remote_flows
  end

  describe '#duo_foundational_flows_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :duo_foundational_flows_enabled
  end

  describe '#built_in_project_templates_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :built_in_project_templates_enabled
  end

  describe '#duo_foundational_flows_availability=' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_foundational_flows_availability, :duo_foundational_flows_enabled_expectation, :lock_duo_foundational_flows_enabled_expectation) do
      true  | true  | false
      false | false | true
    end

    with_them do
      before do
        setting.duo_foundational_flows_availability = duo_foundational_flows_availability
      end

      it 'returns the expected response' do
        expect(setting.duo_foundational_flows_enabled).to be duo_foundational_flows_enabled_expectation
        expect(setting.lock_duo_foundational_flows_enabled).to be lock_duo_foundational_flows_enabled_expectation
      end
    end

    it_behaves_like 'a guarded duo availability setter', base_name: :duo_foundational_flows
  end

  describe '#duo_custom_agents_availability=' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_custom_agents_availability, :duo_custom_agents_enabled_expectation,
      :lock_duo_custom_agents_enabled_expectation) do
      true  | true  | false
      false | false | true
    end

    with_them do
      before do
        setting.duo_custom_agents_availability = duo_custom_agents_availability
      end

      it 'returns the expected response' do
        expect(setting.duo_custom_agents_enabled).to be duo_custom_agents_enabled_expectation
        expect(setting.lock_duo_custom_agents_enabled).to be lock_duo_custom_agents_enabled_expectation
      end
    end

    it_behaves_like 'a guarded duo availability setter', base_name: :duo_custom_agents
  end

  describe '#duo_custom_flows_availability=' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_custom_flows_availability, :duo_custom_flows_enabled_expectation,
      :lock_duo_custom_flows_enabled_expectation) do
      true  | true  | false
      false | false | true
    end

    with_them do
      before do
        setting.duo_custom_flows_availability = duo_custom_flows_availability
      end

      it 'returns the expected response' do
        expect(setting.duo_custom_flows_enabled).to be duo_custom_flows_enabled_expectation
        expect(setting.lock_duo_custom_flows_enabled).to be lock_duo_custom_flows_enabled_expectation
      end
    end

    it_behaves_like 'a guarded duo availability setter', base_name: :duo_custom_flows
  end

  describe '#duo_external_agents_availability=' do
    using RSpec::Parameterized::TableSyntax

    where(:duo_external_agents_availability, :duo_external_agents_enabled_expectation,
      :lock_duo_external_agents_enabled_expectation) do
      true  | true  | false
      false | false | true
    end

    with_them do
      it 'sets duo_external_agents_enabled and lock_duo_external_agents_enabled' do
        setting.duo_external_agents_availability = duo_external_agents_availability

        expect(setting.duo_external_agents_enabled).to be duo_external_agents_enabled_expectation
        expect(setting.lock_duo_external_agents_enabled).to be lock_duo_external_agents_enabled_expectation
      end
    end

    it_behaves_like 'a guarded duo availability setter', base_name: :duo_external_agents
  end

  it_behaves_like 'tool_approval_for_session_availability setter'
  it_behaves_like 'tool_approval_for_session_availability getter'

  describe '#tool_approval_for_session_availability=' do
    it_behaves_like 'a guarded duo availability setter',
      base_name: :tool_approval_for_session,
      availability_value: "default_on"
  end

  describe 'validating new_user_signup_cap' do
    using RSpec::Parameterized::TableSyntax

    where(:feature_available, :seat_control_old, :old_value, :seat_control_new, :new_value, :expectation) do
      true  | :off      | nil | :user_cap | 10 | true
      true  | :user_cap | 0   | :user_cap | 10 | true
      true  | :user_cap | 0   | :user_cap | 0  | true
      false | :off      | nil | :user_cap | 10 | false
      false | :user_cap | 10  | :user_cap | 10 | true
    end

    with_them do
      let(:setting) { build(:namespace_settings, seat_control: seat_control_old, new_user_signups_cap: old_value) }
      let(:group) { create(:group, namespace_settings: setting) }

      before do
        allow(group).to receive(:user_cap_available?).and_return feature_available

        setting.seat_control = seat_control_new
        setting.new_user_signups_cap = new_value
      end

      it 'returns the expected response' do
        expect(setting.valid?).to be expectation

        expect(setting.errors.messages[:seat_control]).to include("cannot be set to user cap") unless expectation
      end
    end

    context 'when enabling the setting' do
      let(:feature_available) { true }

      before do
        allow(group).to receive(:user_cap_available?).and_return feature_available

        setting.seat_control = :user_cap
        setting.new_user_signups_cap = 10
      end

      shared_examples 'user cap is not available' do
        it 'is invalid' do
          expect(setting.valid?).to be false
          expect(setting.errors.messages[:seat_control]).to include("cannot be set to user cap")
        end
      end

      context 'when the group is a subgroup' do
        before do
          group.parent = build(:group)
        end

        it_behaves_like 'user cap is not available'
      end

      context 'when the group is shared externally' do
        before do
          create(:group_group_link, shared_group: group)
        end

        it_behaves_like 'user cap is not available'
      end

      context 'when the namespace is a user' do
        let(:user) { create(:user) }
        let(:setting) { user.namespace.namespace_settings }

        it_behaves_like 'user cap is not available'
      end
    end
  end

  describe 'hooks related to group user cap update' do
    let(:group) { create(:group) }
    let(:settings) { group.namespace_settings }

    before do
      allow(group).to receive(:root?).and_return(true)
      allow(group).to receive(:user_cap_available?).and_return(true)

      group.namespace_settings.update!(seat_control: seat_control, new_user_signups_cap: user_cap)
    end

    context 'when setting a user cap' do
      let(:seat_control) { :off }
      let(:user_cap) { nil }

      it 'sets prevent_sharing_groups_outside_hierarchy to true but does not set share_with_group_lock' do
        expect(group.new_user_signups_cap).to be_nil
        expect(group.share_with_group_lock).to be_falsey
        expect(settings.prevent_sharing_groups_outside_hierarchy).to be_falsey

        settings.update!(seat_control: :user_cap, new_user_signups_cap: 10)
        group.reload

        expect(group.new_user_signups_cap).to eq(10)
        expect(group.share_with_group_lock).to be_falsey
        expect(settings.reload.prevent_sharing_groups_outside_hierarchy).to be_truthy
      end

      it 'sets prevent_sharing_groups_outside_hierarchy for descendent groups but not share_with_group_lock' do
        descendent = create(:group, parent: group)
        desc_settings = descendent.namespace_settings

        expect(descendent.share_with_group_lock).to be_falsey
        expect(desc_settings.prevent_sharing_groups_outside_hierarchy).to be_falsey

        settings.update!(seat_control: :user_cap, new_user_signups_cap: 10)

        expect(descendent.reload.share_with_group_lock).to be_falsey
        expect(desc_settings.reload.prevent_sharing_groups_outside_hierarchy).to be_truthy
      end
    end

    context 'when removing a user cap from namespace settings' do
      let(:seat_control) { :user_cap }
      let(:user_cap) { 10 }

      it 'leaves prevent_sharing_groups_outside_hierarchy set to true to the related group' do
        expect(settings.prevent_sharing_groups_outside_hierarchy).to be_truthy

        settings.update!(seat_control: :off, new_user_signups_cap: nil)

        expect(settings.reload.prevent_sharing_groups_outside_hierarchy).to be_truthy
      end
    end

    context 'when seat controls are enabled' do
      let(:seat_control) { :off }
      let(:user_cap) { nil }

      it 'allows share_with_group_lock to be independently configured with user cap' do
        settings.update!(seat_control: :user_cap, new_user_signups_cap: 10)
        group.reload

        expect(group.share_with_group_lock).to be_falsey

        group.update!(share_with_group_lock: true)

        expect(group.reload.share_with_group_lock).to be_truthy
      end

      it 'allows share_with_group_lock to be independently configured with block overages', :saas do
        settings.update!(seat_control: :block_overages)
        group.reload

        expect(group.share_with_group_lock).to be_falsey

        group.update!(share_with_group_lock: true)

        expect(group.reload.share_with_group_lock).to be_truthy
      end
    end
  end

  describe '#prevent_sharing_groups_outside_hierarchy' do
    let_it_be_with_refind(:group) { create(:group) }
    let(:settings) { group.namespace_settings }

    it 'becomes enabled when block seat overages becomes enabled', :saas do
      expect(settings.prevent_sharing_groups_outside_hierarchy).to be(false)
      expect(group.share_with_group_lock).to be_falsey

      settings.update!(seat_control: :block_overages)

      expect(settings.reload.prevent_sharing_groups_outside_hierarchy).to be(true)
      expect(group.reload.share_with_group_lock).to be_falsey
    end

    context 'when block seat overages is already enabled for the group', :saas do
      before do
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      it 'cannot be disabled' do
        settings.update!(prevent_sharing_groups_outside_hierarchy: false)

        expect(settings.reload.prevent_sharing_groups_outside_hierarchy).to be(true)
      end
    end
  end

  describe '.allowed_namespace_settings_params' do
    it 'includes attributes used for limiting unique project downloads' do
      expect(described_class.allowed_namespace_settings_params).to include(
        *%i[
          unique_project_download_limit
          unique_project_download_limit_interval_in_seconds
          unique_project_download_limit_allowlist
          duo_core_features_enabled
          duo_features_enabled
          lock_duo_features_enabled
          web_based_commit_signing_enabled
          lock_web_based_commit_signing_enabled
          built_in_project_templates_enabled
          lock_built_in_project_templates_enabled
        ])
    end
  end

  describe '.cascading_with_parent_namespace' do
    context "when calling .cascading_with_parent_namespace" do
      it 'create three instance methods for attribute' do
        described_class.cascading_with_parent_namespace("any_configuration")
        expect(described_class.instance_methods).to include(
          :any_configuration_of_parent_group, :any_configuration_locked?, :any_configuration?)
      end
    end

    context 'with three configurations of MR checks' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
      let_it_be_with_reload(:subsubgroup) { create(:group, parent: subgroup) }

      shared_examples '[configuration](inherit_group_setting: bool) and [configuration]_locked?' do |attribute|
        where(:group_attr, :subgroup_attr, :subsubgroup_attr, :group_with_inherit_attr?, :group_without_inherit_attr?, :group_locked?, :subgroup_with_inherit_attr?, :subgroup_without_inherit_attr?, :subgroup_locked?, :subsubgroup_with_inherit_attr?, :subsubgroup_without_inherit_attr?, :subsubgroup_locked?) do
          true  | true  | true      | true  | true  | false     | true  | true  | true      | true  | true  | true
          true  | true  | false     | true  | true  | false     | true  | true  | true      | true  | false | true
          true  | false | false     | true  | true  | false     | true  | false | true      | true  | false | true
          false | true  | true      | false | false | false     | true  | true  | false     | true  | true  | true
          false | true  | false     | false | false | false     | true  | true  | false     | true  | false | true
          false | false | false     | false | false | false     | false | false | false     | false | false | false
        end

        with_them do
          before do
            group.namespace_settings.update!(attribute => group_attr)
            subgroup.namespace_settings.update!(attribute => subgroup_attr)
            subsubgroup.namespace_settings.update!(attribute => subsubgroup_attr)
          end

          it 'returns correct value' do
            expect(group.namespace_settings.public_send("#{attribute}?", inherit_group_setting: true)).to eq(group_with_inherit_attr?)
            expect(group.namespace_settings.public_send("#{attribute}?", inherit_group_setting: false)).to eq(group_without_inherit_attr?)
            expect(group.namespace_settings.public_send("#{attribute}_locked?")).to eq(group_locked?)

            expect(subgroup.namespace_settings.public_send("#{attribute}?", inherit_group_setting: true)).to eq(subgroup_with_inherit_attr?)
            expect(subgroup.namespace_settings.public_send("#{attribute}?", inherit_group_setting: false)).to eq(subgroup_without_inherit_attr?)
            expect(subgroup.namespace_settings.public_send("#{attribute}_locked?")).to eq(subgroup_locked?)

            expect(subsubgroup.namespace_settings.public_send("#{attribute}?", inherit_group_setting: true)).to eq(subsubgroup_with_inherit_attr?)
            expect(subsubgroup.namespace_settings.public_send("#{attribute}?", inherit_group_setting: false)).to eq(subsubgroup_without_inherit_attr?)
            expect(subsubgroup.namespace_settings.public_send("#{attribute}_locked?")).to eq(subsubgroup_locked?)
          end
        end
      end

      it_behaves_like '[configuration](inherit_group_setting: bool) and [configuration]_locked?', :only_allow_merge_if_pipeline_succeeds
      it_behaves_like '[configuration](inherit_group_setting: bool) and [configuration]_locked?', :allow_merge_on_skipped_pipeline
      it_behaves_like '[configuration](inherit_group_setting: bool) and [configuration]_locked?', :only_allow_merge_if_all_discussions_are_resolved
    end
  end

  describe '.experiment_settings_allowed?' do
    subject { group.namespace_settings.experiment_settings_allowed? }

    context 'when namespace is root' do
      let_it_be(:group) { create(:group) }

      it { is_expected.to be true }
    end

    context 'when namespace is subgroup' do
      let_it_be(:group) { create(:group, :nested) }

      it { is_expected.to be false }
    end
  end

  describe '#duo_features_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute', settings_attribute_name: :duo_features_enabled
  end

  describe '#ai_audit_events_storage_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :ai_audit_events_storage_enabled
  end

  describe '#model_prompt_cache_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :model_prompt_cache_enabled
  end

  describe '#auto_duo_code_review_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute', settings_attribute_name: :auto_duo_code_review_enabled
  end

  describe '#mark_duo_code_review_by_default_as_disabled' do
    context 'when auto_duo_code_review_enabled changes to false on a subgroup' do
      let(:subgroup) { create(:group, parent: group) }
      let(:subgroup_setting) { subgroup.namespace_settings }

      before do
        subgroup_setting.update!(auto_duo_code_review_enabled: true)
        setting.update!(enable_duo_code_review_by_default: :enabled)
      end

      it 'does not change the root group enable_duo_code_review_by_default' do
        expect { subgroup_setting.update!(auto_duo_code_review_enabled: false) }
          .not_to change { setting.reload.enable_duo_code_review_by_default }
      end
    end

    context 'when auto_duo_code_review_enabled changes to false on a root group' do
      let(:group) { create(:group) }

      before do
        setting.update!(auto_duo_code_review_enabled: true, enable_duo_code_review_by_default: :enabled)
      end

      it 'sets enable_duo_code_review_by_default to disabled' do
        expect { setting.update!(auto_duo_code_review_enabled: false) }
          .to change { setting.reload.enable_duo_code_review_by_default }.from('enabled').to('disabled')
      end
    end

    context 'when auto_duo_code_review_enabled changes to true' do
      before do
        setting.update!(auto_duo_code_review_enabled: false, enable_duo_code_review_by_default: :enabled)
      end

      it 'does not change enable_duo_code_review_by_default' do
        expect { setting.update!(auto_duo_code_review_enabled: true) }
          .not_to change { setting.reload.enable_duo_code_review_by_default }
      end
    end

    context 'when enable_duo_code_review_by_default is already disabled' do
      before do
        setting.update!(auto_duo_code_review_enabled: true, enable_duo_code_review_by_default: :disabled)
      end

      it 'does not change enable_duo_code_review_by_default' do
        expect { setting.update!(auto_duo_code_review_enabled: false) }
          .not_to change { setting.reload.enable_duo_code_review_by_default }
      end
    end

    context 'when auto_duo_code_review_enabled was not changed' do
      before do
        setting.update!(default_branch_name: 'master', enable_duo_code_review_by_default: :enabled)
      end

      it 'does not change enable_duo_code_review_by_default' do
        expect { setting.update!(default_branch_name: 'main') }
          .not_to change { setting.reload.enable_duo_code_review_by_default }
      end
    end
  end

  describe '#enterprise_users_extensions_marketplace_enabled=' do
    subject { setting.enterprise_users_extensions_marketplace_opt_in_status }

    where(:value, :expected_opt_in_status) do
      true  | 'enabled'
      false | 'disabled'
      0     | 'disabled'
      1     | 'enabled'
    end

    with_them do
      before do
        setting.update!(enterprise_users_extensions_marketplace_opt_in_status: 'unset')
        setting.enterprise_users_extensions_marketplace_enabled = value
      end

      it { is_expected.to eq(expected_opt_in_status) }
    end
  end

  describe '#duo_remote_flows_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :duo_remote_flows_enabled
  end

  describe '#duo_custom_agents_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :duo_custom_agents_enabled
  end

  describe '#duo_custom_flows_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :duo_custom_flows_enabled
  end

  describe '#duo_external_agents_enabled' do
    it_behaves_like 'a cascading namespace setting boolean attribute',
      settings_attribute_name: :duo_external_agents_enabled
  end

  describe 'attributes' do
    describe '#enabled_foundational_flows' do
      it 'accepts an array of strings' do
        setting.enabled_foundational_flows = ['code_review/v1', 'bug_triage/v1', 'documentation/v1']

        expect(setting.enabled_foundational_flows).to match_array(['code_review/v1', 'bug_triage/v1', 'documentation/v1'])
      end

      it 'defaults to nil' do
        new_setting = described_class.new

        expect(new_setting.enabled_foundational_flows).to be_nil
      end

      it 'accepts nil' do
        setting.enabled_foundational_flows = nil

        expect(setting.enabled_foundational_flows).to be_nil
      end

      it 'accepts an empty array' do
        setting.enabled_foundational_flows = []

        expect(setting.enabled_foundational_flows).to eq([])
      end
    end
  end

  describe '#sync_mcp_server_enabled' do
    context 'when the namespace is a root group' do
      before do
        setting.mcp_server_enabled = false
        setting.duo_features_enabled = true
        setting.experiment_features_enabled = true
        setting.save!
      end

      it 'sets mcp_server_enabled to true when both source fields are true' do
        expect(setting.mcp_server_enabled).to be true
      end

      it 'sets mcp_server_enabled to false when duo_features_enabled becomes false' do
        setting.duo_features_enabled = false
        setting.save!

        expect(setting.mcp_server_enabled).to be false
      end

      it 'sets mcp_server_enabled to false when experiment_features_enabled becomes false' do
        setting.experiment_features_enabled = false
        setting.save!

        expect(setting.mcp_server_enabled).to be false
      end
    end

    context 'when the namespace is a subgroup' do
      let(:subgroup) { create(:group, parent: group) }
      let(:setting) { subgroup.namespace_settings }

      it 'does not update mcp_server_enabled' do
        setting.mcp_server_enabled = false
        setting.duo_features_enabled = true
        setting.save!

        expect(setting.mcp_server_enabled).to be false
      end
    end
  end
end
