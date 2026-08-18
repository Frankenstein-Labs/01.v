# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::Content, feature_category: :security_policy_management do
  describe '#include' do
    context 'when include is present' do
      it 'returns an array of Include instances' do
        content_data = {
          include: [
            { project: 'group/project', file: 'compliance/pipeline.yml', ref: 'main' }
          ]
        }
        content = described_class.new(content_data)
        expect(content.include).to be_an(Array)
        expect(content.include.first).to be_a(Security::PipelineExecutionPolicies::Include)
      end

      it 'handles include with all fields' do
        content_data = {
          include: [
            { project: 'group/project', file: 'compliance/pipeline.yml', ref: 'main' }
          ]
        }
        content = described_class.new(content_data)

        include_item = content.include[0]
        expect(include_item.project).to eq('group/project')
        expect(include_item.file).to eq('compliance/pipeline.yml')
        expect(include_item.ref).to eq('main')
      end
    end

    context 'when include is not present' do
      it 'returns an empty array' do
        content = described_class.new({})
        expect(content.include).to be_an(Array)
        expect(content.include).to be_empty
      end
    end

    context 'when content is nil' do
      it 'returns an empty array' do
        content = described_class.new(nil)
        expect(content.include).to be_an(Array)
        expect(content.include).to be_empty
      end
    end
  end
end
