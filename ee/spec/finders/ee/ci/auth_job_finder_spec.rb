# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::AuthJobFinder, feature_category: :continuous_integration do
  describe '#execute!', :request_store do
    subject(:execute) { described_class.new(token: token).execute! }

    let_it_be(:scoped_user) { create(:user) }
    let_it_be_with_reload(:user) { create(:user, :service_account, composite_identity_enforced: true) }
    let_it_be_with_refind(:job) { create(:ci_build, status: :running, user: user) }

    context 'when job has a `scoped_user_id` tracked' do
      let(:token) { job.token }

      shared_examples 'job user that supports composite identity' do
        it 'links the scoped user as composite identity' do
          expect(job.scoped_user).to eq(scoped_user)

          execute

          expect(::Gitlab::Auth::Identity.new(job.user)).to be_linked
        end
      end

      context 'when the scoped_user_id is stored in job definition options' do
        before do
          stub_ci_job_definition(job, options: job.options.merge(scoped_user_id: scoped_user.id))
        end

        it_behaves_like 'job user that supports composite identity'
      end

      context 'when the scoped_user_id is stored in the builds table' do
        before do
          job.update!(scoped_user_id: scoped_user.id)
        end

        it_behaves_like 'job user that supports composite identity'
      end

      context 'when the scoped_user_id is stored in both locations' do
        before do
          stub_ci_job_definition(job, options: job.options.merge(scoped_user_id: non_existing_record_id))
          job.update!(scoped_user_id: scoped_user.id)
        end

        it_behaves_like 'job user that supports composite identity'
      end
    end
  end
end
