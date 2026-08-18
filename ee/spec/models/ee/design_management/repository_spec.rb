# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DesignManagement::Repository, feature_category: :design_management do
  include EE::GeoHelpers

  describe 'Geo', feature_category: :geo_replication do
    describe 'associations' do
      it do
        is_expected
          .to have_one(:design_management_repository_state)
          .class_name('Geo::DesignManagementRepositoryState')
          .inverse_of(:design_management_repository)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:skip_unverifiable_model_record_tests) { true }
      let_it_be(:project) { create(:project) }
      let(:verifiable_model_record) do
        build(:design_management_repository, project: project)
      end

      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, :broken_storage, group: group_2) }

      # Design management for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:design_management_repository, project: project_1)
      end

      # Design management for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:design_management_repository, project: project_2)
      end

      # Design management in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:design_management_repository, project: project_3)
      end

      let_it_be_with_refind(:secondary) { create(:geo_node, :secondary) }

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
