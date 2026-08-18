# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SentNotification, :request_store, feature_category: :notifications do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, group: group) }

  describe 'callbacks' do
    describe '#ensure_sharding_key' do
      context 'when noteable is a Epic' do
        let(:epic) { create(:epic, group: group) }

        subject do
          record = described_class.new(noteable: epic)
          record.valid?

          record.namespace_id
        end

        it { is_expected.to eq(epic.group_id) }
      end
    end
  end
end
