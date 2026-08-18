# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::UserPaidStatusCheckWorker,
  :saas, :use_clean_rails_redis_caching, feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:pipl_user) { create(:pipl_user, user: user) }

  let(:cache_key) { [ComplianceManagement::Pipl::PIPL_SUBJECT_USER_CACHE_KEY, user.id] }

  it_behaves_like 'an idempotent worker' do
    subject(:worker) { described_class.new }

    where(:user_is_paid, :subject_to_pipl) do
      true  | false
      false | true
    end

    with_them do
      before do
        if user_is_paid
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
        else
          create(:group_with_plan, plan: :free_plan, developers: user)
        end
      end

      it "caches the user's subject to PIPL status for 24 hours",
        :aggregate_failures,
        :freeze_time do
        expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 24.hours).and_call_original

        assert_subject_to_pipl?(subject_to_pipl)
      end

      context 'when enforce_pipl_compliance setting is disabled' do
        before do
          stub_ee_application_setting(enforce_pipl_compliance: false)
        end

        it "caches the user's subject to PIPL status for 24 hours", :aggregate_failures do
          expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 24.hours).and_call_original
          assert_subject_to_pipl?(subject_to_pipl)
        end
      end
    end

    context 'when user belongs to a paid namespace as a guest' do
      context 'when namespace plan excludes guests from billable users' do
        it 'treats the user as paid' do
          create(:group_with_plan, plan: :ultimate_plan, guests: user)

          assert_subject_to_pipl?(false)
        end
      end

      context 'when namespace plan treats guests as billable users' do
        it 'treats the user as paid' do
          create(:group_with_plan, plan: :premium_plan, guests: user)

          assert_subject_to_pipl?(false)
        end
      end
    end

    context 'when user belongs to a paid namespace with minimal access' do
      it 'treats the user as paid' do
        stub_licensed_features(minimal_access_role: true)

        group = create(:group_with_plan, plan: :ultimate_plan)
        create(:group_member, :minimal_access, source: group, user: user)

        assert_subject_to_pipl?(false)
      end
    end

    context 'when user cannot be found' do
      it 'does not do anything' do
        expect(Rails.cache).not_to receive(:fetch)

        worker.perform(non_existing_record_id)
      end
    end

    context 'when the user is subject to pipl and becomes paid', :freeze_time do
      let(:days_ago) { 10.days.ago }

      before do
        create(:group_with_plan, plan: :ultimate_plan, developers: user)
        user.pipl_user.update!(initial_email_sent_at: days_ago)
      end

      it 'resets the pipl timestamp' do
        expect { worker.perform(user.id) }
          .to change { pipl_user.reload.initial_email_sent_at }
                .from(days_ago)
                .to(nil)
      end
    end
  end

  def assert_subject_to_pipl?(subject_to_pipl)
    return assert_subject_to_pipl_with_email(subject_to_pipl) if subject_to_pipl

    assert_subject_to_pipl_without_email(subject_to_pipl)
  end

  def assert_subject_to_pipl_without_email(subject_to_pipl)
    expect(ComplianceManagement::Pipl::SendInitialComplianceEmailService).not_to receive(:new)
    expect { worker.perform(user.id) }
      .to change { Rails.cache.read(cache_key) }
            .from(nil).to(subject_to_pipl)
  end

  def assert_subject_to_pipl_with_email(subject_to_pipl)
    expect(ComplianceManagement::Pipl::SendInitialComplianceEmailService).to receive(:new).and_call_original
    expect { worker.perform(user.id) }
      .to change { Rails.cache.read(cache_key) }
            .from(nil).to(subject_to_pipl)
  end
end
