# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DataBuilder::MemberApprovalBuilder, feature_category: :seat_cost_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:requested_by) { build_stubbed(:user) }
  let_it_be(:reviewed_by) { build_stubbed(:user) }

  let_it_be(:approval) do
    build_stubbed(
      :gitlab_subscription_member_management_member_approval,
      user: user,
      requested_by: requested_by
    )
  end

  let_it_be(:failed_approvals) do
    build_stubbed_list(:gitlab_subscription_member_management_member_approval, 2)
  end

  describe '.build' do
    context 'when event is :queued' do
      let(:data) { described_class.build(event: :queued, approval: approval) }

      it { expect(data).to be_a(Hash) }
      it { expect(data[:object_kind]).to eq('gitlab_subscription_member_approval') }
      it { expect(data[:action]).to eq('enqueue') }

      context 'when approval is nil' do
        let(:approval) { nil }

        it 'raises ArgumentError' do
          expect { data }
            .to raise_error(ArgumentError, "Need to pass approval object to build queued event.")
        end
      end

      it 'contains the correct attributes' do
        expect(data).to include(
          object_attributes: approval.hook_attrs,
          user_id: user.id,
          requested_by_user_id: requested_by.id,
          promotion_namespace_id: approval.member_namespace_id,
          created_at: approval.created_at.xmlschema,
          updated_at: approval.updated_at.xmlschema
        )
      end

      context 'when requested_by is nil' do
        let(:approval) do
          build_stubbed(
            :gitlab_subscription_member_management_member_approval,
            user: user,
            requested_by: nil
          )
        end

        it 'includes nil for requested_by_user_id' do
          expect(data[:requested_by_user_id]).to be_nil
        end
      end
    end

    context 'when event is :approved' do
      let(:updated_at) { Time.current }
      let(:updated_at_str) { updated_at.xmlschema }
      let(:data) do
        described_class.build(
          event: :approved,
          reviewed_by: reviewed_by,
          user: user,
          status: :success,
          failed_approvals: failed_approvals,
          reviewed_at: updated_at
        )
      end

      it { expect(data).to be_a(Hash) }
      it { expect(data[:object_kind]).to eq('gitlab_subscription_member_approvals') }
      it { expect(data[:action]).to eq('approve') }

      it 'contains the correct attributes', :aggregate_failures do
        expect(data).to include(
          reviewed_by_user_id: reviewed_by.id,
          user_id: user.id,
          updated_at: updated_at_str
        )
        expect(data[:object_attributes]).to include(
          status: :success,
          promotion_request_ids_that_failed_to_apply: failed_approvals.map(&:id)
        )
      end
    end

    context 'when event is :denied' do
      let(:updated_at) { Time.current }
      let(:updated_at_str) { updated_at.xmlschema }
      let(:data) do
        described_class.build(
          event: :denied,
          reviewed_by: reviewed_by,
          user: user,
          status: :success,
          reviewed_at: updated_at
        )
      end

      it { expect(data).to be_a(Hash) }
      it { expect(data[:object_kind]).to eq('gitlab_subscription_member_approvals') }
      it { expect(data[:action]).to eq('deny') }

      it 'contains the correct attributes' do
        expect(data).to include(
          reviewed_by_user_id: reviewed_by.id,
          user_id: user.id,
          updated_at: updated_at_str
        )
        expect(data[:object_attributes]).to include(
          status: :success
        )
      end
    end

    shared_examples_for 'avoids N+1 queries' do
      specify do
        # First call to establish baseline
        described_class.build(**build_params)

        # Record queries for control
        control = ActiveRecord::QueryRecorder.new { described_class.build(**build_params) }

        # Create additional resources
        create_additional_resources

        # Verify no N+1 queries
        expect { described_class.build(**build_params) }
          .not_to exceed_query_limit(control)
      end
    end

    context 'when building approved events' do
      let(:reviewed_at) { Time.current }
      let(:build_params) do
        {
          event: :approved,
          reviewed_by: reviewed_by,
          user: user,
          status: :success,
          failed_approvals: failed_approvals,
          reviewed_at: reviewed_at
        }
      end

      it_behaves_like 'avoids N+1 queries' do
        let(:additional_approvals) do
          create_list(
            :gitlab_subscription_member_management_member_approval,
            3
          )
        end

        let(:create_additional_resources) do
          # Add more failed approvals to test for N+1
          build_params[:failed_approvals] += additional_approvals
        end
      end
    end
  end
end
