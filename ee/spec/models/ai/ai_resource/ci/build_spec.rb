# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::Ci::Build, feature_category: :duo_chat do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:build) { create(:ci_build, project: project) }
  let(:user) { create(:user) }
  let(:content_limit) { 100000 }

  subject(:wrapped_build) { described_class.new(user, build) }

  describe '#serialize_for_ai' do
    it 'calls the serializations class' do
      expect(Ci::JobSerializer)
        .to receive_message_chain(:new, :represent)
        .with(current_user: user)
        .with(build, {
          user: user,
          content_limit: content_limit,
          resource: wrapped_build
        }, ::Ci::JobAiEntity)

      wrapped_build.serialize_for_ai(content_limit: content_limit)
    end
  end

  describe '#current_page_type' do
    it 'returns type' do
      expect(wrapped_build.current_page_type).to eq('build')
    end
  end

  describe '#current_page_params' do
    it 'returns params to construct prompt' do
      expect(wrapped_build.current_page_params.keys).to eq([:type])
    end
  end
end
