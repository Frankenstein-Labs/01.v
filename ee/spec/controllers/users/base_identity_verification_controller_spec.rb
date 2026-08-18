# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::BaseIdentityVerificationController, feature_category: :instance_resiliency do
  subject(:controller) { Class.new(described_class) }

  describe '#find_verification_user' do
    it 'raises NotImplementedError' do
      expect { controller.new.send(:find_verification_user) }.to raise_error(NotImplementedError)
    end
  end
end
