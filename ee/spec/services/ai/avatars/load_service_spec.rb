# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Avatars::LoadService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let(:project) { build_stubbed(:project) }
  let(:item) { build_stubbed(:ai_catalog_flow, project: project) }

  subject(:avatar) { described_class.new(item).execute }

  describe '#execute' do
    context 'when item is agent' do
      let(:item) { build_stubbed(:ai_catalog_agent, project: project) }

      it 'returns nil' do
        expect(avatar).to be_nil
      end
    end

    context 'when item is a flow' do
      it 'returns a file object for custom-flow' do
        expect(avatar).to be_a(File)
        expect(avatar.path).to include('custom-flow')
      end

      it 'returns nil if the file does not exist' do
        allow(File).to receive(:open).and_raise(Errno::ENOENT)

        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
        expect(avatar).to be_nil
      end
    end

    context 'when item is a third_party_flow' do
      let(:item) { build_stubbed(:ai_catalog_third_party_flow, project: project) }

      it 'returns a file object for external-agent.png' do
        expect(avatar).to be_a(File)
        expect(avatar.path).to include('external-agent.png')
      end

      it 'returns nil if the file does not exist' do
        allow(File).to receive(:open).and_raise(Errno::ENOENT)

        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
        expect(avatar).to be_nil
      end
    end

    context 'when item is a flow with foundational_flow_reference' do
      let(:item) do
        build_stubbed(:ai_catalog_flow, :public, project: project, foundational_flow_reference: 'code_review/v1')
      end

      it 'returns a file object for the workflow definition avatar' do
        expect(avatar).to be_a(File)
        expect(avatar.path).to include('code-review-flow.png')
      end

      it 'returns nil if the file does not exist' do
        allow(File).to receive(:open).and_raise(Errno::ENOENT)

        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
        expect(avatar).to be_nil
      end
    end

    context 'when item is a flow with foundational_flow_reference but workflow definition has no avatar' do
      let(:item) do
        build_stubbed(:ai_catalog_flow, :public, project: project, foundational_flow_reference: 'sast_fp_detection/v1')
      end

      before do
        allow(Ai::Catalog::FoundationalFlow).to receive(:[]).with('sast_fp_detection/v1')
                                                                   .and_return(Ai::Catalog::FoundationalFlow.new)
      end

      it 'returns nil' do
        expect(avatar).to be_nil
      end
    end

    context 'when item is a flow with foundational_flow_reference but workflow definition does not exist' do
      let(:item) do
        build_stubbed(:ai_catalog_flow, :public, project: project, foundational_flow_reference: 'nonexistent/v1')
      end

      it 'returns nil' do
        expect(avatar).to be_nil
      end
    end
  end
end
