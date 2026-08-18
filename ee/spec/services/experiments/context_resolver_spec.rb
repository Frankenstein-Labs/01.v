# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Experiments::ContextResolver, feature_category: :acquisition do
  describe '#resolve', :aggregate_failures do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    let(:experiment_name) { 'null_hypothesis' }
    let(:context_params) { { user: user.username } }

    subject(:resolve) do
      described_class.new(
        experiment_name: experiment_name, context_params: context_params, current_user: user
      ).resolve
    end

    context 'with a resolvable user context' do
      it 'returns success with the resolved context' do
        expect(resolve).to be_success
        expect(resolve.payload[:context]).to eq(user: user)
      end
    end

    context 'when context is empty' do
      let(:context_params) { {} }

      it 'defaults to current user' do
        expect(resolve).to be_success
        expect(resolve.payload[:context]).to eq(user: user)
      end

      it 'reuses the current user without querying the database again' do
        expect(User).not_to receive(:find_by_username)

        expect(resolve.payload[:context][:user]).to be(user)
      end
    end

    context 'when context is invalid' do
      let(:context_params) { { user: 'nonexistent_user' } }

      it 'returns error' do
        expect(resolve).to be_error
        expect(resolve.message).to eq('User not found: nonexistent_user')
      end
    end

    context 'when experiment does not exist' do
      let(:experiment_name) { 'nonexistent_experiment' }

      it 'returns error' do
        expect(resolve).to be_error
        expect(resolve.message).to include('not found')
      end
    end

    context 'when the feature flag exists but is not an experiment' do
      let(:experiment_name) { 'not_an_experiment' }

      before do
        stub_feature_flag_definition(experiment_name, type: 'development')
      end

      it 'returns error' do
        expect(resolve).to be_error
        expect(resolve.message).to eq("'not_an_experiment' is not an experiment")
      end
    end

    context 'when the experiment is not registered as a class' do
      let(:experiment_name) { 'unregistered_experiment' }

      before do
        stub_feature_flag_definition(experiment_name, type: 'experiment')
      end

      it 'returns error' do
        expect(resolve).to be_error
        expect(resolve.message).to eq("Experiment 'unregistered_experiment' is not registered as an experiment class")
      end
    end

    context 'when the experiment class does not declare context keys' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys).and_return(nil)
      end

      it 'returns error with guidance' do
        expect(resolve).to be_error
        expect(resolve.message).to include('does not declare `context_keys`')
      end
    end

    context 'when the experiment class does not override context_keys' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys)
          .and_raise(Gitlab::AbstractMethodError, 'NullHypothesisExperiment must define `self.context_keys`')
      end

      it 'returns error with guidance' do
        expect(resolve).to be_error
        expect(resolve.message).to include('does not declare `context_keys`')
      end
    end

    context 'when context is provided without the required user key' do
      let(:context_params) { { namespace: namespace.full_path } }

      it 'returns error' do
        expect(resolve).to be_error
        expect(resolve.message).to eq('user is required')
      end
    end

    context 'when the experiment declares an unsupported context key' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys).and_return([:group])
      end

      let(:context_params) { { user: user.username } }

      it 'returns error rather than silently omitting the key' do
        expect(resolve).to be_error
        expect(resolve.message).to eq('Unsupported context key: group')
      end
    end

    context 'when the experiment declares an actor context' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys).and_return([:actor])
      end

      context 'with a resolvable user' do
        let(:context_params) { { user: user.username } }

        it 'resolves the actor from the user' do
          expect(resolve).to be_success
          expect(resolve.payload[:context]).to eq(actor: user)
        end
      end

      context 'when the user cannot be found' do
        let(:context_params) { { user: 'nonexistent_user' } }

        it 'returns error' do
          expect(resolve).to be_error
          expect(resolve.message).to eq('User not found: nonexistent_user')
        end
      end

      context 'when context is empty' do
        let(:context_params) { {} }

        it 'defaults the actor to the current user' do
          expect(resolve).to be_success
          expect(resolve.payload[:context]).to eq(actor: user)
        end
      end

      context 'when context is provided without the user key' do
        let(:context_params) { { namespace: namespace.full_path } }

        it 'returns error' do
          expect(resolve).to be_error
          expect(resolve.message).to eq('user is required')
        end
      end
    end

    context 'when the experiment declares a namespace context' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys).and_return([:namespace])
      end

      context 'with a resolvable namespace' do
        let(:context_params) { { namespace: namespace.full_path } }

        it 'returns success with the resolved namespace' do
          expect(resolve).to be_success
          expect(resolve.payload[:context]).to eq(namespace: namespace)
        end
      end

      context 'when the namespace cannot be found' do
        let(:context_params) { { namespace: 'nonexistent/namespace' } }

        it 'returns error' do
          expect(resolve).to be_error
          expect(resolve.message).to eq('Namespace not found: nonexistent/namespace')
        end
      end

      context 'when no namespace is provided' do
        let(:context_params) { {} }

        it 'returns error' do
          expect(resolve).to be_error
          expect(resolve.message).to eq('namespace is required')
        end
      end
    end

    context 'when the experiment declares a project context' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys).and_return([:project])
      end

      context 'with a resolvable project' do
        let(:context_params) { { project: project.full_path } }

        it 'returns success with the resolved project' do
          expect(resolve).to be_success
          expect(resolve.payload[:context]).to eq(project: project)
        end
      end

      context 'when the project cannot be found' do
        let(:context_params) { { project: 'nonexistent/project' } }

        it 'returns error' do
          expect(resolve).to be_error
          expect(resolve.message).to eq('Project not found: nonexistent/project')
        end
      end

      context 'when no project is provided' do
        let(:context_params) { {} }

        it 'returns error' do
          expect(resolve).to be_error
          expect(resolve.message).to eq('project is required')
        end
      end
    end

    context 'when the experiment declares multiple context keys' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys).and_return(%i[user namespace])
      end

      context 'when all keys resolve' do
        let(:context_params) { { user: user.username, namespace: namespace.full_path } }

        it 'returns success with all resolved keys' do
          expect(resolve).to be_success
          expect(resolve.payload[:context]).to eq(user: user, namespace: namespace)
        end
      end

      context 'when one key fails to resolve' do
        let(:context_params) { { user: user.username, namespace: 'nonexistent/namespace' } }

        it 'returns error' do
          expect(resolve).to be_error
          expect(resolve.message).to eq('Namespace not found: nonexistent/namespace')
        end
      end
    end
  end
end
