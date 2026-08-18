# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::BaseUpdateService, feature_category: :security_asset_inventories do
  let(:bare_subclass) { Class.new(described_class) }
  let(:service) { bare_subclass.new([1], :sast) }

  describe '#supported?' do
    it 'raises NotImplementedError' do
      expect { service.send(:supported?) }.to raise_error(NotImplementedError)
    end
  end

  describe '#analyzers_statuses' do
    it 'raises NotImplementedError' do
      expect { service.send(:analyzers_statuses) }.to raise_error(NotImplementedError)
    end
  end
end
