# frozen_string_literal: true

require 'spec_helper'
require 'labkit/rspec/matchers'

RSpec.describe Gitlab::Graphql::UxSliByOperationName, feature_category: :vulnerability_management do
  describe '#track' do
    subject(:track) { described_class.new(operation_name).track { :result } }

    using RSpec::Parameterized::TableSyntax

    where(:operation_name, :experience_id) do
      'projectVulnerabilities'  | :render_vulnerabilities
      'groupVulnerabilities'    | :render_vulnerabilities
      'instanceVulnerabilities' | :render_vulnerabilities
    end

    with_them do
      it 'starts and completes the expected experience' do
        expect { track }.to start_user_experience(experience_id)
          .and complete_user_experience(experience_id)
      end

      it 'returns the value from the block' do
        expect(track).to eq(:result)
      end

      it 'yields control' do
        expect { |block| described_class.new(operation_name).track(&block) }.to yield_control
      end
    end
  end
end
