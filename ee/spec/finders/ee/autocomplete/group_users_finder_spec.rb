# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Autocomplete::GroupUsersFinder, feature_category: :code_review_workflow do
  describe '#execute' do
    let_it_be(:current_user) { create(:user) }
    let(:params) { {} }

    let_it_be(:group) { create(:group) }
    let_it_be(:duo_code_review_bot) { ::Users::Internal.in_organization(group.organization_id).duo_code_review_bot }

    subject do
      described_class.new(current_user: current_user, group: group).execute.to_a
    end

    context 'when group does not have access to Duo Code review for given user' do
      before do
        allow(group).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
      end

      it { is_expected.not_to include(duo_code_review_bot) }
    end

    context 'when group has access to Duo Code review' do
      before do
        allow(group).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
      end

      it { is_expected.to include(duo_code_review_bot) }
    end
  end
end
