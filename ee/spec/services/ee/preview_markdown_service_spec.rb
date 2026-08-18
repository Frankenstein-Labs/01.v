# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PreviewMarkdownService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, group: group) }

  context 'preview epic text with quick action' do
    let_it_be(:epic) { create(:epic, group: group) }
    let(:params) do
      {
        text: '/title new title',
        target_type: 'Epic',
        target_id: epic.iid
      }
    end

    let(:service) { described_class.new(container: epic.group, current_user: user, params: params) }

    before do
      stub_licensed_features(epics: true)
    end

    it 'explains quick actions effect' do
      result = service.execute

      expect(result[:commands]).to eq 'Changes the title to "new title".'
    end
  end

  context 'preview iteration text with quick action' do
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:cadence) { create(:iterations_cadence, group: group) }
    let_it_be(:iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago) }

    let(:service) { described_class.new(container: project, current_user: user, params: params) }
    let(:quick_action_text) { '/iteration --current' }
    let(:params) do
      {
        text: quick_action_text,
        target_type: 'Issue',
        target_id: issue.iid
      }
    end

    before do
      stub_licensed_features(iterations: true)
    end

    it 'previews the quick action' do
      result = service.execute

      expect(result[:commands])
        .to eq "Sets the iteration to #{iteration.to_reference}."
    end

    context 'when the quick action would result in an error' do
      before_all do
        create(:iterations_cadence, group: group)
      end

      it 'returns an empty message' do
        result = service.execute

        expect(result[:commands]).to eq("")
      end
    end
  end
end
