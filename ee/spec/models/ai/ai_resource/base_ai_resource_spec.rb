# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::BaseAiResource, feature_category: :duo_chat do
  describe '#serialize_for_ai' do
    it 'raises NotImplementedError' do
      expect { described_class.new(nil, nil).serialize_for_ai(_content_limit: nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe '#current_page_params' do
    it 'returns params to construct prompt' do
      expect { described_class.new(nil, nil).current_page_params }
        .to raise_error(NotImplementedError)
    end
  end

  describe '#default_content_limit' do
    it 'returns params to construct prompt' do
      expect(described_class.new(nil, nil).default_content_limit).to eq(100_000)
    end
  end

  describe '#root_namespace' do
    let(:resource) { double }

    subject(:root_namespace) { described_class.new(nil, resource).root_namespace }

    context 'when resource has a project' do
      let_it_be(:project) { create(:project) }

      before do
        allow(resource).to receive(:project).and_return(project)
      end

      it 'returns the project root namespace' do
        expect(root_namespace).to be(project.root_namespace)
      end
    end

    context 'when resource has a group' do
      let_it_be(:group) { create(:group) }

      before do
        allow(resource).to receive(:group).and_return(group)
      end

      it 'returns the project root namespace' do
        expect(root_namespace).to be(group.root_ancestor)
      end
    end

    context 'when resource is nil' do
      let(:resource) { nil }

      it 'is nil' do
        expect(root_namespace).to be_nil
      end
    end

    context 'when resource has no group nor namespace' do
      it 'is nil' do
        expect(root_namespace).to be_nil
      end
    end
  end
end
