# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DependencyTrackedRefsFinder, feature_category: :dependency_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component_version) { create(:sbom_component_version) }
  let_it_be(:other_version) { create(:sbom_component_version) }

  let(:params) { { component_version_id: component_version.id } }

  let_it_be(:main_ref) do
    create(:security_project_tracked_context, :default, project: project)
  end

  let_it_be(:feature_ref) do
    create(:security_project_tracked_context, project: project, context_name: 'feature-x')
  end

  let_it_be(:tag_ref) do
    create(:security_project_tracked_context, :tag, project: project, context_name: 'v1.0.0')
  end

  # component_version appears on main (twice, via two occurrences) and the tag
  let_it_be(:occurrence_main) do
    create(:sbom_occurrence, project: project, component_version: component_version)
  end

  let_it_be(:occurrence_main_dup) do
    create(:sbom_occurrence, project: project, component_version: component_version)
  end

  let_it_be(:occurrence_tag) do
    create(:sbom_occurrence, project: project, component_version: component_version)
  end

  let_it_be(:occurrence_other) do
    create(:sbom_occurrence, project: project, component_version: other_version)
  end

  before_all do
    create(:sbom_occurrence_ref, project: project, occurrence: occurrence_main, tracked_context: main_ref)
    create(:sbom_occurrence_ref, project: project, occurrence: occurrence_main_dup, tracked_context: main_ref)
    create(:sbom_occurrence_ref, project: project, occurrence: occurrence_tag, tracked_context: tag_ref)
    # feature_ref only carries a different component version
    create(:sbom_occurrence_ref, project: project, occurrence: occurrence_other, tracked_context: feature_ref)

    project.add_developer(user)
  end

  subject(:execute) { described_class.new(project, user, params).execute }

  before do
    stub_licensed_features(dependency_scanning: true)
  end

  describe '#execute' do
    it 'returns distinct refs where the component version appears' do
      expect(execute).to contain_exactly(main_ref, tag_ref)
    end

    it 'orders refs by name then id' do
      expect(execute.to_a).to eq([main_ref, tag_ref])
    end

    context 'when the component version has no occurrences' do
      let(:params) { { component_version_id: non_existing_record_id } }

      it 'returns an empty relation' do
        expect(execute).to be_empty
      end
    end

    context 'with a search filter' do
      let(:params) { { component_version_id: component_version.id, search: 'v1' } }

      it 'filters refs by name' do
        expect(execute).to contain_exactly(tag_ref)
      end
    end

    context 'when the user cannot read dependencies' do
      subject(:execute) { described_class.new(project, create(:user), params).execute }

      it 'returns an empty relation' do
        expect(execute).to be_empty
      end
    end
  end
end
