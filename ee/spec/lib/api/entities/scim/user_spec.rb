# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Scim::User, feature_category: :system_access do
  let(:user) { build(:user) }
  let(:identity) { build(:group_saml_identity, user: user) }

  let(:entity) do
    described_class.new(identity)
  end

  subject(:json_response) { entity.as_json }

  it 'contains the schemas' do
    expect(json_response[:schemas]).to eq(["urn:ietf:params:scim:schemas:core:2.0:User"])
  end

  it 'contains the extern UID' do
    expect(json_response[:id]).to eq(identity.extern_uid)
  end

  it 'contains the active flag' do
    expect(json_response[:active]).to be true
  end

  it 'contains the name' do
    expect(json_response[:name][:formatted]).to eq(user.name)
  end

  it 'contains the first name' do
    expect(json_response[:name][:givenName]).to eq(user.first_name)
  end

  it 'contains the last name' do
    expect(json_response[:name][:familyName]).to eq(user.last_name)
  end

  it 'contains the email' do
    expect(json_response[:emails].first[:value]).to eq(user.email)
  end

  it 'contains the username' do
    expect(json_response[:userName]).to eq(user.username)
  end

  it 'contains the resource type' do
    expect(json_response[:meta][:resourceType]).to eq('User')
  end

  it 'contains the email type' do
    expect(json_response[:emails].first[:type]).to eq('work')
  end

  it 'contains the email primary flag' do
    expect(json_response[:emails].first[:primary]).to be true
  end

  context 'with a SCIM identity' do
    let(:identity) { build(:scim_identity, user: user) }

    it 'contains active false when the identity is not active' do
      identity.active = false

      expect(json_response[:active]).to be false
    end
  end

  it 'does not expose groups when scim_groups option is not provided' do
    expect(json_response).not_to include(:groups)
  end

  context 'when scim_groups option is provided' do
    let(:user) { build_stubbed(:user) }
    let(:other_user) { build_stubbed(:user) }
    let(:identity) { build_stubbed(:scim_identity, user: user, group: nil) }
    let(:group_uid) { SecureRandom.uuid }
    let(:other_group_uid) { SecureRandom.uuid }
    let(:other_user_groups) { [{ scim_group_uid: SecureRandom.uuid, name: 'Another Group' }] }

    let(:scim_groups) do
      {
        user.id => [
          { scim_group_uid: group_uid, name: 'Engineering' },
          { scim_group_uid: other_group_uid, name: 'Marketing' }
        ],
        other_user.id => other_user_groups
      }
    end

    subject(:json_response) { described_class.new(identity, scim_groups: scim_groups).as_json }

    it "exposes the user's groups" do
      expect(json_response[:groups]).to eq(
        [
          { value: group_uid, display: 'Engineering', type: 'direct' },
          { value: other_group_uid, display: 'Marketing', type: 'direct' }
        ]
      )
    end

    context 'when the user does not belong to any SCIM groups' do
      let(:scim_groups) { { other_user.id => other_user_groups } }

      it 'exposes an empty groups array' do
        expect(json_response[:groups]).to eq([])
      end
    end
  end

  context 'when scim_groups is empty' do
    let(:user) { build_stubbed(:user) }
    let(:identity) { build_stubbed(:scim_identity, user: user, group: nil) }

    subject(:json_response) { described_class.new(identity, scim_groups: {}).as_json }

    it 'exposes an empty groups array' do
      expect(json_response[:groups]).to eq([])
    end
  end
end
