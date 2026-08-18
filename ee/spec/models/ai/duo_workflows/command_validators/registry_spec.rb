# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../app/models/ai/duo_workflows/command_validators/base'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/git_validator'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/npm_validator'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/docker_validator'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/bundle_validator'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/make_validator'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/curl_validator'
require_relative '../../../../../app/models/ai/duo_workflows/command_validators/registry'

RSpec.describe Ai::DuoWorkflows::CommandValidators::Registry, feature_category: :duo_agent_platform do
  describe '.validator_for' do
    it 'returns validators for pattern-eligible programs' do
      expect(described_class.validator_for('git')).to be_a(Ai::DuoWorkflows::CommandValidators::GitValidator)
      expect(described_class.validator_for('npm')).to be_a(Ai::DuoWorkflows::CommandValidators::NpmValidator)
      expect(described_class.validator_for('docker')).to be_a(Ai::DuoWorkflows::CommandValidators::DockerValidator)
      expect(described_class.validator_for('bundle')).to be_a(Ai::DuoWorkflows::CommandValidators::BundleValidator)
    end

    it 'does not register simple tools without a safe wildcard subset' do
      expect(described_class.validator_for('make')).to be_nil
      expect(described_class.validator_for('curl')).to be_nil
    end

    it 'returns nil for unregistered programs' do
      expect(described_class.validator_for('python')).to be_nil
      expect(described_class.validator_for('ruby')).to be_nil
    end
  end

  describe '.registered?' do
    it 'returns true for registered programs' do
      %w[git npm docker bundle].each do |program|
        expect(described_class.registered?(program)).to be true
      end
    end

    it 'returns false for unregistered programs' do
      %w[make curl python ruby].each do |program|
        expect(described_class.registered?(program)).to be false
      end
    end
  end
end
