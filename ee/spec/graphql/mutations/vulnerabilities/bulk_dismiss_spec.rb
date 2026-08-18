# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Vulnerabilities::BulkDismiss, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:vulnerabilities) { create_list(:vulnerability, 2, :with_findings, project: project) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }
  let(:vulnerability_ids) { vulnerabilities.map(&:to_global_id) }
  let(:comment) { 'Dismissal Feedback' }
  let(:dismissal_reason) { 'used_in_tests' }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  subject do
    mutation.resolve(
      vulnerability_ids: vulnerability_ids,
      comment: comment,
      dismissal_reason: dismissal_reason
    )
  end

  describe '#resolve' do
    it 'does not introduce N+1 errors' do
      control = ActiveRecord::QueryRecorder.new { subject }

      # Add more vulnerabilities to the project to ensure the query count is stable
      create(:vulnerability, :with_findings, project: project)

      expect { subject }.not_to exceed_query_limit(control)
    end
  end
end
