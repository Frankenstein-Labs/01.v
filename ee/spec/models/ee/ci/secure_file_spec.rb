# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::SecureFile, feature_category: :mobile_devops do
  describe '.search' do
    let_it_be_with_reload(:ci_secure_file1) { create(:ci_secure_file) }
    let_it_be(:ci_secure_file2) { create(:ci_secure_file) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(ci_secure_file1, ci_secure_file2)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all records' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        where(:searchable_attribute) { described_class::EE_SEARCHABLE_ATTRIBUTES }

        before do
          # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
          ci_secure_file1.update_column(searchable_attribute, 'any_keyword')
        end

        with_them do
          it do
            result = described_class.search('any_keyword')

            expect(result).to contain_exactly(ci_secure_file1)
          end
        end
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:ci_secure_file_state)
          .class_name('Geo::CiSecureFileState')
          .inverse_of(:ci_secure_file)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:project) { create(:project) }
      let(:verifiable_model_record) { build(:ci_secure_file, project: project) }

      let(:unverifiable_model_record) do
        stub_ci_secure_file_object_storage
        file = build(:ci_secure_file, :remote_store, project: project)
        stub_ci_secure_file_object_storage(enabled: false)

        file
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, :broken_storage, group: group_2) }

      # Secure file for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:ci_secure_file, project: project_1)
      end

      # Secure file for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:ci_secure_file, project: project_2)
      end

      # Secure file for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        create(:ci_secure_file, :remote_store, project: project_1)
      end

      # Secure file for a group not in selective sync
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:ci_secure_file, project: project_3)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
