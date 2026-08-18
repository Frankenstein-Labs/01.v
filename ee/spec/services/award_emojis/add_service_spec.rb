# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AwardEmojis::AddService do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:awardable, freeze: false) { create(:note_on_issue, project: project) }

  let(:name) { AwardEmoji::THUMBS_UP }

  let(:service) { described_class.new(awardable, name, user) }

  describe '#execute' do
    subject(:execute) { service.execute }

    describe 'publish to status page' do
      let(:issue_id) { awardable.noteable_id }

      context 'when adding succeeds' do
        context 'with recognized emoji' do
          let(:name) { Gitlab::StatusPage::AWARD_EMOJI }

          include_examples 'trigger status page publish'
        end

        context 'with unrecognized emoji' do
          let(:name) { 'x' }

          include_examples 'no trigger status page publish'
        end
      end

      context 'when adding fails' do
        let(:name) { '' }

        include_examples 'no trigger status page publish'
      end
    end

    describe 'tracking emoji adding' do
      context 'for epics' do
        let_it_be(:awardable, freeze: false) { create(:epic, group: group) }

        before_all do
          group.add_developer(user)
        end

        before do
          stub_licensed_features(epics: true)
        end

        it 'tracks usage' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_emoji_awarded_action)
            .with(author: user, namespace: group)

          described_class.new(awardable, name, user).execute
        end
      end

      context 'for awardables that are not epics' do
        it 'does not track epic emoji awarding' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_emoji_awarded_action)

          execute
        end
      end
    end

    describe 'track duo_code_review reaction', feature_category: :code_review_workflow do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:duo_bot) { create(:user, :duo_code_review_bot) }
      let_it_be(:duo_note, freeze: false) { create(:note, author: duo_bot, project: project, noteable: merge_request) }
      let_it_be(:regular_note, freeze: false) { create(:note, project: project, noteable: merge_request) }

      before_all do
        project.add_developer(user)
      end

      context 'when adding thumbs up to a Duo Code Review comment' do
        let(:awardable) { duo_note }
        let(:name) { 'thumbsup' }

        it 'tracks the thumbs up event' do
          expect { service.execute }
              .to trigger_internal_events('react_thumbs_up_on_duo_code_review_comment')
              .with(user: user, project: duo_note.project)
              .exactly(1).times
        end

        context 'with skin tone variants' do
          let(:name) { 'thumbsup_tone2' }

          it 'tracks the thumbs up event' do
            expect { service.execute }
              .to trigger_internal_events('react_thumbs_up_on_duo_code_review_comment')
              .with(user: user, project: duo_note.project)
              .exactly(1).times
          end
        end
      end

      context 'when adding thumbs down to a Duo Code Review comment' do
        let(:awardable) { duo_note }
        let(:name) { 'thumbsdown' }

        it 'tracks the thumbs down event' do
          expect { service.execute }
              .to trigger_internal_events('react_thumbs_down_on_duo_code_review_comment')
              .with(user: user, project: duo_note.project)
              .exactly(1).times
        end
      end

      context 'when adding thumbs up or thumbs down to a regular comment' do
        let(:awardable) { regular_note }

        context 'with thumbs up' do
          let(:name) { 'thumbsup' }

          it 'does not track thumbs up event' do
            expect { service.execute }
                .not_to trigger_internal_events('react_thumbs_up_on_duo_code_review_comment')
          end
        end

        context 'with thumbs down' do
          let(:name) { 'thumbsdown' }

          it 'does not track thumbs down event' do
            expect { service.execute }
                .not_to trigger_internal_events('react_thumbs_down_on_duo_code_review_comment')
          end
        end
      end

      context 'when adding non-thumbs emoji to a Duo Code Review comment' do
        let(:awardable) { duo_note }
        let(:name) { 'heart' }

        it 'does not track thumbs up event' do
          expect { service.execute }
              .not_to trigger_internal_events('react_thumbs_up_on_duo_code_review_comment')
        end

        it 'does not track thumbs down event' do
          expect { service.execute }
              .not_to trigger_internal_events('react_thumbs_down_on_duo_code_review_comment')
        end
      end
    end
  end
end
