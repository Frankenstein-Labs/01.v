# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Standards::RefreshService, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }

  subject(:service) { described_class.new(group: group, current_user: user) }

  describe '#execute' do
    before do
      stub_licensed_features(group_level_compliance_adherence_report: true)
    end

    context 'for user namespace' do
      let_it_be(:group) { create(:namespace, owner: user) }

      it 'returns an error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq("namespace must be a group")
      end
    end

    context 'when user does not have required permissions' do
      before_all do
        group.add_maintainer(user)
      end

      it 'returns an error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq("Access denied for user id: #{user.id}")
      end
    end

    context 'when user has permissions' do
      before_all do
        group.add_owner(user)
      end

      context 'when we do not have cached progress in redis', :freeze_time do
        it 'returns correct values' do
          expect(ComplianceManagement::Standards::RefreshWorker).to receive(:perform_async).with(
            { 'group_id' => group.id, 'user_id' => user.id })

          expect_next_instance_of(ComplianceManagement::StandardsAdherenceChecksTracker, group.id) do |tracker|
            expect(tracker).to receive(:progress)
          end

          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ started_at: Time.current.utc.to_s,
                                           total_checks: "1", checks_completed: "0" })
        end
      end

      context 'when we have cached progress in redis', :sidekiq_inline, :freeze_time do
        it 'returns correct values' do
          expect(ComplianceManagement::Standards::RefreshWorker).to receive(:perform_async).with(
            { 'group_id' => group.id, 'user_id' => user.id }).and_call_original

          response = service.execute

          expect(response).to be_success
          expect(response.payload).to eq({ started_at: Time.current.utc.to_s,
                                           total_checks: "6", checks_completed: "0" })
        end
      end
    end
  end
end
