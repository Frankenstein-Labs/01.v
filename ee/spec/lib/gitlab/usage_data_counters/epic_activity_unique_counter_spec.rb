# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageDataCounters::EpicActivityUniqueCounter, :snowplow, :clean_gitlab_redis_shared_state, feature_category: :service_ping do
  subject { track_action({ author: user1, namespace: namespace }) }

  let(:user) { user1 }
  let_it_be(:user1) { build(:user, id: 1) }
  let_it_be(:user2) { build(:user, id: 2) }
  let_it_be(:namespace) { build(:group) }

  context 'for epic created event' do
    def track_action(params)
      described_class.track_epic_created_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_CREATED }
    end
  end

  context 'for epic title changed event' do
    def track_action(params)
      described_class.track_epic_title_changed_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_TITLE_CHANGED }
    end
  end

  context 'for epic description changed event' do
    def track_action(params)
      described_class.track_epic_description_changed_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_DESCRIPTION_CHANGED }
    end
  end

  context 'for epic note created event' do
    def track_action(params)
      described_class.track_epic_note_created_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_NOTE_CREATED }
    end
  end

  context 'for epic note updated event' do
    def track_action(params)
      described_class.track_epic_note_updated_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_NOTE_UPDATED }
    end
  end

  context 'for epic note destroyed event' do
    def track_action(params)
      described_class.track_epic_note_destroyed_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_NOTE_DESTROYED }
    end
  end

  context 'for epic emoji award event' do
    def track_action(params)
      described_class.track_epic_emoji_awarded_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_EMOJI_AWARDED }
    end
  end

  context 'for epic emoji remove event' do
    def track_action(params)
      described_class.track_epic_emoji_removed_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_EMOJI_REMOVED }
    end
  end

  context 'for epic closing event' do
    def track_action(params)
      described_class.track_epic_closed_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_CLOSED }
    end
  end

  context 'for epic reopening event' do
    def track_action(params)
      described_class.track_epic_reopened_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_REOPENED }
    end
  end

  context 'for making epic visible' do
    def track_action(params)
      described_class.track_epic_visible_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_VISIBLE }
    end
  end

  context 'for making epic confidential' do
    def track_action(params)
      described_class.track_epic_confidential_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_CONFIDENTIAL }
    end
  end

  context 'for epic date modification events' do
    context 'start date' do
      context 'setting as fixed event' do
        def track_action(params)
          described_class.track_epic_start_date_set_as_fixed_action(**params)
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { described_class::EPIC_START_DATE_SET_AS_FIXED }
        end
      end

      context 'setting as fixed start date event' do
        def track_action(params)
          described_class.track_epic_fixed_start_date_updated_action(**params)
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { described_class::EPIC_FIXED_START_DATE_UPDATED }
        end
      end

      context 'setting as inherited event' do
        def track_action(params)
          described_class.track_epic_start_date_set_as_inherited_action(**params)
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { described_class::EPIC_START_DATE_SET_AS_INHERITED }
        end
      end
    end

    context 'due date' do
      context 'setting as fixed event' do
        def track_action(params)
          described_class.track_epic_due_date_set_as_fixed_action(**params)
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { described_class::EPIC_DUE_DATE_SET_AS_FIXED }
        end
      end

      context 'setting as fixed due date event' do
        def track_action(params)
          described_class.track_epic_fixed_due_date_updated_action(**params)
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { described_class::EPIC_FIXED_DUE_DATE_UPDATED }
        end
      end

      context 'setting as inherited event' do
        def track_action(params)
          described_class.track_epic_due_date_set_as_inherited_action(**params)
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { described_class::EPIC_DUE_DATE_SET_AS_INHERITED }
        end
      end
    end
  end

  context 'for adding issue to epic event' do
    def track_action(params)
      described_class.track_epic_issue_added(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_ISSUE_ADDED }
    end
  end

  context 'for changing labels epic event' do
    def track_action(params)
      described_class.track_epic_labels_changed_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_LABELS }
    end
  end

  context 'for removing issue from epic event' do
    def track_action(params)
      described_class.track_epic_issue_removed(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_ISSUE_REMOVED }
    end
  end

  context 'for moving an issue that belongs to epic' do
    def track_action(params)
      described_class.track_epic_issue_moved_from_project(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_ISSUE_MOVED_FROM_PROJECT }
    end
  end

  context 'updating epic parent' do
    def track_action(params)
      described_class.track_epic_parent_updated_action(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_PARENT_UPDATED }
    end
  end

  context 'for promoting issue to epic' do
    def track_action(params)
      described_class.track_issue_promoted_to_epic(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::ISSUE_PROMOTED_TO_EPIC }
    end
  end

  context 'for destroying epic' do
    def track_action(params)
      described_class.track_epic_destroyed(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_DESTROYED }
    end
  end

  context 'for margin epic task as checked' do
    def track_action(params)
      described_class.track_epic_task_checked(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_TASK_CHECKED }
    end
  end

  context 'for margin epic task as unchecked' do
    def track_action(params)
      described_class.track_epic_task_unchecked(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_TASK_UNCHECKED }
    end
  end

  context 'for epic cross reference' do
    def track_action(params)
      described_class.track_epic_cross_referenced(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_CROSS_REFERENCED }
    end
  end

  context 'for related epic added' do
    def track_action(params)
      described_class.track_linked_epic_with_type_relates_to_added(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_RELATED_ADDED }
    end
  end

  context 'for related epic removed' do
    def track_action(params)
      described_class.track_linked_epic_with_type_relates_to_removed(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_RELATED_REMOVED }
    end
  end

  context 'for blocking epic added' do
    def track_action(params)
      described_class.track_linked_epic_with_type_blocks_added(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_BLOCKING_ADDED }
    end
  end

  context 'for blocking epic removed' do
    def track_action(params)
      described_class.track_linked_epic_with_type_blocks_removed(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_BLOCKING_REMOVED }
    end
  end

  context 'for blocked epic added' do
    def track_action(params)
      described_class.track_linked_epic_with_type_is_blocked_by_added(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_BLOCKED_ADDED }
    end
  end

  context 'for blocked epic removed' do
    def track_action(params)
      described_class.track_linked_epic_with_type_is_blocked_by_removed(**params)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { described_class::EPIC_BLOCKED_REMOVED }
    end
  end
end
