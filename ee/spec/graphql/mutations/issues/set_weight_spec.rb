# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Issues::SetWeight, feature_category: :team_planning do
  include GraphqlHelpers
  let(:issue) { create(:issue, weight: 1) }
  let(:current_user) { create(:user) }

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let(:weight) { 2 }
    let(:mutated_issue) { subject[:issue] }

    subject { mutation.resolve(project_path: issue.project.full_path, iid: issue.iid, weight: weight) }

    it_behaves_like 'permission level for issue mutation is correctly verified'

    context 'when the user can update the issue' do
      before do
        issue.project.add_developer(current_user)
      end

      it 'returns the issue with correct weight', :aggregate_failures do
        expect(mutated_issue).to eq(issue)
        expect(mutated_issue.weight).to eq(2)
        expect(subject[:errors]).to be_empty
      end

      context 'when the weight is nil' do
        let(:weight) { nil }

        it 'updates weight to be nil' do
          expect(mutated_issue.weight).to be_nil
        end
      end
    end
  end
end
