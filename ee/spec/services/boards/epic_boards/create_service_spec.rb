# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::EpicBoards::CreateService, :services do
  let_it_be(:user) { create(:user) }

  let(:parent) { create(:group) }

  describe '#execute' do
    it_behaves_like 'create a board', :epic_boards do
      def created_board
        service.execute.payload[:board]
      end
    end

    context 'when logged in' do
      it 'tracks epic board creation' do
        expect(Gitlab::UsageDataCounters::HLLRedisCounter)
          .to receive(:track_event).with('g_project_management_users_creating_epic_boards', values: user.id)

        described_class.new(parent, user).execute
      end
    end

    context 'when not logged in' do
      it 'tracks epic board creation' do
        expect(Gitlab::UsageDataCounters::HLLRedisCounter)
          .to receive(:track_event).with('g_project_management_users_creating_epic_boards', values: nil)

        described_class.new(parent, nil).execute
      end
    end

    context 'for internal event tracking' do
      context 'when creating a group board' do
        it 'tracks board_created event' do
          expect { described_class.new(parent, user).execute }
            .to trigger_internal_events('board_created')
                  .with(user: user, namespace: parent)
        end
      end
    end
  end
end
