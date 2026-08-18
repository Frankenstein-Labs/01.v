# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Milestone, :elastic_helpers, feature_category: :shared do
  describe "Associations" do
    it { is_expected.to have_many(:boards) }
  end

  describe 'callbacks', feature_category: :global_search do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be_with_reload(:milestone) { create(:milestone, :with_dates, group: group) }
    let_it_be_with_reload(:another_milestone) { create(:milestone, :with_dates, group: group) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:another_epic) { create(:epic, group: group) }
    let_it_be(:issue) { create(:issue, project: project, milestone: milestone, epic: epic) }
    let_it_be(:another_issue) { create(:issue, project: project, milestone: another_milestone, epic: another_epic) }

    context 'when epic indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        Epics::UpdateDatesService.new([epic, another_epic]).execute
        epic.reload
        another_epic.reload
      end

      it 'updates epics inheriting from the milestone in Elasticsearch when the milestone start_date is updated' do
        expect(epic.start_date_sourcing_milestone).to eq(milestone)
        expect(another_epic.start_date_sourcing_milestone).to eq(another_milestone)

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(another_epic)

        milestone.update!(start_date: milestone.start_date - 2.days)
        another_milestone.update!(title: "another milestone")
      end

      it 'updates epics inheriting from the milestone in Elasticsearch when the milestone due_date is updated' do
        expect(epic.due_date_sourcing_milestone).to eq(milestone)
        expect(another_epic.due_date_sourcing_milestone).to eq(another_milestone)

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(another_epic)

        milestone.update!(due_date: milestone.due_date + 2.days)
        another_milestone.update!(title: "another milestone")
      end
    end

    describe 'elastic_index_dependant_association' do
      let_it_be(:milestone) { create(:milestone, project: project, issues: project.issues) }

      it 'contains the correct array for elastic_index_dependants' do
        expect(described_class.elastic_index_dependants).to contain_exactly(
          {
            association_name: :issues,
            on_change: :title
          },
          {
            association_name: :issues,
            on_change: :due_date
          },
          {
            association_name: :issues,
            on_change: :start_date
          },
          {
            association_name: :issues,
            on_change: :state
          }
        )
      end

      shared_examples 'tracks ES changes' do |attribute, value|
        it "tracks changes to #{attribute} in ES" do
          expect(ElasticAssociationIndexerWorker)
            .to receive(:perform_async)
            .with('Milestone', milestone.id, ['issues'])

          milestone.reload.update!(attribute => value)
        end
      end

      shared_examples 'does not track ES changes' do |attribute, value|
        it "does not track changes to #{attribute} in ES" do
          expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)

          milestone.reload.update!(attribute => value)
        end
      end

      context 'when ES is enabled' do
        before do
          allow(milestone).to receive(:use_elasticsearch?).and_return(true)
          allow(Gitlab::CurrentSettings).to receive(:elasticsearch_indexing?).and_return(true)
        end

        include_examples 'tracks ES changes', :start_date, Date.tomorrow
        include_examples 'tracks ES changes', :due_date, 1.week.from_now
        include_examples 'does not track ES changes', :description, 'new description'

        include_examples 'tracks ES changes', :state, 'closed'
      end

      context 'when ES is not enabled' do
        before do
          allow(milestone).to receive(:use_elasticsearch?).and_return(false)
        end

        include_examples 'does not track ES changes', :title, 'new title'
        include_examples 'does not track ES changes', :start_date, Date.tomorrow
        include_examples 'does not track ES changes', :due_date, 1.week.from_now
        include_examples 'does not track ES changes', :state, 'closed'
      end
    end
  end
end
