# frozen_string_literal: true

RSpec.shared_context 'orchestration policy context' do
  let_it_be(:policy_last_updated_at, freeze: false) { Time.now }
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:policy_management_project, freeze: false) { create(:project) }
  let_it_be(:user, freeze: false) { create(:user) }
end
