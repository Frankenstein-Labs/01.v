# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::AuditEventsBaseService, feature_category: :package_registry do
  subject(:service) { described_class.new }

  describe '#execute' do
    subject(:execute) { service.execute }

    it { expect { execute }.to raise_error(NotImplementedError) }
  end
end
