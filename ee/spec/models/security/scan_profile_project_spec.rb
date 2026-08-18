# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfileProject, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group) }

  describe 'associations' do
    it { is_expected.to belong_to(:scan_profile).class_name('Security::ScanProfile').required }
    it { is_expected.to belong_to(:project).required }
  end

  describe 'validations' do
    subject { create(:security_scan_profile_project, scan_profile: scan_profile, project: project) }

    it { is_expected.to validate_uniqueness_of(:project_id).scoped_to(:security_scan_profile_id) }
  end

  describe 'scopes' do
    let_it_be(:root_namespace) { create(:group) }
    let_it_be(:other_namespace) { create(:group) }

    let_it_be(:project_in_root) { create(:project, namespace: root_namespace) }
    let_it_be(:project_in_other) { create(:project, namespace: other_namespace) }
    let_it_be(:project_1) { create(:project, namespace: group) }
    let_it_be(:project_2) { create(:project, namespace: group) }
    let_it_be(:project_3) { create(:project, namespace: group) }

    let_it_be(:scan_profile_in_root) { create(:security_scan_profile, namespace: root_namespace) }
    let_it_be(:scan_profile_in_other) { create(:security_scan_profile, namespace: other_namespace) }
    let_it_be(:scan_profile_1) { create(:security_scan_profile, namespace: group, name: "profile 1") }
    let_it_be(:scan_profile_2) { create(:security_scan_profile, namespace: group, name: "profile 2") }

    let_it_be(:association_in_root) do
      create(:security_scan_profile_project, scan_profile: scan_profile_in_root, project: project_in_root)
    end

    let_it_be(:association_in_other) do
      create(:security_scan_profile_project, scan_profile: scan_profile_in_other, project: project_in_other)
    end

    let_it_be(:association_1) do
      create(:security_scan_profile_project, scan_profile: scan_profile_1, project: project_1)
    end

    let_it_be(:association_2) do
      create(:security_scan_profile_project, scan_profile: scan_profile_1, project: project_2)
    end

    let_it_be(:association_3) do
      create(:security_scan_profile_project, scan_profile: scan_profile_1, project: project_3)
    end

    let_it_be(:association_other_profile) do
      create(:security_scan_profile_project, scan_profile: scan_profile_2, project: project_1)
    end

    let_it_be(:all_associations) do
      [
        association_in_root,
        association_in_other,
        association_1,
        association_2,
        association_3,
        association_other_profile
      ]
    end

    describe '.for_projects_and_profile' do
      let_it_be(:association1) do
        create(:security_scan_profile_project, scan_profile: scan_profile, project: project)
      end

      let_it_be(:association2) do
        create(:security_scan_profile_project, scan_profile: scan_profile, project: project_1)
      end

      let_it_be(:association_different_profile) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other, project: project)
      end

      let_it_be(:association_unrelated) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other, project: project_2)
      end

      it 'returns associations for the given projects and scan profile' do
        result = described_class.for_projects_and_profile([project.id, project_1.id], scan_profile)

        expect(result).to contain_exactly(association1, association2)
      end

      it 'returns empty when no projects match' do
        result = described_class.for_projects_and_profile([non_existing_record_id], scan_profile)

        expect(result).to be_empty
      end

      it 'returns empty when projects exist but not for the given profile' do
        result = described_class.for_projects_and_profile([project_2.id], scan_profile)

        expect(result).to be_empty
      end
    end

    describe '.not_in_root_namespace' do
      it 'returns associations where scan profile is not in the given root namespace' do
        result = described_class.not_in_root_namespace(root_namespace)

        expect(result).to match_array(all_associations - [association_in_root])
      end

      it 'returns associations in root namespace when querying for other namespace' do
        result = described_class.not_in_root_namespace(other_namespace)

        expect(result).to match_array(all_associations - [association_in_other])
      end
    end

    describe '.by_project_id' do
      it 'returns associations for the given project' do
        result = described_class.by_project_id(project_1.id)

        expect(result).to contain_exactly(association_1, association_other_profile)
      end
    end

    describe '.for_scan_profile' do
      it 'returns associations for the given scan profile' do
        result = described_class.for_scan_profile(scan_profile_1.id)

        expect(result).to contain_exactly(association_1, association_2, association_3)
      end
    end
  end

  context 'with loose foreign key on security_scan_profiles_projects.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { project }
      let_it_be(:model) { create(:security_scan_profile_project, scan_profile: scan_profile, project: parent) }
    end
  end
end
