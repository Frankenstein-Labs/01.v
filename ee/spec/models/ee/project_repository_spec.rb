# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectRepository, feature_category: :source_code_management do
  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:project_repository_state)
          .class_name('Geo::ProjectRepositoryState')
          .inverse_of(:project_repository)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:skip_unverifiable_model_record_tests) { true }

      let(:verifiable_model_record) { build(:project_repository) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      # Project for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        project = create(:project_with_repo, group: group_1)
        project.project_repository
      end

      # Project for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        project = create(:project_with_repo, group: nested_group_1)
        project.project_repository
      end

      # Project in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        project = create(:project_with_repo, :broken_storage, group: group_2)
        project.project_repository
      end

      include_examples 'Geo Framework selective sync behavior'
    end

    describe '.create_verification_details_for' do
      let(:verification_state_class) { described_class.verification_state_table_class }
      let_it_be(:project1) { create(:project_with_repo) }
      let_it_be(:project2) { create(:project_with_repo) }
      let(:project_repo1) { project1.project_repository }
      let(:project_repo2) { project2.project_repository }

      it 'creates verification details with correct attributes' do
        described_class.create_verification_details_for([project_repo1.id, project_repo2.id])

        verification_state1 = verification_state_class.find_by(project_id: project1.id)
        verification_state2 = verification_state_class.find_by(project_id: project2.id)

        expect(verification_state1).to have_attributes(
          described_class.verification_state_model_key => project_repo1.id,
          project_id: project1.id
        )

        expect(verification_state2).to have_attributes(
          described_class.verification_state_model_key => project_repo2.id,
          project_id: project2.id
        )
      end
    end
  end
end
