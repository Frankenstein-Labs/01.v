# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersionsFinder, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:public_flow) { create(:ai_catalog_flow, :public).latest_version }
  let_it_be(:private_flow) { create(:ai_catalog_flow).latest_version }
  let_it_be(:public_agent) { create(:ai_catalog_agent, :public).latest_version }
  let_it_be(:public_flow_in_other_org) do
    create(:ai_catalog_flow, :public, organization: create(:organization)).latest_version
  end

  let(:params) { { organization: user.organization } }

  subject(:results) { described_class.new(user, params: params).execute }

  before do
    enable_ai_catalog
  end

  it 'returns correctly ordered public items' do
    is_expected.to eq([public_agent, public_flow])
  end

  context 'when filtering by created_after' do
    let(:params) { { organization: user.organization, created_after: Date.tomorrow } }

    it 'returns only versions created after the specified date' do
      latest_version = create(:ai_catalog_flow_version, item: public_flow.item, created_at: Date.tomorrow + 1.hour)

      is_expected.to contain_exactly(latest_version)
    end
  end

  context "with organization user does not belong to" do
    let(:params) { { organization: public_flow_in_other_org.organization } }

    it 'returns public items in that organization' do
      is_expected.to contain_exactly(public_flow_in_other_org)
    end

    it 'returns the matching items when user is nil' do
      expect(described_class.new(nil, params: params).execute).to contain_exactly(
        public_flow_in_other_org
      )
    end
  end

  describe 'exclude_deprecated' do
    let_it_be_with_reload(:deprecated_agent) { create(:ai_catalog_agent, :public) }
    let_it_be_with_reload(:agent_version) { deprecated_agent.latest_version }

    before do
      agent_version.update!(deprecated: true)
    end

    context 'when exclude_deprecated is true' do
      let(:params) { { organization: user.organization, exclude_deprecated: true } }

      it 'excludes deprecated versions' do
        results = described_class.new(user, params: params).execute

        expect(results).to contain_exactly(public_agent, public_flow)
      end
    end

    context 'when exclude_deprecated is false' do
      let(:params) { { organization: user.organization, exclude_deprecated: false } }

      it 'includes deprecated versions' do
        results = described_class.new(user, params: params).execute

        expect(results).to contain_exactly(public_agent, public_flow, agent_version)
      end
    end
  end

  context 'when organization is not provided' do
    let(:params) { {} }

    it 'raises an ArgumentError' do
      expect { results }.to raise_error(ArgumentError, _('Organization parameter must be specified'))
    end
  end
end
