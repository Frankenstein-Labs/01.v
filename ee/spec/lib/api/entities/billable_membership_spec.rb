# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::BillableMembership, feature_category: :seat_cost_management do
  let(:entity) do
    {
      id: membership.id,
      source_id: membership.group.id,
      source_full_name: membership.group.full_name,
      source_members_url: Gitlab::Routing.url_helpers.group_group_members_url(membership.group),
      created_at: membership.created_at,
      expires_at: membership.expires_at,
      access_level: {
        string_value: role_name,
        integer_value: 30,
        custom_role: custom_role
      }
    }
  end

  context 'without custom role' do
    let(:membership) { create(:group_member, :developer) }
    let(:custom_role) { nil }
    let(:role_name) { 'Developer' }

    subject(:entity_representation) { described_class.new(membership).as_json }

    it 'exposes the expected attributes' do
      expect(entity_representation).to eq entity
    end
  end

  context 'with custom role' do
    let(:role) { create(:member_role, :developer, :billable) }
    let(:membership) { create(:group_member, :developer, member_role: role) }
    let(:custom_role) { { id: role.id, name: role.name } }
    let(:role_name) { role.name }

    subject(:entity_representation) { described_class.new(membership).as_json }

    it 'exposes the expected attributes' do
      expect(entity_representation).to eq entity
    end
  end
end
