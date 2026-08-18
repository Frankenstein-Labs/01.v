# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::MemberRole, feature_category: :permissions do
  describe 'exposes expected fields' do
    let_it_be(:group) { create(:group) }
    let_it_be(:owner) { create(:group_member, :owner, source: group) }

    let_it_be(:member_role) { create(:member_role, :read_code, namespace: group) }

    subject(:entity_representation) { described_class.new(member_role).as_json }

    it 'exposes the attributes' do
      expect(entity_representation[:id]).to eq member_role.id
      expect(entity_representation[:name]).to eq member_role.name
      expect(entity_representation[:description]).to eq member_role.description
      expect(entity_representation[:base_access_level]).to eq member_role.base_access_level
      expect(entity_representation[:read_code]).to be(true)
      expect(entity_representation[:read_vulnerability]).to be(false)
      expect(entity_representation[:admin_terraform_state]).to be(false)
      expect(entity_representation[:admin_vulnerability]).to be(false)
      expect(entity_representation[:manage_group_access_tokens]).to be(false)
      expect(entity_representation[:manage_project_access_tokens]).to be(false)
      expect(entity_representation[:archive_project]).to be(false)
      expect(entity_representation[:remove_project]).to be(false)
      expect(entity_representation[:group_id]).to eq(group.id)
    end
  end
end
