# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::PackageFile, feature_category: :package_registry do
  include ::EE::GeoHelpers

  describe '.search' do
    let_it_be_with_reload(:package_file1) { create(:package_file) }
    let_it_be(:package_file2) { create(:package_file) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(package_file1, package_file2)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all package files' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches' do
        context 'with matches by attributes' do
          where(:searchable_attributes) { described_class::EE_SEARCHABLE_ATTRIBUTES }

          before do
            # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
            package_file1.update_column(searchable_attributes, 'any_keyword')
          end

          with_them do
            it 'returns filtered package_files limited to 500 records' do
              expect_any_instance_of(described_class) do |instance|
                expect(instance).to receive(:limit).and_return(500)
              end

              result = described_class.search('any_keyword')

              expect(result).to contain_exactly(package_file1)
            end
          end
        end
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:package_file_state)
          .class_name('Geo::PackageFileState')
          .inverse_of(:package_file)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      before do
        stub_package_file_object_storage
      end

      let(:verifiable_model_record) do
        build(:package_file)
      end

      let(:unverifiable_model_record) do
        build(:package_file,
          file_store: ObjectStorage::Store::REMOTE,
          package: create(:maven_package)
        )
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      let_it_be(:package_1) { create(:conan_package, without_package_files: true, project: project_1) }
      let_it_be(:package_2) { create(:conan_package, without_package_files: true, project: project_2) }
      let_it_be(:package_3) { create(:conan_package, without_package_files: true, project: project_1) }
      let_it_be(:package_4) { create(:conan_package, without_package_files: true, project: project_3) }

      # Package file for the root group
      let!(:first_replicable_and_in_selective_sync) do
        stub_package_file_object_storage(enabled: false)
        create(:conan_package_file, package: package_1)
      end

      # Package file for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        stub_package_file_object_storage(enabled: false)
        create(:conan_package_file, package: package_2)
      end

      # Package file for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_package_file_object_storage(enabled: true)
        create(:conan_package_file, :object_storage, package: package_3)
      end

      # Package file for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        stub_package_file_object_storage(enabled: false)
        create(:conan_package_file, package: package_4)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
