# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyType, feature_category: :dependency_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:project) { create(:project, group: group) }

  before do
    stub_licensed_features(dependency_scanning: true)
  end

  it 'implements the DependencyInterface interface' do
    expect(described_class.interfaces).to include(Types::Sbom::DependencyInterface)
  end

  it { expect(described_class).to require_graphql_authorizations(:read_dependency) }
  it { expect(described_class.graphql_name).to eq('Dependency') }
  it { expect(described_class).to have_graphql_field(:has_dependency_paths) }
  it { expect(described_class).to have_graphql_field(:tracked_refs_count) }

  describe '#vulnerability_count' do
    subject(:resolved_count) { resolve_field(:vulnerability_count, dependency, current_user: user) }

    context 'when vulnerabilities exist' do
      let(:dependency) { create(:sbom_occurrence, :with_vulnerabilities, project: project) }

      it 'returns the count of vulnerabilities' do
        expect(resolved_count).to eq(2)
      end
    end

    context 'when vulnerabilities do not exist' do
      let(:dependency) do
        create(:sbom_occurrence, project: project).tap do |o|
          allow(o).to receive(:vulnerabilities).and_return(nil)
        end
      end

      it 'returns 0' do
        expect(resolved_count).to eq(0)
      end
    end
  end
end
