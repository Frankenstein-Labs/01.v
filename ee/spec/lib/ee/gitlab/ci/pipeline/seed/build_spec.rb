# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Seed::Build, feature_category: :pipeline_composition do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be(:head_sha) { project.repository.head_commit.id }

  let(:pipeline) { build(:ci_empty_pipeline, project: project, sha: head_sha) }
  let(:root_variables) { [] }
  let(:seed_context) { Gitlab::Ci::Pipeline::Seed::Context.new(pipeline, root_variables: root_variables) }
  let(:attributes) { { name: 'rspec', ref: 'master', scheduling_type: :stage, when: 'on_success' } }
  let(:previous_stages) { [] }
  let(:current_stage) { instance_double(Gitlab::Ci::Pipeline::Seed::Stage, seeds_names: [attributes[:name]]) }

  let(:seed_build) { described_class.new(seed_context, attributes, previous_stages + [current_stage]) }

  describe '#attributes' do
    subject(:seed_attributes) { seed_build.attributes }

    describe 'propagating composite identity', :request_store do
      let_it_be(:user) { create(:user, :service_account, composite_identity_enforced: true) }

      let(:attributes) do
        { name: 'rspec', options: { test: 123 } }
      end

      before do
        pipeline.update!(user: user)
      end

      context 'when pipeline user supports composite identity' do
        it 'does not propagate composite identity if composite user is not linked' do
          expect(seed_attributes.key?(:scoped_user_id)).to be(false)
        end

        context 'when composite identity is linked' do
          let(:scoped_user) { create(:user) }

          before do
            ::Gitlab::Auth::Identity.fabricate(user).link!(scoped_user)
          end

          it 'propagates the composite identity as `scoped_user_id`' do
            expect(seed_attributes[:scoped_user_id]).to be(scoped_user.id)
          end
        end
      end
    end
  end
end
