# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::SavedReplies::CreateService, feature_category: :team_planning do
  context 'for group' do
    describe '#execute' do
      let_it_be(:group) { create(:group) }
      let_it_be(:saved_reply) { create(:group_saved_reply, group: group) }
      let(:name) { 'new_saved_reply_name' }
      let(:content) { 'New content for Saved Reply' }

      subject(:service) { described_class.new(object: group, name: name, content: content).execute }

      context 'when not licensed' do
        before do
          stub_licensed_features(group_saved_replies: false)
        end

        it 'returns an error' do
          expect(service[:status]).to eq(:error)
          expect(service[:message]).to eq(_('You have insufficient permissions to create a saved reply'))
        end
      end

      context 'when create fails' do
        let(:name) { saved_reply.name }
        let(:content) { '' }

        before do
          stub_licensed_features(group_saved_replies: true)
        end

        it { expect(service[:status]).to eq(:error) }

        it 'does not create new Saved Reply in database' do
          expect { service }.not_to change { ::Groups::SavedReply.count }
        end

        it 'returns error messages' do
          expect(service[:message]).to match_array(["Content can't be blank", "Name has already been taken"])
        end
      end

      context 'when create succeeds' do
        before do
          stub_licensed_features(group_saved_replies: true)
        end

        it { expect(service[:status]).to eq(:success) }

        it 'creates new Saved Reply in database' do
          expect { service }.to change { ::Groups::SavedReply.count }.by(1)
        end

        it 'returns new saved reply', :aggregate_failures do
          expect(service[:saved_reply]).to eq(::Groups::SavedReply.last)
          expect(service[:saved_reply].name).to eq(name)
          expect(service[:saved_reply].content).to eq(content)
        end
      end
    end
  end
end
