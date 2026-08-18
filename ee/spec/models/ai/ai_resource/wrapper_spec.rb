# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::Wrapper, feature_category: :duo_chat do
  describe "#wrap" do
    subject(:wrap) { described_class.new(user, resource).wrap }

    let(:user) { create(:user) }

    describe '#wrap' do
      context 'when resource wrapper class exists' do
        let(:resource) { build(:issue) }
        let(:authorizer_double) { instance_double(::Gitlab::Llm::Utils::Authorizer::Response) }

        before do
          allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer)
            .to receive(:resource).with(resource: resource, user: user)
              .and_return(authorizer_double)
        end

        context 'when user is authorized' do
          before do
            allow(authorizer_double).to receive(:allowed?).and_return(true)
          end

          it 'returns wrapped resource' do
            is_expected.to be_kind_of(Ai::AiResource::Issue)
          end
        end

        context 'when user is not authorized' do
          before do
            allow(authorizer_double).to receive(:allowed?).and_return(false)
          end

          it 'returns nil' do
            is_expected.to be_nil
          end
        end
      end

      context 'when resource wrapper class does not exist' do
        let(:resource) { build(:vulnerability) }

        it 'raises ArgumentError' do
          expect { wrap }.to raise_error(ArgumentError, 'Vulnerability is not a valid AiResource class')
        end
      end
    end
  end
end
