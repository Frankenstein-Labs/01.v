# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupLink::ProjectGroupLinkEntity, feature_category: :system_access do
  let_it_be(:current_user) { build_stubbed(:user) }

  # rubocop: disable RSpec/FactoryBot/AvoidCreate -- needs to be persisted
  let_it_be(:member_role) { create(:member_role, :instance) }
  # rubocop: enable RSpec/FactoryBot/AvoidCreate

  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project_group_link) do
    build_stubbed(
      :project_group_link,
      project: project,
      group: group,
      member_role: member_role
    )
  end

  let(:custom_role_for_project_link_enabled) { true }

  let(:entity) { described_class.new(project_group_link, { current_user: current_user }) }

  subject(:as_json) { entity.as_json }

  before do
    allow(entity).to receive(:custom_role_for_project_link_enabled?)
      .with(project)
      .and_return(custom_role_for_project_link_enabled)

    stub_licensed_features(custom_roles: true)
  end

  it 'exposes custom_roles' do
    expect(as_json[:custom_roles]).to eq([
      member_role_id: member_role.id,
      name: member_role.name,
      description: member_role.description,
      base_access_level: member_role.base_access_level
    ])
  end

  it 'exposes member_role_id' do
    expect(as_json[:access_level][:member_role_id]).to eq(member_role.id)
  end

  context 'when feature is not available' do
    let(:custom_role_for_project_link_enabled) { false }

    it 'does not expose custom_roles' do
      expect(as_json[:custom_roles]).to be_empty
    end

    it 'does not expose member_role_id' do
      expect(as_json[:access_level][:member_role_id]).to be_nil
    end
  end
end
