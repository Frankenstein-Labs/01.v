# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::MergeRequestTool, feature_category: :ai_abstraction_layer do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.owner }

  let(:source_project) { project }
  let(:target_project) { project }
  let(:source_branch) { 'feature' }
  let(:target_branch) { 'master' }

  let(:character_limit) { 1000 }

  let(:arguments) do
    {
      source_project: source_project,
      target_project: target_project,
      source_branch: source_branch,
      target_branch: target_branch,
      character_limit: character_limit
    }
  end

  context "when there is a diff with an edge case" do
    let(:good_diff) { { diff: "@@ -0,0 +1 @@hellothere\n+🌚\n" } }
    let(:compare) { instance_double(Compare) }

    before do
      allow(CompareService).to receive_message_chain(:new, :execute).and_return(compare)
    end

    context 'when a diff is not encoded with UTF-8' do
      let(:other_diff) do
        { diff: "@@ -1 +1 @@\n-This should not be in the prompt\n+#{(0..255).map(&:chr).join}\n" }
      end

      let(:diff_files) { Gitlab::Git::DiffCollection.new([good_diff, other_diff]) }

      it 'does not raise any error and not contain the non-UTF diff' do
        allow(compare).to receive(:raw_diffs).and_return(diff_files)
        extracted_diff = described_class.extract_diff(**arguments)
        expect(extracted_diff).to include("hellothere")
        expect(extracted_diff).not_to include("This should not be in the prompt")
      end
    end

    context 'when a diff contains the binary notice' do
      let(:binary_message) { Gitlab::Git::Diff.binary_message('a', 'b') }
      let(:other_diff) { { diff: binary_message } }
      let(:diff_files) { Gitlab::Git::DiffCollection.new([good_diff, other_diff]) }

      it 'does not contain the binary diff' do
        allow(compare).to receive(:raw_diffs).and_return(diff_files)
        extracted_diff = described_class.extract_diff(**arguments)

        expect(extracted_diff).to include("hellothere")
        expect(extracted_diff).not_to include(binary_message)
      end
    end

    context 'when extracted diff is blank' do
      let(:diff_files) { Gitlab::Git::DiffCollection.new([good_diff]) }

      before do
        allow(CompareService).to receive_message_chain(:new, :execute).and_return(nil)
      end

      it 'returns nil' do
        extracted_diff = described_class.extract_diff(**arguments)
        expect(extracted_diff).to be_nil
      end
    end
  end

  describe '.extract_diff_for_duo_chat' do
    let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let(:character_limit) { 1000 }

    let(:arguments) do
      {
        merge_request: merge_request,
        character_limit: character_limit
      }
    end

    let(:good_diff) do
      instance_double(Gitlab::Git::Diff,
        old_path: 'old_path',
        new_path: 'new_path',
        diff: "@@ -0,0 +1,2 @@\n+hellothere\n+🌚\n",
        has_binary_notice?: false)
    end

    before do
      allow(merge_request).to receive_message_chain(:diffs, :diffs).and_return([good_diff])
    end

    it 'returns the expected diff in the proper format' do
      expected_diff = "--- old_path\n+++ new_path\n\n+hellothere\n+🌚\n\n"
      expect(described_class.extract_diff_for_duo_chat(**arguments)).to eq(expected_diff)
    end

    context 'when a diff is not encoded with UTF-8' do
      let(:non_utf8_diff) do
        instance_double(Gitlab::Git::Diff,
          old_path: 'non_utf8_path',
          new_path: 'non_utf8_path',
          diff: "@@ -1 +1 @@\n-This should not be in the prompt\n+non-utf8-content\n"
                  .encode('ASCII-8BIT'),
          has_binary_notice?: false)
      end

      before do
        allow(merge_request).to receive_message_chain(:diffs, :diffs).and_return([good_diff, non_utf8_diff])
      end

      it 'does not include the non-UTF-8 diff' do
        expected_diff = "--- old_path\n+++ new_path\n\n+hellothere\n+🌚\n\n"
        expect(described_class.extract_diff_for_duo_chat(**arguments)).to eq(expected_diff)
      end
    end

    context 'when a diff is binary' do
      let(:binary_diff) do
        instance_double(Gitlab::Git::Diff,
          old_path: 'binary_path',
          new_path: 'binary_path',
          diff: 'Binary files /dev/null and b/file.bin differ',
          has_binary_notice?: true)
      end

      before do
        allow(merge_request).to receive_message_chain(:diffs, :diffs).and_return([good_diff, binary_diff])
      end

      it 'does not include the binary diff' do
        expected_diff = "--- old_path\n+++ new_path\n\n+hellothere\n+🌚\n\n"
        expect(described_class.extract_diff_for_duo_chat(**arguments)).to eq(expected_diff)
      end
    end

    context 'when extracted diff is blank' do
      before do
        allow(merge_request).to receive_message_chain(:diffs, :diffs).and_return([])
      end

      it 'returns nil' do
        expect(described_class.extract_diff_for_duo_chat(**arguments)).to be_nil
      end
    end

    context 'when a small character limit is set' do
      let(:small_character_limit) { 20 }
      let(:long_diff) do
        instance_double(Gitlab::Git::Diff,
          old_path: 'long_path',
          new_path: 'long_path',
          diff: "@@ -1,5 +1,5 @@\n-This is a very long diff\n+This is a modified very long diff\n
          that exceeds the small character limit we set for this test.\n It should be truncated in the result.\n",
          has_binary_notice?: false)
      end

      before do
        allow(merge_request).to receive_message_chain(:diffs, :diffs).and_return([long_diff])
      end

      it 'truncates the diff to the specified character limit' do
        expected_diff = "--- long_path\n+++..."
        extracted_diff = described_class.extract_diff_for_duo_chat(merge_request: merge_request,
          character_limit: small_character_limit)
        expect(extracted_diff).to eq(expected_diff)
        expect(extracted_diff.length).to eq(small_character_limit)
      end
    end
  end
end
