# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Protection::UpdateTagRuleService, feature_category: :container_registry do
  let(:service) { described_class.new(container_protection_tag_rule, current_user: build(:user), params: params) }
  let(:params) do
    attributes_for(
      :container_registry_protection_tag_rule,
      tag_name_pattern: 'v1*',
      minimum_access_level_for_delete: ::Gitlab::Access::OWNER,
      minimum_access_level_for_push: ::Gitlab::Access::OWNER
    )
  end

  subject(:service_execute) { service.execute }

  context 'when the rule is immutable' do
    let(:container_protection_tag_rule) { build(:container_registry_protection_tag_rule, :immutable) }

    it_behaves_like 'returning an error service response', message: 'Operation not allowed'
  end
end
