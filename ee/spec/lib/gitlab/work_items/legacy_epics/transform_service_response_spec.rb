# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::WorkItems::LegacyEpics::TransformServiceResponse, feature_category: :team_planning do
  let(:created_references) { %w[reference1 reference2] }
  let(:error_message_creator) do
    Gitlab::WorkItems::IssuableLinks::ErrorMessage.new(target_type: 'epic')
  end

  describe '#transform' do
    subject(:transform) do
      described_class.new(result: result).transform(created_references_lambda: -> {
        created_references
      }, error_message_lambda: -> { error_message_creator })
    end

    context 'when status is success' do
      let(:result) { { status: :success, message: 'Success message', work_item: 'Work item' } }

      it 'returns a success response' do
        expect(transform).to eq({
          status: :success,
          created_references: created_references
        })
      end

      it 'removes message and work_item keys' do
        expect(transform).not_to include(:message, :work_item)
      end
    end

    context 'when status is error' do
      context 'with already assigned error' do
        let(:result) { { status: :error, message: 'Epic already assigned' } }

        it 'returns a conflict response' do
          expect(transform).to include(status: :error, http_status: 409, message: 'Epic(s) already assigned')
        end
      end

      context 'with not found error' do
        let(:result) { { status: :error, message: 'No matching work item found' } }

        it 'returns a not found response' do
          expect(transform).to include(status: :error, http_status: 404,
            message: 'No matching epic found. Make sure that you are adding a valid epic URL.'
          )
        end
      end
    end
  end
end
