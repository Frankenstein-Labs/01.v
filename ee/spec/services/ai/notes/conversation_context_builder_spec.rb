# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Notes::ConversationContextBuilder, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:note) { create(:note, project: project, noteable: issue, author: user, note: 'Hello') }

  describe '#build' do
    subject(:context) { described_class.new(note).build }

    it 'includes the note content in a message block with id' do
      expect(context).to include("<message id=\"#{note.id}\" author=\"@#{user.username}\">\nHello\n</message>")
    end

    it 'marks a complete thread when nothing was trimmed', :aggregate_failures do
      expect(context).to include('This is the complete discussion thread')
      expect(context).not_to include('trimmed')
    end

    context 'with notes sharing the discussion_id but belonging to another noteable' do
      let_it_be(:other_issue) { create(:issue, project: project) }

      before do
        create(:note, project: project, noteable: other_issue, author: user,
          note: 'Collision note', discussion_id: note.discussion_id)
      end

      it 'excludes notes from other noteables that collide on discussion_id' do
        expect(context).not_to include('Collision note')
      end
    end

    context 'with multiple notes in the discussion' do
      let_it_be(:other_user) { create(:user) }

      let!(:reply) do
        create(:note, project: project, noteable: issue, author: other_user,
          note: 'Follow-up', discussion_id: note.discussion_id)
      end

      it 'includes all notes in chronological order', :aggregate_failures do
        expect(context).to include('Hello')
        expect(context).to include('Follow-up')
        expect(context.index('Hello')).to be < context.index('Follow-up')
      end

      it 'attributes each message to the correct author', :aggregate_failures do
        expect(context).to include("@#{user.username}")
        expect(context).to include("@#{other_user.username}")
      end
    end

    context 'with system notes in the discussion' do
      before do
        create(:note, :system, project: project, noteable: issue,
          note: 'added label ~bug', discussion_id: note.discussion_id)
      end

      it 'excludes system notes' do
        expect(context).not_to include('added label')
      end
    end

    context 'when notes exceed max_notes' do
      subject(:context) { described_class.new(note, max_notes: 2).build }

      before do
        3.times do |i|
          create(:note, project: project, noteable: issue, author: user,
            note: "Message #{i}", discussion_id: note.discussion_id)
        end
      end

      it 'includes an omission notice without a count' do
        expect(context).to include('Earlier messages in this thread were trimmed')
      end

      it 'does not include a specific count of omitted messages' do
        expect(context).not_to match(/\d+ earlier message/)
      end

      it 'includes the discussion ID and URL needed to fetch the rest of the discussion', :aggregate_failures do
        expect(context).to include("Discussion ID: #{note.discussion_id}")
        expect(context).to include("URL: #{Gitlab::UrlBuilder.build(issue)}")
      end

      it 'keeps the notice read-only (no reply-channel instruction)' do
        expect(context).not_to include('reply')
      end

      it 'includes only the most recent messages' do
        expect(context).to include('Message 2')
      end

      it 'excludes older messages beyond max_notes' do
        expect(context).not_to include('Hello')
      end
    end

    context 'when note has no discussion peers' do
      it 'returns a single message block' do
        blocks = context.scan(/<message/).count
        expect(blocks).to eq(1)
      end
    end

    context 'when the note has no author' do
      before do
        note.update_column(:author_id, non_existing_record_id)
      end

      it 'uses "unknown" as the author' do
        expect(context).to include('@unknown')
      end
    end
  end
end
