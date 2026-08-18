# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::EpicWorkItemSync::Logger, feature_category: :team_planning do
  describe '.build' do
    it 'builds an instance' do
      expect(described_class.build).to be_an_instance_of(described_class)
    end
  end

  describe '.file_name_noext' do
    it 'sets correct filename' do
      expect(described_class.file_name_noext).to eq('epic_work_item_sync')
    end
  end
end
