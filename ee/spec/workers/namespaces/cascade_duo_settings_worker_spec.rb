# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::CascadeDuoSettingsWorker, feature_category: :ai_abstraction_layer do
  let(:group) { create(:group) }
  let(:user) { create(:user) }
  let(:setting_attributes) { { "duo_features_enabled" => true } }
  let(:always_on_attributes) { { "duo_features_enabled" => true, "lock_duo_features_enabled" => true } }

  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'calls cascade_for_group on service with the correct arguments' do
      expect_next_instance_of(Ai::CascadeDuoSettingsService, setting_attributes, current_user: user) do |service|
        expect(service).to receive(:cascade_for_group).with(group)
      end

      worker.perform(group.id, setting_attributes, user.id)
    end

    context 'when user_id is not provided' do
      it 'calls cascade_for_group with nil current_user' do
        expect_next_instance_of(Ai::CascadeDuoSettingsService, setting_attributes, current_user: nil) do |service|
          expect(service).to receive(:cascade_for_group).with(group)
        end

        worker.perform(group.id, setting_attributes)
      end
    end

    context 'when user_id does not exist' do
      it 'calls cascade_for_group with nil current_user' do
        expect_next_instance_of(Ai::CascadeDuoSettingsService, setting_attributes, current_user: nil) do |service|
          expect(service).to receive(:cascade_for_group).with(group)
        end

        worker.perform(group.id, setting_attributes, non_existing_record_id)
      end
    end

    context 'when group does not exist' do
      it 'calls cascade_for_group with nil group' do
        expect_next_instance_of(Ai::CascadeDuoSettingsService, setting_attributes, current_user: user) do |service|
          expect(service).to receive(:cascade_for_group).with(nil)
        end

        worker.perform(non_existing_record_id, setting_attributes, user.id)
      end
    end

    context 'when attributes originate from duo_availability = always_on' do
      it 'calls cascade_for_group with the always_on attribute combination' do
        expect_next_instance_of(Ai::CascadeDuoSettingsService, always_on_attributes, current_user: user) do |service|
          expect(service).to receive(:cascade_for_group).with(group)
        end

        worker.perform(group.id, always_on_attributes, user.id)
      end
    end
  end
end
