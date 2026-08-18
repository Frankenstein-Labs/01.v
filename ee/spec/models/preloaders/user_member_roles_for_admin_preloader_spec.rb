# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::UserMemberRolesForAdminPreloader, feature_category: :permissions do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  subject(:result) { described_class.new(user: user).execute }

  shared_examples 'custom roles' do |ability|
    let!(:member_role) { create(factory_name, ability, user: user) }

    let(:expected_abilities) { [ability].compact }

    context 'when custom_roles license is enabled' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when ability is enabled' do
        it 'returns all allowed abilities' do
          expect(result).to eq({ admin: expected_abilities })
        end
      end
    end

    context 'when custom_roles license is disabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it { expect(result).to eq({ admin: [] }) }
    end
  end

  MemberRole.all_customizable_admin_permission_keys.each do |ability|
    where(:flag_value, :factory_klass_name) do
      true | :user_admin_role
      false | :admin_member_role
    end

    with_them do
      context 'with :extract_admin_roles_from_member_roles flag toggled' do
        let(:factory_name) { factory_klass_name }

        before do
          stub_feature_flags(extract_admin_roles_from_member_roles: flag_value)
        end

        it_behaves_like 'custom roles', ability
      end
    end
  end
end
