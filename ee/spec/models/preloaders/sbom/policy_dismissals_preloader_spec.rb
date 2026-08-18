# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::Sbom::PolicyDismissalsPreloader, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:security_policy) { create(:security_policy) }

  let_it_be(:component_version) { create(:sbom_component_version) }
  let_it_be(:occurrence) do
    create(:sbom_occurrence, project: project, component_version: component_version)
  end

  let_it_be(:other_component_version) { create(:sbom_component_version) }
  let_it_be(:other_occurrence) do
    create(:sbom_occurrence, project: project, component_version: other_component_version)
  end

  describe '#execute' do
    subject(:execute) { described_class.new(occurrences, group).execute }

    context 'when occurrences are empty' do
      let(:occurrences) { [] }

      it 'does not fire any queries' do
        expect { execute }.not_to exceed_query_limit(0)
      end
    end

    context 'with basic dismissal matching' do
      let_it_be(:dismissal) do
        create(:policy_dismissal, :preserved,
          project: project,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid])
      end

      let(:occurrences) { [occurrence, other_occurrence] }

      it 'assigns matching dismissals to the correct occurrence' do
        execute

        expect(occurrence.policy_dismissals).to contain_exactly(dismissal)
        expect(other_occurrence.policy_dismissals).to eq([])
      end
    end

    context 'when same component version appears in multiple projects' do
      let_it_be(:other_project) { create(:project, group: group) }
      let_it_be(:other_project_occurrence) do
        create(:sbom_occurrence, project: other_project, component_version: component_version)
      end

      let_it_be(:dismissal_project_1) do
        create(:policy_dismissal, :preserved,
          project: project,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid])
      end

      let_it_be(:dismissal_project_2) do
        create(:policy_dismissal, :preserved,
          project: other_project,
          security_policy: security_policy,
          license_occurrence_uuids: [other_project_occurrence.uuid])
      end

      let(:occurrences) { [occurrence] }

      it 'assigns dismissals from all projects for the same component version' do
        execute

        expect(occurrence.policy_dismissals).to contain_exactly(dismissal_project_1, dismissal_project_2)
      end
    end

    context 'when same dismissal references multiple UUIDs of same component version' do
      let_it_be(:second_occurrence_same_cv) do
        create(:sbom_occurrence, project: project, component_version: component_version)
      end

      let_it_be(:dismissal) do
        create(:policy_dismissal, :preserved,
          project: project,
          security_policy: security_policy,
          license_occurrence_uuids: [occurrence.uuid, second_occurrence_same_cv.uuid])
      end

      let(:occurrences) { [occurrence] }

      it 'assigns dismissal only once for each component version' do
        execute

        expect(occurrence.policy_dismissals).to contain_exactly(dismissal)
      end
    end

    context 'when all matching occurrences for a component version are archived' do
      let_it_be(:archived_component_version) { create(:sbom_component_version) }
      let_it_be(:archived_occurrence) do
        create(:sbom_occurrence, project: project, component_version: archived_component_version, archived: true)
      end

      let(:occurrences) { [archived_occurrence] }

      it 'returns no dismissals without querying policy dismissals' do
        expect(::Security::PolicyDismissal).not_to receive(:for_license_occurrence_uuids)

        execute

        expect(archived_occurrence.policy_dismissals).to eq([])
      end
    end
  end
end
