# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::Mention::BaseHandler, feature_category: :duo_code_review do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:note) { create(:diff_note_on_merge_request, noteable: merge_request, project: project) }

  subject(:handler) { described_class.new(note) }

  describe '#execute' do
    it 'raises NotImplementedError' do
      expect { handler.execute }.to raise_error(NotImplementedError)
    end
  end

  describe '#create_note_on (via subclass)' do
    let(:subclass) do
      Class.new(described_class) do
        def execute
          create_note_on(content)
        end

        def content
          'test reply'
        end
      end
    end

    subject(:handler) { subclass.new(note) }

    it 'creates a reply note in the same discussion', :aggregate_failures do
      duo_bot = ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot

      expect { handler.execute }
        .to change { Note.count }.by(1)

      reply = Note.order(id: :desc).first
      expect(reply.note).to eq('test reply')
      expect(reply.author).to eq(duo_bot)
      expect(reply.noteable).to eq(merge_request)
      expect(reply.discussion_id).to eq(note.discussion_id)
    end

    context 'when content is blank' do
      let(:subclass) do
        Class.new(described_class) do
          def execute
            create_note_on('')
          end
        end
      end

      it 'does not create a note' do
        expect { handler.execute }.not_to change { Note.count }
      end
    end
  end
end
