# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::PromptResolvers::Base, feature_category: :ai_evaluation do
  describe 'interface' do
    it 'expects subclasses to implement abstract methods' do
      expect { described_class.execute }.to raise_error(NotImplementedError)
    end
  end

  describe '.execute' do
    subject(:prompt_version) { base_resolver.execute(user:, project:, group:) }

    let(:base_resolver) do
      Class.new(Gitlab::Llm::PromptResolvers::Base) do
        class << self
          def execute(user: nil, project: nil, group: nil)
            if user
              '1.0.0'
            elsif project
              '2.0.0'
            elsif group
              '3.0.0'
            else
              '4.0.0'
            end
          end
        end
      end
    end

    let(:user) { nil }
    let(:project) { nil }
    let(:group) { nil }

    it 'optionally accepts a user' do
      user = build_stubbed(:user)

      expect(base_resolver.execute(user:)).to eq('1.0.0')
    end

    it 'optionally accepts a project' do
      project = build_stubbed(:project)

      expect(base_resolver.execute(project:)).to eq('2.0.0')
    end

    it 'optionally accepts a group' do
      group = build_stubbed(:group)

      expect(base_resolver.execute(group:)).to eq('3.0.0')
    end

    it 'runs with no optional params' do
      expect(base_resolver.execute).to eq('4.0.0')
    end
  end
end
