# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::ComponentResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }

  let_it_be(:project_1) { create(:project, namespace: group) }
  let_it_be(:sbom_component_1) { create(:sbom_component, name: "activerecord") }
  let_it_be(:sbom_occurrence_1) { create(:sbom_occurrence, component: sbom_component_1, project: project_1) }

  let_it_be(:sbom_component_2) { create(:sbom_component, name: "activestorage") }
  let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, component: sbom_component_2, project: project_1) }

  let_it_be(:project_2) { create(:project, namespace: group) }
  let_it_be(:sbom_component_3) { create(:sbom_component, name: "log4j") }
  let_it_be(:sbom_occurrence_3) { create(:sbom_occurrence, component: sbom_component_3, project: project_2) }

  describe '#resolve' do
    subject { resolve_components(dependable, args: { name: name }) }

    context 'when given a group' do
      let(:dependable) { group }

      context 'when not given a query string' do
        let(:name) { nil }

        it { is_expected.to match_array([sbom_component_1, sbom_component_2, sbom_component_3]) }
      end

      context 'when given a query string' do
        let(:name) { "active" }

        it { is_expected.to match_array([sbom_component_1, sbom_component_2]) }
      end
    end
  end

  def resolve_components(obj, args: {})
    resolve(
      described_class,
      obj: obj,
      args: args,
      ctx: { current_user: user }
    )
  end
end
