# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestDiff, feature_category: :code_review_workflow do
  before do
    stub_external_diffs_setting(enabled: true)
  end

  describe '.search' do
    let_it_be_with_reload(:merge_request_diff1) { create(:merge_request_diff) }
    let_it_be_with_reload(:merge_request_diff2) { create(:merge_request_diff) }
    let_it_be_with_reload(:merge_request_diff3) { create(:merge_request_diff) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(merge_request_diff1, merge_request_diff2, merge_request_diff3)
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
        context 'for external_diff attribute' do
          before do
            merge_request_diff1.update_column(:external_diff, 'diff-105')
            merge_request_diff2.update_column(:external_diff, 'diff-106')
            merge_request_diff3.update_column(:external_diff, 'diff-107')
          end

          it 'returns merge_request_diffs limited to 1000 records' do
            expect_any_instance_of(described_class) do |instance|
              expect(instance).to receive(:limit).and_return(1000)
            end

            result = described_class.search('diff-106')

            expect(result).to contain_exactly(merge_request_diff2)
          end
        end
      end
    end
  end

  describe '.has_external_diffs' do
    it 'only includes diffs with files' do
      diff_with_files = create(:merge_request).merge_request_diff
      create(:merge_request, :without_diffs)

      expect(described_class.has_external_diffs).to contain_exactly(diff_with_files)
    end

    it 'only includes externally stored diffs' do
      external_diff = create(:merge_request).merge_request_diff

      stub_external_diffs_setting(enabled: false)

      create(:merge_request, :without_diffs)

      expect(described_class.has_external_diffs).to contain_exactly(external_diff)
    end
  end

  describe '.project_id_in' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let_it_be(:other_project) { create(:project, :repository) }

    it 'only includes diffs for the provided projects' do
      diff = create(:merge_request, source_project: project).merge_request_diff
      other_diff = create(:merge_request, source_project: other_project).merge_request_diff
      create(:merge_request)

      expect(described_class.project_id_in([project, other_project])).to contain_exactly(diff, other_diff)
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:merge_request_diff_detail)
          .inverse_of(:merge_request_diff)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:merge_request_diff, :external, external_diff_store: ::ObjectStorage::Store::LOCAL) }
      let(:unverifiable_model_record) { build(:merge_request_diff) }
    end

    describe '#after_save' do
      let(:mr_diff) { build(:merge_request_diff, :external, external_diff_store: ::ObjectStorage::Store::LOCAL) }

      let_it_be(:primary) { create(:geo_node, :primary) }

      before do
        stub_current_geo_node(primary)
      end

      context 'when diff is stored externally and locally' do
        it 'does not create verification details when diff is without files' do
          mr_diff[:state] = :without_files

          expect { mr_diff.save! }.not_to change { MergeRequestDiffDetail.count }
        end

        it 'does not create verification details when diff is empty' do
          mr_diff[:state] = :empty

          expect { mr_diff.save! }.not_to change { MergeRequestDiffDetail.count }
        end

        it 'creates verification details' do
          mr_diff[:state] = :collected

          expect { mr_diff.save! }.to change { MergeRequestDiffDetail.count }.by(1)
        end

        context 'for a remote stored diff' do
          before do
            allow_next_instance_of(MergeRequestDiff) do |mr_diff|
              allow(mr_diff).to receive(:update_external_diff_store).and_return(true)
            end
          end

          it 'does not create verification details' do
            mr_diff[:state] = :collected
            mr_diff[:external_diff_store] = ::ObjectStorage::Store::REMOTE

            expect { mr_diff.save! }.not_to change { MergeRequestDiffDetail.count }
          end
        end
      end

      context 'when diff is not stored externally' do
        it 'does not create verification details' do
          expect { create(:merge_request_diff, stored_externally: false) }.not_to change { MergeRequestDiffDetail.count }
        end
      end
    end

    describe 'Geo cleanup event when a diff is cleaned to without_files', feature_category: :geo_replication do
      let_it_be(:primary) { create(:geo_node, :primary) }
      let_it_be(:secondary) { create(:geo_node) }

      let(:merge_request_diff) { create(:merge_request_diff, :external, external_diff_store: ::ObjectStorage::Store::LOCAL) }

      before do
        stub_current_geo_node(primary)
      end

      def deleted_events
        ::Geo::Event.where(replicable_name: 'merge_request_diff', event_name: ::Geo::ReplicatorEvents::EVENT_DELETED)
      end

      it 'publishes a deleted event so secondaries remove the out-of-scope registry' do
        merge_request_diff

        expect { merge_request_diff.clean! }.to change { deleted_events.count }.by(1)
      end

      it 'does not publish for a diff that is not stored externally' do
        non_external_diff = create(:merge_request_diff, stored_externally: false)

        expect { non_external_diff.clean! }.not_to change { deleted_events.count }
      end

      it 'does not publish on a Geo secondary' do
        merge_request_diff
        stub_current_geo_node(secondary)

        expect { merge_request_diff.clean! }.not_to change { deleted_events.count }
      end

      context 'when merge request diff replication is disabled' do
        before do
          stub_feature_flags(geo_merge_request_diff_replication: false)
        end

        it 'does not publish a deleted event' do
          merge_request_diff

          expect { merge_request_diff.clean! }.not_to change { deleted_events.count }
        end
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      let_it_be(:merge_request_1) { create(:merge_request, :skip_diff_creation, source_project: project_1) }
      let_it_be(:merge_request_2) { create(:merge_request, :skip_diff_creation, source_project: project_2) }
      let_it_be(:merge_request_3) { create(:merge_request, :skip_diff_creation, source_project: project_1, source_branch: 'improve/awesome') }
      let_it_be(:merge_request_4) { create(:merge_request, :skip_diff_creation, source_project: project_3) }

      # Merge request diff for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:external_merge_request_diff, merge_request: merge_request_1)
      end

      # Merge request diff for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:external_merge_request_diff, merge_request: merge_request_2)
      end

      # Merge request diff for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_external_diffs_object_storage(ExternalDiffUploader, direct_upload: true)
        create(:external_merge_request_diff, merge_request: merge_request_3, external_diff_store: ::ObjectStorage::Store::REMOTE)
      end

      # Merge request diff for a group not in selective sync
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:external_merge_request_diff, merge_request: merge_request_4)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
