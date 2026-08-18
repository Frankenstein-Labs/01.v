# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflow::BaseService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  subject(:service) do
    described_class.new(
      project: project,
      current_user: current_user
    )
  end

  before_all do
    project.add_maintainer(current_user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe '#execute' do
    context 'when the user is authorized' do
      it 'raises NotImplementedError' do
        expect { service.execute }
          .to raise_error(
            NotImplementedError,
            'Vulnerabilities::BulkDuoWorkflow::BaseService subclasses must implement #perform'
          )
      end
    end

    context 'when the user is unauthorized' do
      let_it_be(:guest) { create(:user) }

      subject(:service) do
        described_class.new(
          project: project,
          current_user: guest
        )
      end

      it 'raises an access denied error' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(bulk_vulnerabilities_duo_workflow_api: false)
      end

      it 'raises an access denied error' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end
  end
end
