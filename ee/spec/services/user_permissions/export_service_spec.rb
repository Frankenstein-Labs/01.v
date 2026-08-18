# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserPermissions::ExportService, feature_category: :system_access do
  let(:service) { described_class.new(current_user) }

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user, last_activity_on: Date.new(2020, 12, 16)) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:sub_group_user) { create(:user, last_activity_on: Date.new(2020, 12, 18)) }

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:custom_role) do
    create(:member_role, base_access_level: Gitlab::Access::GUEST, name: 'Top guest')
  end

  let_it_be(:group_owner) { create(:group_member, :owner, group: group, user: user) }
  let_it_be(:group_guest) do
    create(:group_member, :guest, group: group, user: user2, member_role: custom_role)
  end

  let_it_be(:sub_group_maintainer) do
    create(:group_member, :maintainer, group: sub_group, user: sub_group_user)
  end

  shared_examples 'not allowed to export user permissions' do
    it { expect(service.csv_data).not_to be_success }
  end

  before do
    stub_licensed_features(export_user_permissions: licensed)
  end

  context 'when user is an admin', :enable_admin_mode do
    let(:current_user) { admin }

    context 'when licensed' do
      subject(:csv) { CSV.parse(service.csv_data.payload.to_a.join, headers: true).to_a }

      let(:licensed) { true }

      it { expect(service.csv_data).to be_success }

      it 'returns correct data' do
        headers = [
          'Username', 'Email', 'Type', 'Path', 'Access Level', 'Last Activity'
        ]
        expected_data = [
          [user.username, user.email, 'Group', group.full_path, 'Owner', '2020-12-16'],
          [user2.username, user2.email, 'Group', group.full_path, "Top guest (#{_('Custom role')})", nil],
          [sub_group_user.username, sub_group_user.email, 'Sub group', sub_group.full_path, 'Maintainer', '2020-12-18']
        ]

        expect(csv).to match_array([headers] + expected_data)
      end
    end

    context 'when not licensed' do
      let(:licensed) { false }

      it_behaves_like 'not allowed to export user permissions'
    end
  end

  context 'when user is not an admin' do
    let(:current_user) { user }

    context 'when licensed' do
      let(:licensed) { true }

      it_behaves_like 'not allowed to export user permissions'
    end

    context 'when not licensed' do
      let(:licensed) { false }

      it_behaves_like 'not allowed to export user permissions'
    end
  end
end
