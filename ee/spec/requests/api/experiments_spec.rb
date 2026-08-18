# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Experiments, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, name: 'GitLab.com', path: 'gitlab-com') }

  let(:definition_yaml) { Rails.root.join("config/feature_flags/experiment/null_hypothesis.yml") }

  describe 'GET /experiments' do
    context 'when on .com', :saas do
      before do
        stub_experiments(null_hypothesis: :candidate)

        definition = YAML.load_file(definition_yaml).deep_symbolize_keys!
        allow(Feature::Definition.definitions).to receive(:values).and_return(
          [
            Feature::Definition.new(definition_yaml.to_s, definition),
            Feature::Definition.new(
              'foo/non_experiment.yml',
              definition.merge(type: 'development', name: 'non_experiment')
            )
          ])
      end

      it 'returns a 401 for anonymous users' do
        get api('/experiments')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'returns a 403 for users' do
        get api('/experiments', user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'returns a 403 for non human users' do
        bot = create(:user, :bot)
        group.add_developer(bot)

        get api('/experiments', bot)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      context 'for gitlab team members' do
        before_all do
          group.add_developer(user)
        end

        it_behaves_like 'authorizing granular token permissions', :read_experiment do
          let(:boundary_object) { :instance }
          let(:request) do
            get api('/experiments', personal_access_token: pat)
          end
        end

        it 'returns the feature flag details', :aggregate_failures do
          get api('/experiments', user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include({
            key: 'null_hypothesis',
            context: ['user'],
            definition: {
              name: 'null_hypothesis',
              feature_issue_url: nil,
              introduced_by_url: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/45840',
              rollout_issue_url: nil,
              intended_to_rollout_by: nil,
              milestone: '13.7',
              type: 'experiment',
              group: 'group::acquisition',
              default_enabled: false,
              log_state_changes: nil
            },
            current_status: {
              state: :off,
              gates: [
                {
                  key: :boolean,
                  value: false
                },
                {
                  key: :expression,
                  value: nil
                }
              ]
            }
          }.as_json)
        end

        it 'understands the state of the feature flag and what that means for an experiment', :aggregate_failures do
          Feature.enable_percentage_of_actors(:null_hypothesis, 1)

          get api('/experiments', user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include(hash_including({
            key: 'null_hypothesis',
            current_status: {
              state: :conditional,
              gates: [
                {
                  key: :boolean,
                  value: false
                },
                {
                  key: :expression,
                  value: nil
                },
                {
                  key: :percentage_of_actors,
                  value: 1
                }
              ]
            }
          }.as_json))
        end

        describe 'the null_hypothesis as a canary' do
          # This group of test ensures that we will continue to have a functional
          # backend experiment. It's part of the suite of tooling that's in place to
          # ensure that we don't change notable aspects of experimentation, like
          # the position of the contexts etc.
          #
          # We wrap our experiments endpoint in a canary like experiment that if
          # broken will render this endpoint visibly broken.
          #
          # This is something of an integration level and shouldn't be adjusted
          # without proper consultation with the relevant Growth teams.

          it 'runs and tracks the expected events' do
            contexts = []

            # Yes, we really do want to test this and the only way to get here
            # is by calling a private method.
            expect(Gitlab::Tracking.send(:tracker)).to receive(:event).with(
              'null_hypothesis',
              'assignment',
              label: nil,
              property: nil,
              value: nil,
              context: [
                instance_of(SnowplowTracker::SelfDescribingJson),
                instance_of(SnowplowTracker::SelfDescribingJson)
              ]
            ) { |_, _, **options| contexts = options[:context] }

            get api('/experiments', user)

            # Ensure the order of the contexts stays correct for now.
            #
            # If you change this, you need to talk with the growth team,
            # because some reporting is done (incorrectly) based on the index
            # of this context.
            expect(contexts[1].to_json).to include({
              schema: 'iglu:com.gitlab/gitlab_experiment/jsonschema/1-0-0',
              data: {
                experiment: 'null_hypothesis',
                key: anything,
                variant: 'candidate'
              }
            })
          end

          it 'returns a 400 if experimentation seems broken', :aggregate_failures do
            # we assume that rendering control would only be done in error.
            stub_experiments(null_hypothesis: :control)

            get api('/experiments', user)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response).to eq({
              message: '400 Bad request - experimentation may not be working right now'
            }.as_json)
          end

          it 'publishes into a collection of experiments that have been run in the request' do
            expect(RequestStore).to receive(:clear!).and_wrap_original do |clear|
              expect(ApplicationExperiment.published_experiments['null_hypothesis']).to include(
                excluded: false,
                experiment: 'null_hypothesis',
                variant: 'candidate'
              )

              clear.call
            end

            get api('/experiments', user)
          end
        end
      end
    end

    context 'when not .com' do
      before_all do
        group.add_developer(user)
      end

      it 'returns a 403 for users' do
        get api('/experiments', user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /experiments/:name/cache' do
    let(:experiment_name) { 'some_experiment' }

    context 'when on .com', :saas do
      it 'returns a 401 for anonymous users' do
        delete api("/experiments/#{experiment_name}/cache")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'returns a 403 for users' do
        delete api("/experiments/#{experiment_name}/cache", user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'returns a 403 for non human users' do
        bot = create(:user, :bot)
        group.add_developer(bot)

        delete api("/experiments/#{experiment_name}/cache", bot)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      context 'for gitlab team members' do
        let(:cache_store) { instance_double(Gitlab::Experiment::Cache::RedisHashStore, clear: nil) }

        before_all do
          group.add_developer(user)
        end

        before do
          allow(Gitlab::Experiment::Configuration).to receive(:cache).and_return(cache_store)
        end

        it_behaves_like 'authorizing granular token permissions', :delete_experiment_cache do
          let(:boundary_object) { :instance }
          let(:request) do
            delete api("/experiments/#{experiment_name}/cache", personal_access_token: pat)
          end
        end

        it 'clears the cache for the given experiment name and returns 204', :aggregate_failures do
          expect(cache_store).to receive(:clear).with(key: experiment_name)

          delete api("/experiments/#{experiment_name}/cache", user)

          expect(response).to have_gitlab_http_status(:no_content)
        end

        it 'returns 400 when the name references a non-hash cache key' do
          allow(cache_store).to receive(:clear).and_raise(ArgumentError)

          delete api("/experiments/#{experiment_name}/cache", user)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when not .com' do
      before_all do
        group.add_developer(user)
      end

      it 'returns a 403 for users' do
        delete api("/experiments/#{experiment_name}/cache", user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'experiment assignments endpoints', :saas do
    let(:experiment_name) { 'null_hypothesis' }
    let_it_be(:target_user) { create(:user) }

    before do
      allow(Gitlab::Experiment::Configuration).to receive(:cache).and_call_original
    end

    after do
      Gitlab::Experiment::Configuration.cache&.clear(key: experiment_name)
    end

    shared_examples 'requires gitlab team member' do
      it 'returns 401 for anonymous users' do
        make_request(nil)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'returns 403 for non-team members' do
        make_request(user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    describe 'GET /experiments/:experiment_name/assignments' do
      def make_request(request_user, params: { context: { user: target_user.username } })
        get api("/experiments/#{experiment_name}/assignments", request_user), params: params
      end

      it_behaves_like 'requires gitlab team member'

      context 'for gitlab team members' do
        before_all do
          group.add_developer(user)
        end

        it_behaves_like 'authorizing granular token permissions', :read_experiment do
          let(:boundary_object) { :instance }
          let(:request) do
            get api("/experiments/#{experiment_name}/assignments", personal_access_token: pat)
          end
        end

        it 'returns the current assignment status' do
          make_request(user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include(
            'experiment' => experiment_name,
            'variant' => nil,
            'cached' => false
          )
          expect(json_response['context_key']).to be_present
        end

        context 'without context params' do
          it 'defaults to current user' do
            make_request(user, params: {})

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include(
              'experiment' => experiment_name,
              'cached' => false
            )
            expect(json_response['context_key']).to be_present
          end
        end

        context 'when a variant is cached' do
          before do
            Experiments::AssignmentService.new(
              experiment_name: experiment_name,
              variant: 'candidate',
              context_params: { user: target_user.username },
              current_user: user
            ).write
          end

          it 'returns the cached variant' do
            make_request(user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include(
              'experiment' => experiment_name,
              'variant' => 'candidate',
              'cached' => true
            )
          end
        end

        context 'with invalid context' do
          it 'returns bad request' do
            make_request(user, params: { context: { user: 'nonexistent_user' } })

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('User not found')
          end
        end

        context 'when the experiment class does not declare context keys' do
          before do
            allow(NullHypothesisExperiment).to receive(:context_keys).and_return(nil)
          end

          it 'returns bad request' do
            make_request(user)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('does not declare `context_keys`')
          end
        end
      end
    end

    describe 'POST /experiments/:experiment_name/assignments' do
      def make_request(request_user, params: { variant: 'candidate', context: { user: target_user.username } })
        post api("/experiments/#{experiment_name}/assignments", request_user), params: params
      end

      it_behaves_like 'requires gitlab team member' do
        def make_request(request_user)
          post api("/experiments/#{experiment_name}/assignments", request_user),
            params: { variant: 'candidate', context: { user: target_user.username } }
        end
      end

      context 'for gitlab team members' do
        before_all do
          group.add_developer(user)
        end

        context 'with a granular personal access token' do
          let(:pat) { create(:granular_pat, user: user) }

          it 'denies access because the endpoint defers granular token authorization' do
            post api("/experiments/#{experiment_name}/assignments", personal_access_token: pat),
              params: { variant: 'candidate', context: { user: target_user.username } }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        it 'forces the variant assignment' do
          make_request(user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include(
            'experiment' => experiment_name,
            'variant' => 'candidate',
            'cached' => true
          )
          expect(json_response['context_key']).to be_present
        end

        it 'persists the assignment in cache' do
          make_request(user)

          result = Experiments::AssignmentService.new(
            experiment_name: experiment_name,
            context_params: { user: target_user.username },
            current_user: user
          ).read

          expect(result.payload[:variant]).to eq('candidate')
        end

        context 'without context params' do
          it 'defaults to current user' do
            make_request(user, params: { variant: 'candidate' })

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include(
              'experiment' => experiment_name,
              'variant' => 'candidate'
            )
          end
        end

        context 'with invalid context' do
          it 'returns bad request' do
            make_request(user, params: { variant: 'candidate', context: { user: 'nonexistent_user' } })

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when the variant is blank' do
          it 'returns bad request' do
            make_request(user, params: { variant: '', context: { user: target_user.username } })

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end
    end

    describe 'DELETE /experiments/:experiment_name/assignments' do
      def make_request(request_user, params: { context: { user: target_user.username } })
        delete api("/experiments/#{experiment_name}/assignments", request_user), params: params
      end

      def read_assignment_for(context_user)
        Experiments::AssignmentService.new(
          experiment_name: experiment_name,
          context_params: { user: context_user.username },
          current_user: user
        ).read.payload
      end

      it_behaves_like 'requires gitlab team member'

      context 'for gitlab team members' do
        before_all do
          group.add_developer(user)
        end

        context 'with a granular personal access token' do
          let(:pat) { create(:granular_pat, user: user) }

          it 'denies access because the endpoint defers granular token authorization' do
            delete api("/experiments/#{experiment_name}/assignments", personal_access_token: pat),
              params: { context: { user: target_user.username } }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when a variant is cached' do
          before do
            Experiments::AssignmentService.new(
              experiment_name: experiment_name,
              variant: 'candidate',
              context_params: { user: target_user.username },
              current_user: user
            ).write
          end

          it 'clears the assignment and returns 204' do
            make_request(user)

            expect(response).to have_gitlab_http_status(:no_content)
          end

          it 'removes the assignment from the cache' do
            make_request(user)

            payload = read_assignment_for(target_user)

            expect(payload[:variant]).to be_nil
            expect(payload[:cached]).to be false
          end

          context 'when another context has its own cached variant' do
            let_it_be(:other_user) { create(:user) }

            before do
              Experiments::AssignmentService.new(
                experiment_name: experiment_name,
                variant: 'control',
                context_params: { user: other_user.username },
                current_user: user
              ).write
            end

            it 'clears only the targeted context', :aggregate_failures do
              make_request(user)

              expect(read_assignment_for(target_user)[:variant]).to be_nil
              expect(read_assignment_for(other_user)[:variant]).to eq('control')
            end
          end
        end

        context 'when no variant is cached' do
          it 'is idempotent and returns 204' do
            make_request(user)

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end

        context 'without context params' do
          it 'defaults to current user and returns 204' do
            make_request(user, params: {})

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end

        context 'with invalid context' do
          it 'returns bad request' do
            make_request(user, params: { context: { user: 'nonexistent_user' } })

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('User not found')
          end
        end
      end
    end
  end
end
