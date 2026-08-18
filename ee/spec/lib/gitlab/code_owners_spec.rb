# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners, feature_category: :source_code_management do
  include FakeBlobHelpers

  let_it_be(:code_owner_1) { create(:user, username: 'owner-1') }
  let_it_be(:code_owner_2) { create(:user, username: 'owner-2') }

  describe 'mocked' do
    let(:project) { create(:project, :repository) }
    let(:codeowner_blob) { fake_blob(path: 'CODEOWNERS', data: codeowner_content) }
    let(:codeowner_blob_ref) { fake_blob(path: 'CODEOWNERS', data: codeowner_content) }
    let(:codeowner_content) do
      <<~CODEOWNERS

        docs/ @owner-2
        docs/CODEOWNERS @owner-1
      CODEOWNERS
    end

    before do
      project.add_developer(code_owner_1)
      project.add_developer(code_owner_2)
      allow(project.repository).to receive(:code_owners_blob)
        .with(ref: codeowner_lookup_ref)
        .and_return(codeowner_blob)
    end

    describe '.for_blob' do
      subject { described_class.for_blob(project, blob) }

      let(:branch) { TestEnv::BRANCH_SHA['with-codeowners'] }
      let(:codeowner_lookup_ref) { branch }

      context 'when the feature is available' do
        before do
          stub_licensed_features(code_owners: true)
          allow(Gitlab::CodeOwners::Loader).to receive(:new).and_call_original
        end

        context 'when the blob is a tree' do
          let(:blob) { project.repository.blobs_at([[branch, 'docs']]).first }

          it 'returns users for a blob' do
            is_expected.to contain_exactly(code_owner_2)
          end
        end

        context 'when the blob is not a tree' do
          let(:blob) { project.repository.blob_at(branch, 'docs/CODEOWNERS') }

          it 'returns users for a blob' do
            is_expected.to contain_exactly(code_owner_1)
          end
        end
      end

      context 'when the feature is not available' do
        let(:blob) { project.repository.blob_at(branch, 'docs/CODEOWNERS') }

        before do
          stub_licensed_features(code_owners: false)
        end

        it 'returns no users' do
          is_expected.to be_empty
        end
      end
    end

    describe '.sections' do
      subject { described_class.sections(project, branch) }

      let(:branch) { TestEnv::BRANCH_SHA['with-codeowners'] }
      let(:codeowner_lookup_ref) { branch }

      context 'when the feature is available' do
        before do
          stub_licensed_features(code_owners: true)
        end

        it 'returns sections' do
          is_expected.to match_array(['codeowners'])
        end
      end

      context 'when the feature is not available' do
        before do
          stub_licensed_features(code_owners: false)
        end

        it 'returns empty array' do
          is_expected.to be_empty
        end
      end
    end

    describe '.optional_section?' do
      subject { described_class.optional_section?(project, branch, 'codeowners') }

      let(:branch) { TestEnv::BRANCH_SHA['with-codeowners'] }
      let(:codeowner_lookup_ref) { branch }

      context 'when the feature is available' do
        before do
          stub_licensed_features(code_owners: true)
        end

        it 'returns the optionality of the section' do
          is_expected.to be(false)
        end
      end

      context 'when the feature is not available' do
        before do
          stub_licensed_features(code_owners: false)
        end

        it 'does not call Loader' do
          expect(Gitlab::CodeOwners::Loader).not_to receive(:new)

          subject
        end
      end
    end

    describe '.entries_for_merge_request' do
      subject(:entries) { described_class.entries_for_merge_request(merge_request, merge_request_diff: merge_request_diff) }

      let(:merge_request_diff) { nil }
      let(:codeowner_lookup_ref) { merge_request.target_branch_ref }
      let(:merge_request) do
        create(
          :merge_request,
          source_project: project,
          source_branch: 'feature',
          target_project: project,
          target_branch: 'with-codeowners',
          merge_status: merge_status
        )
      end

      let(:merge_status) { 'can_be_merged' }

      context 'when the feature is available' do
        context 'when merge_head_diff exists' do
          context 'and the merge request can be merged' do
            let(:merge_head_diff) { instance_double(MergeRequestDiff) }

            before do
              expect(merge_head_diff).to receive(:modified_paths).with(fallback_on_overflow: true).and_return(modified_paths)
              expect(merge_request).to receive(:merge_head_diff).and_return(merge_head_diff)
              expect(merge_request).not_to receive(:merge_request_diff).and_call_original
            end

            context 'when the changed file paths have matching code owners' do
              let(:modified_paths) { ['docs/CODEOWNERS'] }

              it 'returns owners for merge request' do
                expect(entries.first).to have_attributes(pattern: 'docs/CODEOWNERS', users: [code_owner_1])
              end
            end

            context 'when the changed file paths do not have matching code owners' do
              let(:modified_paths) { ['files/ruby/feature.rb'] }

              it 'returns an empty array' do
                expect(entries).to be_empty
              end
            end
          end

          context 'and the merge request cannot be merged' do
            let(:merge_status) { 'cannot_be_merged' }

            it 'falls back to merge_request_diff' do
              expect(merge_request).not_to receive(:merge_head_diff)
              expect(merge_request.merge_request_diff).to receive(:modified_paths).with(fallback_on_overflow: true).and_call_original

              entries
            end
          end
        end

        context 'when merge_head_diff does not exist' do
          before do
            expect(merge_request).to receive(:merge_head_diff).and_return(nil)
          end

          it 'falls back to merge_request_diff' do
            expect(merge_request.merge_request_diff).to receive(:modified_paths).with(fallback_on_overflow: true).and_call_original

            entries
          end
        end

        context 'when merge_request_diff is specified' do
          let(:merge_request_diff) { merge_request.merge_request_diff }
          let(:modified_paths) { ['docs/CODEOWNERS'] }

          before do
            expect(merge_request_diff).to receive(:modified_paths).with(fallback_on_overflow: true).and_return(modified_paths)
          end

          it 'returns owners at the specified ref' do
            expect(merge_request).not_to receive(:merge_head_diff)
            expect(entries.first).to have_attributes(pattern: 'docs/CODEOWNERS', users: [code_owner_1])
          end
        end
      end

      context 'when the feature is not available' do
        before do
          stub_licensed_features(code_owners: false)
        end

        it 'skips reading codeowners and returns an empty array' do
          expect(Gitlab::CodeOwners::Loader).not_to receive(:new)

          is_expected.to be_empty
        end
      end
    end
  end

  describe '.entries_since_merge_request_commit' do
    let_it_be(:project) { create(:project, :custom_repo, files: { 'CODEOWNERS' => "*.rb @co1\n*.js @co2", 'file.rb' => '1' }) }
    let_it_be(:feature_sha1) { project.repository.create_file(code_owner_1, "another.rb", "2", message: "2", branch_name: 'feature') }
    let_it_be(:feature_sha2) { project.repository.create_file(code_owner_1, "some.js", "3", message: "3", branch_name: 'feature') }
    let_it_be(:feature_sha3) { project.repository.create_file(code_owner_1, "last.rb", "4", message: "4", branch_name: 'feature') }

    let_it_be(:merge_request) do
      create(
        :merge_request,
        source_project: project,
        source_branch: 'feature',
        target_project: project,
        target_branch: 'master'
      )
    end

    context 'when code_owners feature is not available' do
      before do
        allow(merge_request.project).to receive(:feature_available?).with(:code_owners).and_return(false)
      end

      it 'returns an empty array' do
        expect(described_class.entries_since_merge_request_commit(merge_request)).to eq([])
      end
    end

    context 'without sha' do
      it 'identifies single codeowner entry' do
        entries = described_class.entries_since_merge_request_commit(merge_request)
        patterns = entries.map(&:pattern)

        expect(entries.count).to be(1)
        expect(patterns).to include('*.rb')
      end

      context 'when the single commit gets amended' do
        before do
          head_commit_sha = merge_request.merge_request_diff.head_commit_sha
          expect(merge_request).to receive(:commit_shas).with(limit: 2).and_return([head_commit_sha])
        end

        it 'identifies codeowner entries from the merge_request_diff' do
          entries = described_class.entries_since_merge_request_commit(merge_request)
          patterns = entries.map(&:pattern)

          expect(entries.count).to be(2)
          expect(patterns).to include('*.js')
          expect(patterns).to include('*.rb')
        end
      end
    end

    context 'with sha' do
      it 'identifies single code owner entry' do
        entries = described_class.entries_since_merge_request_commit(merge_request, sha: feature_sha2)
        patterns = entries.map(&:pattern)

        expect(entries.count).to be(1)
        expect(patterns).to include('*.rb')
      end

      it 'identifies multiple code owner entries' do
        entries = described_class.entries_since_merge_request_commit(merge_request, sha: feature_sha1)
        patterns = entries.map(&:pattern)

        expect(entries.count).to be(2)
        expect(patterns).to include('*.js')
        expect(patterns).to include('*.rb')
      end

      context 'when the sha is the same as head_commit_sha' do
        it 'identifies codeowner entries from the merge_request_diff' do
          head_commit_sha = merge_request.merge_request_diff.head_commit_sha
          entries = described_class.entries_since_merge_request_commit(merge_request, sha: head_commit_sha)
          patterns = entries.map(&:pattern)

          expect(entries.count).to be(2)
          expect(patterns).to include('*.js')
          expect(patterns).to include('*.rb')
        end
      end

      it 'uses changed_paths instead of modified_paths' do
        compare = instance_double(Compare)
        allow(::MergeRequests::MergeRequestDiffComparison).to receive_message_chain(:new, :compare_with).and_return(compare)
        allow(compare).to receive(:changed_paths).and_return([])

        described_class.entries_since_merge_request_commit(merge_request, sha: feature_sha1)

        expect(compare).to have_received(:changed_paths)
      end
    end
  end
end
