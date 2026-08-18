# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::AwardEmoji, feature_category: :team_planning do
  let_it_be(:unauthorized_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :private, namespace: group) }
  let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }

  let(:current_user) { reporter }
  let(:work_item) { group_work_item }

  before do
    stub_licensed_features(epics: true)
  end

  describe '#before_update' do
    subject(:before_update) do
      described_class.new(issuable: work_item, current_user: current_user, params: params)
        .before_update
    end

    context 'when awarding an emoji' do
      let(:params) { { action: :add, name: 'star' } }

      context 'when user has no access' do
        let(:current_user) { unauthorized_user }

        it 'does not award the emoji' do
          expect { before_update }.not_to change { AwardEmoji.count }
        end
      end

      context 'when user has access to the group via the project' do
        it 'awards the emoji to the work item' do
          expect { before_update }.to change { AwardEmoji.count }.by(1)

          emoji = AwardEmoji.last

          expect(emoji.name).to eq('star')
          expect(emoji.awardable_id).to eq(work_item.id)
          expect(emoji.user).to eq(current_user)
        end
      end
    end
  end
end
