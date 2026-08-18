# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Users::DuoStatusResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: project) }

  let(:parent) { nil }
  let(:ctx) do
    { current_user: current_user }
  end

  subject(:resolution) { resolve(described_class.single, obj: user, parent: parent, ctx: ctx) }

  context 'when resolving a human user' do
    let(:user) { create(:user, developer_of: project) }

    it { is_expected.to be_nil }
  end

  context 'when resolving a regular service account' do
    let(:user) { create(:user, :service_account, developer_of: project, composite_identity_enforced: false) }

    it { is_expected.to be_nil }
  end

  context 'when resolving a composite identity service account' do
    let(:user) { create(:user, :service_account, developer_of: project, composite_identity_enforced: true) }

    it { is_expected.to eq(user) }

    context 'when resolving via user' do
      it 'sets the parent entity in the context to nil' do
        resolution

        expect(ctx[:duo_status_parent]).to be_nil
      end
    end

    context 'when resolving via project' do
      let(:parent) { project }

      it 'sets the parent entity in the context to the project' do
        resolution

        expect(ctx[:duo_status_parent]).to eq(project)
      end
    end

    context 'when resolving via group' do
      let(:parent) { group }

      it 'sets the parent entity in the context to the group' do
        resolution

        expect(ctx[:duo_status_parent]).to eq(group)
      end
    end
  end
end
