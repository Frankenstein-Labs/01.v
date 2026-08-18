# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ServiceAccounts::EligibilityChecker, feature_category: :system_access do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }
  let_it_be(:other_group) { create(:group) }

  describe '#eligible?' do
    subject(:eligible) { checker.eligible?(sa) }

    context 'with composite identity restrictions', :saas do
      let(:checker) { described_class.new(target_group: target_group) }
      let(:target_group) { root_group }

      context 'when SA is from origin group' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        end

        it { is_expected.to be true }
      end

      context 'when SA is from subgroup of origin' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        end

        let(:target_group) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is from unrelated group' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
        end

        it { is_expected.to be false }
      end

      context 'when SA is from unrelated subgroup' do
        let_it_be(:other_subgroup) { create(:group, parent: other_group) }
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_subgroup)
        end

        it { is_expected.to be false }
      end

      context 'when SA is from parent of origin group' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:child_origin_group) { create(:group, parent: parent_group) }
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: child_origin_group)
        end

        let(:target_group) { parent_group }

        it { is_expected.to be false }
      end

      context 'when SA does not have composite_identity_enforced' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: other_group)
        end

        it { is_expected.to be true }
      end

      context 'when SA is instance-level (no provisioned_by_group)' do
        let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil) }

        it { is_expected.to be true }
      end
    end
  end

  describe '#filter_users' do
    context 'with mixed user types and both restrictions enabled', :saas do
      let(:checker) { described_class.new(target_group: root_group) }

      it 'includes regular users' do
        regular_user = create(:user)

        result = checker.filter_users(User.all)

        expect(result).to include(regular_user)
      end

      it 'includes allowed SAs' do
        allowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: root_group)
        instance_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)

        result = checker.filter_users(User.all)

        expect(result).to include(allowed_sa, instance_sa)
      end

      it 'excludes disallowed SAs' do
        disallowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: other_group)

        result = checker.filter_users(User.all)

        expect(result).not_to include(disallowed_sa)
      end
    end

    context 'when composite identity restriction is enabled', :saas do
      let(:checker) { described_class.new(target_group: root_group) }

      it 'excludes subgroup SAs without composite_identity_enforced (subgroup hierarchy restriction always applies)' do
        subgroup_sa_no_composite = create(:user, :service_account, composite_identity_enforced: false,
          provisioned_by_group: subgroup)

        result = checker.filter_users(User.all)

        expect(result).not_to include(subgroup_sa_no_composite)
      end

      it 'includes SAs from allowed hierarchy with composite_identity_enforced' do
        allowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: root_group)

        result = checker.filter_users(User.all)

        expect(result).to include(allowed_sa)
      end

      it 'excludes SAs from unrelated groups with composite_identity_enforced' do
        disallowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: other_group)

        result = checker.filter_users(User.all)

        expect(result).not_to include(disallowed_sa)
      end
    end

    context 'when filtering from a subgroup', :saas do
      let(:checker) { described_class.new(target_group: subgroup) }

      it 'includes SAs from target group and ancestors' do
        root_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        subgroup_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)

        result = checker.filter_users(User.all)

        expect(result).to include(root_sa, subgroup_sa)
      end

      it 'excludes SAs from descendants' do
        nested_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: nested_subgroup)

        result = checker.filter_users(User.all)

        expect(result).not_to include(nested_sa)
      end

      it 'excludes SAs from unrelated groups' do
        other_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)

        result = checker.filter_users(User.all)

        expect(result).not_to include(other_sa)
      end
    end

    context 'with instance-level SAs', :saas do
      let(:checker) { described_class.new(target_group: root_group) }

      it 'includes instance-level SAs regardless of restrictions' do
        instance_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)

        result = checker.filter_users(User.all)

        expect(result).to include(instance_sa)
      end
    end
  end

  context 'when composite identity feature flag behavior', :saas do
    let(:checker) { described_class.new(target_group: target_group) }
    let(:target_group) { root_group }

    subject(:eligible) { checker.eligible?(sa) }

    context 'when service_accounts_invite_restrictions is disabled' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group) }

      it { is_expected.to be true }
    end

    context 'when top-level SA has composite_identity_enforced but no subgroup hierarchy restriction' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group) }
      let(:target_group) { subgroup }

      it { is_expected.to be true }
    end
  end

  context 'with combined restrictions', :saas do
    let(:checker) { described_class.new(target_group: target_group) }
    let(:target_group) { root_group }

    subject(:eligible) { checker.eligible?(sa) }

    context 'when both composite identity and subgroup restrictions apply' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup) }

      it { is_expected.to be false }
    end

    context 'when only composite identity restriction applies' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group) }

      it { is_expected.to be false }
    end

    context 'when only subgroup hierarchy restriction applies' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: subgroup) }

      it { is_expected.to be false }
    end

    context 'when neither restriction applies' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: root_group) }
      let(:target_group) { subgroup }

      it { is_expected.to be true }
    end

    context 'when project provisioning and composite identity restrictions apply' do
      let_it_be(:project_in_root) { create(:project, namespace: root_group) }
      let(:sa) do
        create(:user, :service_account, composite_identity_enforced: true).tap do |user|
          user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
        end
      end

      context 'when inviting to origin project' do
        let(:checker) { described_class.new(target_project: project_in_root) }

        it { is_expected.to be true }
      end

      context 'when inviting to group' do
        it { is_expected.to be false }
      end
    end
  end
end
