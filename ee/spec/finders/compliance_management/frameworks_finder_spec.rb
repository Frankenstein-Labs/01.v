# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::FrameworksFinder, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:framework1) { create(:compliance_framework, name: 'framework1', namespace: group) }
  let_it_be(:framework2) { create(:compliance_framework, name: 'framework2', namespace: group) }
  let_it_be(:framework3) { create(:compliance_framework, name: 'framework3', namespace: group) }

  let(:params) { { ids: [framework1.id, framework3.id] } }

  subject(:result) { described_class.new(user, params).execute }

  describe '#execute' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: true)
      end

      context 'when user is authorized' do
        before_all do
          group.add_developer(user)
        end

        it 'returns frameworks based on user access filtered by ids' do
          expect(result).to contain_exactly(framework1, framework3)
        end
      end

      context 'when user is unauthorized' do
        it 'returns an empty array' do
          expect(result).to be_empty
        end
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: false)
      end

      before_all do
        group.add_owner(user)
      end

      it 'returns an empty array' do
        expect(result).to be_empty
      end
    end
  end

  describe 'validating params' do
    context 'when ids param is present' do
      it 'does not raise an error' do
        expect { result }.not_to raise_error
      end
    end

    context 'when ids param is not provided' do
      let(:params) { {} }

      it 'raises an ArgumentError' do
        expect { result }.to raise_error(ArgumentError, 'filter param, :ids has to be provided')
      end
    end

    context 'when ids param is empty' do
      let(:params) { { ids: [] } }

      it 'raises an ArgumentError' do
        expect { result }.to raise_error(ArgumentError, 'filter param, :ids has to be provided')
      end
    end
  end
end
