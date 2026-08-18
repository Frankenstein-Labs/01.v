# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserAdminRole, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:admin_role).class_name('Authz::AdminRole') }
    it { is_expected.to belong_to(:member_role).class_name('Authz::AdminRole') }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validation' do
    subject(:user_admin_role) { build(:user_admin_role) }

    it { is_expected.to validate_presence_of(:admin_role) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user) }
  end

  describe '.klass' do
    subject(:klass) { described_class.klass(build(:user)) }

    before do
      stub_feature_flags(extract_admin_roles_from_member_roles: flag_value)
    end

    context 'with :extract_admin_roles_from_member_roles flag enabled' do
      let(:flag_value) { true }

      it { is_expected.to eq(described_class) }
    end

    context 'with :extract_admin_roles_from_member_roles flag disabled' do
      let(:flag_value) { false }

      it { is_expected.to eq(Users::UserMemberRole) }
    end
  end

  describe '.create_or_update' do
    let(:user) { create(:user) }
    let(:admin_role) { create(:admin_role) }
    let(:admin_role_2) { create(:admin_role) }

    subject(:create_or_update) { described_class.create_or_update(user: user, member_role: admin_role) }

    context 'when a user has join record' do
      let!(:join_record) { create(:user_admin_role, user: user, admin_role: admin_role_2) }

      it 'updates the existing record with the new role' do
        expect { create_or_update }.to change {
          described_class.find_by(user: user).admin_role_id
        }.from(admin_role_2.id).to(admin_role.id)
      end

      it 'does not create a new join record' do
        expect { create_or_update }.not_to change { described_class.count }
      end
    end

    context 'when a user has no join record' do
      it 'creates a new join record' do
        expect { create_or_update }.to change { described_class.count }.by(1)
      end

      it 'assigns the correct role to the user' do
        create_or_update

        expect(user.reload.user_admin_role.admin_role_id).to eq(admin_role.id)
      end
    end
  end
end
