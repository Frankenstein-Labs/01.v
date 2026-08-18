# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Remediations::NoteService, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:vulnerable_mr) { create(:merge_request) }
  let_it_be(:project) { vulnerable_mr.project }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:resolution_mr) do
    create(
      :merge_request, :simple,
      source_branch: 'resolution', target_branch: vulnerable_mr.source_branch, source_project: project
    )
  end

  let(:service) { described_class.new(*params) }
  let(:params) { [vulnerable_mr, resolution_mr, vulnerability, user] }

  describe '#execute' do
    subject(:response) { described_class.new(*params).execute }

    let(:note_regex) { %r{Vulnerability Resolution has generated a fix.*merge_requests.*/\d+\+s.*} }

    context 'when a line_code can be generated' do
      let_it_be(:file) { vulnerable_mr.raw_diffs.first.new_path }
      let_it_be(:finding_location) { { start_line: 1 } }

      before do
        allow_next_instance_of(Vulnerabilities::FindingPresenter) do |presenter|
          allow(presenter).to receive_messages(file: file, location: finding_location)
        end
      end

      it 'creates a diff note' do
        expect(response.valid?).to be true
        expect(response.noteable_type).to eq('MergeRequest')
        expect(response.noteable_id).to eq(vulnerable_mr.id)
        expect(response.type).to eq('DiffNote')
        expect(response.note).to match(note_regex)
        expect(response.line_code).to eq(Gitlab::Git.diff_line_code(file, 1, 0))
      end
    end

    context 'when a line_code cannot be generated' do
      it 'creates a discussion note' do
        expect(response.valid?).to be true
        expect(response.noteable_type).to eq('MergeRequest')
        expect(response.noteable_id).to eq(vulnerable_mr.id)
        expect(response.type).to eq('DiscussionNote')
        expect(response.note).to match(note_regex)
      end
    end
  end

  context 'with missing parameters' do
    it 'raises an argument error' do
      params.each_with_index do |_, i|
        test_params = params.dup.tap { |p| p[i] = nil }

        expect { described_class.new(*test_params) }.to raise_error(ArgumentError)
      end
    end
  end
end
