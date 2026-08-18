# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ChatMessageAnalyzer, feature_category: :duo_chat do
  let_it_be(:organization) { create(:organization) }

  let(:messages) { [create(:ai_conversation_message, content: 'What is the pipeline?')] }

  subject(:result) { described_class.new(messages).execute }

  before do
    stub_feature_flags(work_item_legacy_url: true)
  end

  describe '#execute', :freeze_time do
    it 'succeeds' do
      expect(result).to match(
        'number_of_conversations' => 1,
        'number_of_questions_in_conversation' => 1,
        'length_of_questions_in_conversation' => 21,
        'length_of_questions' => 21,
        'first_question_after_reset' => false,
        'time_since_beginning_of_conversation' => 0
      )
    end

    context 'with reset' do
      let(:messages) do
        [
          create(:ai_conversation_message, content: 'what?', timestamp: 1.second.ago),
          create(:ai_conversation_message, :assistant, content: 'abc'),
          create(:ai_conversation_message, content: '/reset'),
          create(:ai_conversation_message, content: 'why?')
        ]
      end

      it 'handles reset' do
        expect(result).to match(
          'number_of_conversations' => 2,
          'number_of_questions_in_conversation' => 1,
          'length_of_questions_in_conversation' => 4,
          'length_of_questions' => 4,
          'first_question_after_reset' => true,
          'time_since_beginning_of_conversation' => 0,
          'time_since_last_question' => 1
        )
      end
    end

    context 'with previous question' do
      let(:messages) do
        [
          create(:ai_conversation_message, content: 'what?', timestamp: 1.second.ago),
          create(:ai_conversation_message, :assistant, content: 'abc'),
          create(:ai_conversation_message, content: 'why?')
        ]
      end

      it 'handles multiple questions in conversation' do
        expect(result).to match(
          'number_of_conversations' => 1,
          'number_of_questions_in_conversation' => 2,
          'length_of_questions_in_conversation' => 9,
          'length_of_questions' => 4,
          'first_question_after_reset' => false,
          'time_since_beginning_of_conversation' => 1,
          'time_since_last_question' => 1
        )
      end

      context 'when current question does not have a referer URL' do
        before do
          messages << create(:ai_conversation_message, referer_url: 'http://127.0.0.1:3000')
          messages << create(:ai_conversation_message)
        end

        it 'does not include asked_on_the_same_page attribute' do
          expect(result['asked_on_the_same_page']).to be_nil
        end
      end

      context 'when previous question does not have a referer URL' do
        before do
          messages << create(:ai_conversation_message)
          messages << create(:ai_conversation_message, referer_url: 'http://127.0.0.1:3000')
        end

        it 'does not include asked_on_the_same_page attribute' do
          expect(result['asked_on_the_same_page']).to be_nil
        end
      end

      context 'when previous question has a different referer URL' do
        before do
          messages << create(:ai_conversation_message, referer_url: 'http://127.0.0.1:3000')
          messages << create(:ai_conversation_message, referer_url: 'http://127.0.0.1:3000/dashboard/')
        end

        it 'returns false for the asked_on_the_same_page attribute' do
          expect(result['asked_on_the_same_page']).to be(false)
        end
      end

      context 'when previous question has the same referer URL' do
        before do
          messages << create(:ai_conversation_message, referer_url: 'http://127.0.0.1:3000')
          messages << create(:ai_conversation_message, referer_url: 'http://127.0.0.1:3000')
        end

        it 'returns true for the asked_on_the_same_page attribute' do
          expect(result['asked_on_the_same_page']).to be(true)
        end
      end
    end

    context 'when messages is empty' do
      let(:messages) { [] }

      it { is_expected.to eq({}) }
    end

    context 'when current message contains url' do
      let(:messages) { [create(:ai_conversation_message, content: content)] }
      let(:content) do
        project = create(:project)
        issue = create(:issue, project: project)
        pipeline = create(:ci_pipeline, project: project)
        epic = create(:epic)

        <<~CONTENT
          Summarize the following:
          #{Gitlab::Routing.url_helpers.group_epic_url(epic.group, epic)}
          #{::Gitlab::UrlBuilder.instance.issue_url(issue)}
          #{Gitlab::Routing.url_helpers.project_pipeline_url(project, pipeline)}
          #{Gitlab::Routing.url_helpers.project_blob_url(project, 'readme.md')}
        CONTENT
      end

      it 'returns url attributes' do
        expect(result).to match(
          'contains_link' => true,
          'contains_link_to_issue' => true,
          'contains_link_to_epic' => true,
          'contains_link_to_pipeline' => true,
          'contains_link_to_code' => true,
          'number_of_conversations' => 1,
          'number_of_questions_in_conversation' => 1,
          'length_of_questions_in_conversation' => content.length,
          'length_of_questions' => content.length,
          'first_question_after_reset' => false,
          'time_since_beginning_of_conversation' => 0
        )
      end
    end
  end
end
