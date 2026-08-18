# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::CreateNoteService, feature_category: :ai_agents do
  let_it_be(:author) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:note) { build(:note, project: project) }
  let_it_be(:source) { create(:issue, project: project) }
  let_it_be(:command) { 'dev' }

  let(:service) { described_class.new(author: author, note: note, source: source, command: command) }

  describe '#execute' do
    context 'when note is present' do
      it 'calls UpdateService with correct parameters' do
        update_service = instance_double(Notes::UpdateService)
        expect(Notes::UpdateService).to receive(:new)
          .with(project, author, hash_including(:note, :author))
          .and_return(update_service)
        expect(update_service).to receive(:execute).with(an_instance_of(Note))

        service.execute
      end

      it 'generates the correct note message for an issue' do
        expect(service.send(:generate_note_message)).to eq(
          "I'm generating code for this issue. I'll update this comment and open a merge request when I'm done."
        )
      end
    end

    context 'when note is nil' do
      let(:note) { nil }

      it 'does not call UpdateService' do
        expect(Notes::UpdateService).not_to receive(:new)
        service.execute
      end
    end
  end

  describe '#generate_note_message' do
    context 'when source is an Issue' do
      it 'returns the correct message for dev command' do
        expect(service.send(:generate_note_message)).to include("I'm generating code for this issue")
      end

      it 'returns the correct message for transform command' do
        allow(service).to receive(:command).and_return('transform')
        expect(service.send(:generate_note_message)).to include("I'm upgrading your code to Java 17")
      end
    end

    context 'when source is a MergeRequest' do
      let(:source) { create(:merge_request, source_project: project) }

      it 'returns the correct message for dev command' do
        expect(service.send(:generate_note_message)).to include(
          "I'm revising this merge request based on your feedback"
        )
      end

      context 'when note is a DiffNote' do
        let(:note) { build(:diff_note_on_merge_request, project: project) }

        it 'returns the correct message for test command' do
          allow(service).to receive(:command).and_return('test')
          expect(service.send(:generate_note_message)).to include(
            "I'm creating unit tests for the selected lines of code"
          )
        end
      end
    end

    context 'when source is neither Issue nor MergeRequest' do
      let_it_be(:source) { create(:project) }

      it 'returns nil' do
        expect(service.send(:generate_note_message)).to be_nil
      end
    end
  end
end
