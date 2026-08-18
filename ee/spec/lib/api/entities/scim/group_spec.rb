# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Scim::Group, feature_category: :system_access do
  let(:group_uid) { SecureRandom.uuid }
  let(:other_group_uid) { SecureRandom.uuid }
  let(:group_link) { build(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: group_uid) }
  let(:entity) { described_class.new(group_link) }

  subject(:json_response) { entity.as_json }

  it 'contains the schemas' do
    expect(json_response[:schemas]).to eq(['urn:ietf:params:scim:schemas:core:2.0:Group'])
  end

  it 'contains the SCIM group uid' do
    expect(json_response[:id]).to eq(group_link.scim_group_uid)
  end

  it 'contains the display name' do
    expect(json_response[:displayName]).to eq(group_link.saml_group_name)
  end

  it 'contains an empty members array when no members are provided' do
    expect(json_response[:members]).to eq([])
  end

  it 'contains the resource type' do
    expect(json_response[:meta][:resourceType]).to eq('Group')
  end

  context 'when members are provided via the scim_members option' do
    let(:scim_members) do
      {
        group_uid => [
          { extern_uid: 'user-1', name: 'Alice Example' },
          { extern_uid: 'user-2', name: 'Bob Example' }
        ],
        other_group_uid => [{ extern_uid: 'user-3', name: 'Carol Example' }]
      }
    end

    subject(:json_response) { described_class.new(group_link, scim_members: scim_members).as_json }

    it 'exposes only this group\'s members as SCIM member objects' do
      expect(json_response[:members]).to eq([
        { value: 'user-1', display: 'Alice Example', type: 'User' },
        { value: 'user-2', display: 'Bob Example', type: 'User' }
      ])
    end
  end

  context 'when the group has no entry in the scim_members option' do
    subject(:json_response) { described_class.new(group_link, scim_members: {}).as_json }

    it 'returns an empty members array' do
      expect(json_response[:members]).to eq([])
    end
  end

  context 'when members are excluded' do
    subject(:json_response) do
      described_class.new(
        group_link,
        excluded_attributes: ['members'],
        scim_members: { group_uid => [{ extern_uid: 'user-1', name: 'Alice Example' }] }
      ).as_json
    end

    it 'does not include members in the response' do
      expect(json_response).not_to include(:members)
    end
  end
end
