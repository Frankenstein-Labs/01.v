# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::LfsObject, feature_category: :source_code_management do
  describe '.search' do
    let_it_be_with_reload(:lfs_object1) { create(:lfs_object) }
    let_it_be_with_reload(:lfs_object2) { create(:lfs_object) }
    let_it_be_with_reload(:lfs_object3) { create(:lfs_object) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(lfs_object1, lfs_object2, lfs_object3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all lfs objects' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        context 'for file attribute' do
          before do
            lfs_object1.update_column(:file, 'a1e7550e9b718dafc9b525a04879a766de62e4fbdfc46593d47f7ab74636')
            lfs_object2.update_column(:file, '4c6fe7a2979eefb9ec74a5dfc6888fb25543cf99b77586b79afea1da6f97')
            lfs_object3.update_column(:file, '8de917525f83104736f6c64d32f0e2a02f5bf2ee57843a54f222cba8c813')
          end

          it do
            result = described_class.search('8de917525f83104736f6c64d32f0e2a02f5bf2ee57843a54f222cba8c813')

            expect(result).to contain_exactly(lfs_object3)
          end
        end
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:lfs_object_state)
          .inverse_of(:lfs_object)
          .class_name('Geo::LfsObjectState')
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:lfs_object) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      # LFS object for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        lfs_object = create(:lfs_object, :with_file)
        create(:lfs_objects_project, lfs_object: lfs_object, project: project_1)
        lfs_object
      end

      # LFS object for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        lfs_object = create(:lfs_object, :with_file)
        create(:lfs_objects_project, lfs_object: lfs_object, project: project_2)
        lfs_object
      end

      # LFS object for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_lfs_object_storage(uploader: LfsObjectUploader)
        lfs_object = create(:lfs_object, :object_storage, :with_file)
        create(:lfs_objects_project, lfs_object: lfs_object, project: project_1)
        lfs_object
      end

      # LFS object for a group not in selective sync
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        lfs_object = create(:lfs_object, :with_file)
        create(:lfs_objects_project, lfs_object: lfs_object, project: project_3)
        lfs_object
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
