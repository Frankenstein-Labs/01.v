# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::BaseAuditEventFinder, feature_category: :audit_events do
  describe '#init_collection' do
    it 'raises NotImplementedError' do
      finder = described_class.new(params: {})
      expect do
        finder.send(:init_collection)
      end.to raise_error(NotImplementedError, "Subclasses must define `init_collection`")
    end
  end
end
