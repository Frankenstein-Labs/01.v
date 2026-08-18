# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IterationNote, feature_category: :team_planning do
  describe '.from_event' do
    let(:author) { create(:user) }
    let_it_be(:project) { create(:project, :small_repo) }
    let(:noteable) { create(:work_item, :task, author: author, project: project) }
    let(:event) { create(:resource_iteration_event, issue: noteable) }

    subject { described_class.from_event(event, resource: noteable, resource_parent: project) }

    it_behaves_like 'a synthetic note', 'iteration'

    RSpec.shared_examples 'actionable iteration note' do |action, message|
      let(:iteration) { create(:iteration) }
      let(:event) { create(:resource_iteration_event, action: action, issue: noteable, iteration: iteration) }

      it 'creates the expected note' do
        expect(subject.note).to eq("#{message} #{iteration.to_reference}")
        expect(subject.note_html).to include(message)
        expect(subject.created_at).to eq(event.created_at)
        expect(subject.updated_at).to eq(event.created_at)
      end

      context 'when the automated column is true' do
        let!(:parent) { create(:work_item, :issue, author: author, project: project) }

        before do
          event.update!(automated: true, triggered_by_id: parent.id)
        end

        it 'creates the expected note' do
          expect(subject.note).to eq(
            "#{message} #{iteration.to_reference} on this item and parent item"
          )
        end

        context "when the parent is deleted" do
          before do
            parent.destroy!
          end

          it 'creates the expected note' do
            expect(subject.note).to eq(
              "#{message} #{iteration.to_reference} on this item and parent item (deleted)"
            )
          end
        end
      end
    end

    it_behaves_like "actionable iteration note", :remove, "removed iteration"
    it_behaves_like "actionable iteration note", :add, "changed iteration to"
  end
end
