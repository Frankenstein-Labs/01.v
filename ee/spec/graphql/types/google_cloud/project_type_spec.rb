# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudProject'], feature_category: :runner_core do
  using RSpec::Parameterized::TableSyntax

  specify { expect(described_class.graphql_name).to eq('GoogleCloudProject') }

  describe '.coerce_input' do
    subject(:input) { described_class.coerce_isolated_input(project_name) }

    context 'when project name is valid' do
      where(:project_name) { %w[a-project-id a-2-project-with-numbers] }

      with_them do
        it 'coerces project name to same string' do
          expect(input).to eq(project_name)
        end
      end
    end

    context 'when project name is not valid' do
      where(:project_name) { %w[-project-id a-2-project-with-numbers- a_project_id] }

      with_them do
        it 'raises an exception' do
          expect { input }.to raise_error(GraphQL::CoercionError).with_message(%r{is not a valid project name})
        end
      end
    end
  end

  describe '.coerce_result' do
    subject(:result) { described_class.coerce_isolated_result(:'project-id') }

    it 'coerces a symbol to a string' do
      expect(result).to eq('project-id')
    end
  end
end
