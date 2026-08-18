# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terraform::StateVersion, feature_category: :infrastructure_as_code do
  include EE::GeoHelpers

  describe '.search' do
    let_it_be_with_reload(:state_version1) { create(:terraform_state_version) }
    let_it_be_with_reload(:state_version2) { create(:terraform_state_version) }
    let_it_be_with_reload(:state_version3) { create(:terraform_state_version) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(state_version1, state_version2, state_version3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all terraform state versions' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        context 'for file attribute' do
          before do
            state_version1.update_column(:file, '1.tfstate')
            state_version2.update_column(:file, '2.tfstate')
            state_version3.update_column(:file, '3.tfstate')
          end

          it do
            result = described_class.search('3')

            expect(result).to contain_exactly(state_version3)
          end
        end
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:terraform_state_version_state)
          .class_name('Geo::TerraformStateVersionState')
          .inverse_of(:terraform_state_version)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) do
        build(:terraform_state_version, terraform_state: create(:terraform_state))
      end

      let(:unverifiable_model_record) do
        record = create(:terraform_state_version, terraform_state: create(:terraform_state))
        record.update_column(:file_store, ObjectStorage::Store::REMOTE)
        record
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      # Terraform state version for the root group
      let!(:first_replicable_and_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: false)
        create(:terraform_state_version, terraform_state: create(:terraform_state, project: project_1))
      end

      # Terraform state version for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: false)
        create(:terraform_state_version, terraform_state: create(:terraform_state, project: project_2))
      end

      # Terraform state version for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: true)
        create(:terraform_state_version, :object_storage, terraform_state: create(:terraform_state, project: project_1))
      end

      # Terraform state version for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        stub_terraform_state_object_storage(enabled: false)
        create(:terraform_state_version, terraform_state: create(:terraform_state, project: project_3))
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
