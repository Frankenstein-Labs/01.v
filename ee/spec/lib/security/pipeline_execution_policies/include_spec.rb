# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::Include, feature_category: :security_policy_management do
  describe '#project' do
    context 'when project is present' do
      it 'returns the project value' do
        include_item = described_class.new({ project: 'group/project', file: 'path/to/file.yml' })
        expect(include_item.project).to eq('group/project')
      end
    end

    context 'when project is not present' do
      it 'returns nil' do
        include_item = described_class.new({ file: 'path/to/file.yml' })
        expect(include_item.project).to be_nil
      end
    end
  end

  describe '#file' do
    context 'when file is present' do
      it 'returns the file value' do
        include_item = described_class.new({ project: 'group/project', file: 'path/to/file.yml' })
        expect(include_item.file).to eq('path/to/file.yml')
      end
    end

    context 'when file is not present' do
      it 'returns nil' do
        include_item = described_class.new({ project: 'group/project' })
        expect(include_item.file).to be_nil
      end
    end
  end

  describe '#ref' do
    context 'when ref is present' do
      it 'returns the ref value' do
        include_item = described_class.new({ project: 'group/project', file: 'path/to/file.yml', ref: 'main' })
        expect(include_item.ref).to eq('main')
      end

      it 'handles branch names' do
        include_item = described_class.new({ project: 'group/project', file: 'path/to/file.yml',
ref: 'feature-branch' })
        expect(include_item.ref).to eq('feature-branch')
      end

      it 'handles commit SHAs' do
        include_item = described_class.new({ project: 'group/project', file: 'path/to/file.yml', ref: 'abc123def456' })
        expect(include_item.ref).to eq('abc123def456')
      end
    end

    context 'when ref is not present' do
      it 'returns nil' do
        include_item = described_class.new({ project: 'group/project', file: 'path/to/file.yml' })
        expect(include_item.ref).to be_nil
      end
    end
  end

  describe 'complete include item' do
    it 'handles include with all fields' do
      include_data = {
        project: 'group/project',
        file: 'compliance/pipeline.yml',
        ref: 'main'
      }
      include_item = described_class.new(include_data)

      expect(include_item.project).to eq('group/project')
      expect(include_item.file).to eq('compliance/pipeline.yml')
      expect(include_item.ref).to eq('main')
    end

    it 'handles include with only required fields' do
      include_data = {
        project: 'group/project',
        file: 'compliance/pipeline.yml'
      }
      include_item = described_class.new(include_data)

      expect(include_item.project).to eq('group/project')
      expect(include_item.file).to eq('compliance/pipeline.yml')
      expect(include_item.ref).to be_nil
    end
  end
end
