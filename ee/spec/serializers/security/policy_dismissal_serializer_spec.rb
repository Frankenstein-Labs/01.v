# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyDismissalSerializer, feature_category: :security_policy_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:merge_request) { build_stubbed(:merge_request, source_project: project) }
  let_it_be(:security_orchestration_policy_configuration) do
    build_stubbed(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:security_policy) do
    build_stubbed(:security_policy,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy_dismissal) do
    build_stubbed(:policy_dismissal,
      project: project,
      merge_request: merge_request,
      security_policy: security_policy,
      user: user,
      dismissal_types: [0, 3],
      comment: 'Test dismissal comment')
  end

  let(:serializer) { described_class.new(current_user: user) }

  describe '#represent' do
    subject(:represent) { serializer.represent(policy_dismissal) }

    it 'serializes the policy dismissal correctly' do
      expect(represent).to include(
        id: policy_dismissal.id,
        created_at: policy_dismissal.created_at,
        updated_at: policy_dismissal.updated_at,
        project_id: project.id,
        merge_request_id: merge_request.id,
        security_policy_id: security_policy.id,
        user_id: user.id,
        dismissal_types: ['Policy false positive', 'Other'],
        comment: 'Test dismissal comment'
      )
    end
  end
end
