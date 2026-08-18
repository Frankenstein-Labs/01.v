# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Security::RefreshProjectPoliciesWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let(:project_member_changed_event) do
    ::ProjectAuthorizations::AuthorizationsChangedEvent.new(data: { project_id: project.id })
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { project_member_changed_event }

    it 'receives the event after some delay' do
      expect(described_class).to receive(:perform_in).with(1.minute, any_args)
      ::Gitlab::EventStore.publish(event)
    end
  end
end
