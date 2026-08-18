# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Group::NamespaceFilterPolicy, feature_category: :audit_events do
  using RSpec::Parameterized::TableSyntax

  before do
    stub_licensed_features(external_audit_events: true)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }
  let_it_be_with_reload(:namespace_filter) do
    create(:audit_events_streaming_group_namespace_filters,
      external_streaming_destination: destination, namespace: subgroup)
  end

  subject { described_class.new(user, namespace_filter) }

  where(:user_type, :allowed) do
    :anonymous  | false
    :guest      | false
    :developer  | false
    :maintainer | false
    :owner      | true
  end

  with_them do
    context "for user type #{params[:user_type]}" do
      before do
        group.public_send("add_#{user_type}", user) unless user_type == :anonymous
      end

      if params[:allowed]
        it { is_expected.to be_allowed(:admin_external_audit_events) }
      else
        it { is_expected.not_to be_allowed(:admin_external_audit_events) }
      end
    end
  end
end
