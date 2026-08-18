# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupLink::GroupGroupLinkEntity, feature_category: :system_access do
  let_it_be(:current_user) { build_stubbed(:user) }

  # rubocop: disable RSpec/FactoryBot/AvoidCreate -- needs to be persisted
  let_it_be(:member_role) { create(:member_role, :instance) }
  # rubocop: enable RSpec/FactoryBot/AvoidCreate

  let_it_be(:shared_with_group) { build_stubbed(:group) }
  let_it_be(:shared_group) { build_stubbed(:group) }
  let_it_be(:group_group_link) do
    build_stubbed(
      :group_group_link,
      shared_group: shared_group,
      shared_with_group: shared_with_group,
      member_role_id: member_role.id
    )
  end

  let(:entity) { described_class.new(group_group_link, { current_user: current_user, source: shared_group }) }

  subject(:as_json) { entity.as_json }

  context 'when fetching member roles' do
    before do
      stub_licensed_features(custom_roles: custom_roles_enabled)
    end

    context 'when custom roles feature is available' do
      let(:custom_roles_enabled) { true }

      it 'exposes `custom_roles`' do
        expect(as_json[:custom_roles]).to eq([
          member_role_id: member_role.id,
          name: member_role.name,
          description: member_role.description,
          base_access_level: member_role.base_access_level
        ])
      end

      it 'exposes `member_role_id`' do
        expect(as_json[:access_level][:member_role_id]).to eq(member_role.id)
      end
    end

    context 'when custom roles feature is not available' do
      let(:custom_roles_enabled) { false }

      it 'does not expose `custom_roles`' do
        expect(as_json[:custom_roles]).to be_empty
      end

      it 'does not expose `member_role_id`' do
        expect(as_json[:access_level][:member_role_id]).to be_nil
      end
    end
  end
end
