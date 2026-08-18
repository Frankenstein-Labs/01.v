# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Dependency, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:sbom_occurrence) { build_stubbed(:sbom_occurrence, project: project) }

  subject(:json) { described_class.represent(sbom_occurrence, user: user, project: project).as_json }

  before do
    stub_licensed_features(security_dashboard: true)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :read_security_resource, project).and_return(true)
  end

  describe 'malware field' do
    it 'exposes the return value of occurrence.malware_status' do
      allow(sbom_occurrence).to receive(:malware_status).and_return(true)
      expect(json[:malware]).to be true
    end

    context 'when the user cannot read vulnerabilities' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_security_resource, project).and_return(false)
      end

      it 'does not expose the malware field' do
        expect(json.keys).not_to include(:malware)
      end
    end
  end
end
