# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::EnqueueJobService, '#execute', feature_category: :continuous_integration do
  let_it_be(:project, freeze: true) { create(:project, :repository) }
  let_it_be(:pipeline, freeze: true) { create(:ci_pipeline, project: project) }
  let_it_be(:environment, freeze: true) { create(:environment, project: project, name: 'production') }
  let_it_be(:guest, freeze: true) { create(:user, guest_of: project) }
  let_it_be(:reporter, freeze: true) { create(:user, reporter_of: project) }
  let_it_be(:developer, freeze: true) { create(:user, developer_of: project) }
  let_it_be(:maintainer, freeze: true) { create(:user, maintainer_of: project) }
  let_it_be(:owner, freeze: true) { create(:user, owner_of: project) }

  let(:job) { create(:ci_build, :manual, pipeline: pipeline, environment: environment.name, project: project) }

  subject(:execute) { described_class.new(job, current_user: current_user).execute }

  describe 'environment access' do
    before do
      stub_licensed_features(protected_environments: true)
    end

    shared_examples 'enqueues the job' do
      it 'returns the job in pending state' do
        expect(execute).to eq(job)
        expect(job.reload).to be_pending
      end
    end

    shared_examples 'raises access denied' do
      it { expect { execute }.to raise_error(Gitlab::Access::AccessDeniedError) }
    end

    context 'when environment is not protected' do
      where(:current_user) { [ref(:developer), ref(:maintainer), ref(:owner)] }
      with_them { it_behaves_like 'enqueues the job' }

      where(:current_user) { [ref(:guest), ref(:reporter)] }
      with_them { it_behaves_like 'raises access denied' }
    end

    context 'when environment is protected' do
      let!(:protected_environment) do
        create(:protected_environment, name: environment.name, project: project)
      end

      context 'without deploy access' do
        where(:current_user) { [ref(:guest), ref(:reporter), ref(:developer), ref(:maintainer), ref(:owner)] }
        with_them { it_behaves_like 'raises access denied' }
      end

      context 'with deploy access' do
        before do
          protected_environment.deploy_access_levels.create!(user: current_user)
        end

        context 'when user is a guest' do
          let(:current_user) { guest }

          it_behaves_like 'raises access denied'
        end

        where(:current_user) { [ref(:reporter), ref(:developer), ref(:maintainer), ref(:owner)] }
        with_them { it_behaves_like 'enqueues the job' }
      end
    end
  end
end
