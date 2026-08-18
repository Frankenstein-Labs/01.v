# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::V2ApprovalRules::BaseService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { name: 'Test Rule', approvals_required: 2 } }

  subject(:service) { described_class.new(merge_request, current_user, params) }

  describe '#initialize' do
    it 'sets merge_request, current_user, project, and params' do
      expect(service).to have_attributes(
        merge_request: merge_request,
        current_user: current_user,
        project: project,
        params: params
      )
    end

    it 'defaults params to empty hash' do
      service = described_class.new(merge_request, current_user)

      expect(service.params).to eq({})
    end
  end

  describe '#execute' do
    context 'when merge_request is nil' do
      subject(:service) { described_class.new(nil, current_user, params) }

      it 'returns error with message' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Merge request is required')
      end
    end

    context 'when user is not authorized' do
      it 'returns access denied error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq(%w[Prohibited])
        expect(result.reason).to eq(:access_denied)
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_maintainer(current_user)
      end

      it 'delegates to action' do
        expect { service.execute }.to raise_error(Gitlab::AbstractMethodError)
      end

      context 'when subclass implements action' do
        let(:test_service_class) do
          Class.new(described_class) do
            private

            def action
              success(data: 'test')
            end
          end
        end

        it 'returns a successful ServiceResponse with payload' do
          result = test_service_class.new(merge_request, current_user, params).execute

          expect(result).to be_success
          expect(result.payload).to eq({ data: 'test' })
        end
      end
    end
  end
end
