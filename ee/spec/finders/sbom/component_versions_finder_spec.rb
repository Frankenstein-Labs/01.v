# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersionsFinder, feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project, group: group) }

  let_it_be(:sbom_component) { create(:sbom_component) }
  let_it_be(:matching_occurrence1) { create_occurrence(component: sbom_component, project: project) }
  let_it_be(:matching_occurrence2) { create_occurrence(component: sbom_component, project: project) }
  let_it_be(:other_project_in_group) { create_occurrence(component: sbom_component, project: other_project) }
  let_it_be(:non_matching_occurrence) { create_occurrence(project: project) }

  def create_occurrence(**attributes)
    component = attributes[:component] || create(:sbom_component)
    version = create(:sbom_component_version, component: component)
    create(:sbom_occurrence, component_version: version, **attributes)
  end

  describe '#execute' do
    let(:finder) { described_class.new(object, sbom_component.name) }

    subject(:find) { finder.execute }

    context 'when finding versions for project' do
      let(:object) { project }

      it "returns the versions related to a component" do
        expect(find).to match_array([matching_occurrence1.component_version, matching_occurrence2.component_version])
      end
    end

    context 'when finding versions for group' do
      let(:object) { group }

      it "returns the versions related to a component" do
        expect(find).to match_array([
          matching_occurrence1.component_version,
          matching_occurrence2.component_version,
          other_project_in_group.component_version
        ])
      end
    end

    context 'when object is not supported' do
      let(:object) { Issue.new }

      it 'raises an error' do
        expect { find }.to raise_error(ArgumentError, "can't find components for Issue")
      end
    end
  end
end
