# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Issues::Update, feature_category: :team_planning do
  include GraphqlHelpers
  let(:current_user) { create(:user) }

  it_behaves_like 'updating health status' do
    let(:resource) { create(:issue) }
  end

  context 'updating parent epic' do
    let_it_be(:group, freeze: false) { create(:group) }
    let_it_be(:project, freeze: false) { create(:project, group: group) }
    let_it_be(:issue, freeze: false) { create(:issue, project: project) }
    let_it_be(:epic, freeze: false) { create(:epic, group: group) }

    let(:params) do
      {
        project_path: project.full_path,
        iid: issue.iid,
        weight: 10
      }.merge(epic_params)
    end

    let(:epic_params) do
      { epic: epic }
    end

    let(:mutated_issue) { subject[:issue] }
    let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

    subject { mutation.resolve(**params) }

    before do
      project.add_reporter(current_user)
      group.add_guest(current_user)
    end

    context 'when epics feature is disabled' do
      it 'raises an error' do
        expect { subject }.to raise_error(::Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'for user without permissions' do
        let(:epic) { create(:epic, :confidential, group: group) }

        it 'raises an error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'for user with correct permissions' do
        context 'when a valid epic is given' do
          it 'updates the epic' do
            expect { subject }.to change { issue.reload.epic }.from(nil).to(epic)
          end

          it 'returns the updated issue' do
            expect(mutated_issue.epic).to eq(epic)
            expect(mutated_issue.weight).to eq(10)
          end
        end

        context 'when nil epic is given' do
          before do
            create(:epic_issue, epic: epic, issue: issue)
          end

          let(:epic_params) { { epic: nil } }

          it 'set the epic to nil' do
            expect { subject }.to change { issue.reload.epic }.from(epic).to(nil)
          end

          it 'returns the updated issue' do
            expect(mutated_issue.epic).to be_nil
          end
        end
      end
    end
  end
end
