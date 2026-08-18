# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::BlockedUsersReportWorker, '#perform', feature_category: :insider_threat do
  subject(:worker) { described_class.new }

  context 'when the blocked users are reported' do
    before do
      allow_next_instance_of(::Arkose::BlockedUsersReportService) do |instance|
        allow(instance).to receive(:execute).and_return(true)
      end
    end

    it 'reports the blocked users' do
      expect(subject.perform).to be_truthy
    end
  end
end
