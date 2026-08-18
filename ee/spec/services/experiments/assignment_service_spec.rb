# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Experiments::AssignmentService, :aggregate_failures, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }

  let(:experiment_name) { 'null_hypothesis' }
  let(:variant) { 'candidate' }
  let(:context_params) { { user: user.username } }
  let(:current_user) { user }

  let(:service) do
    described_class.new(
      experiment_name: experiment_name,
      variant: variant,
      context_params: context_params,
      current_user: current_user
    )
  end

  before do
    allow(Gitlab::Experiment::Configuration).to receive(:cache).and_call_original
  end

  after do
    Gitlab::Experiment::Configuration.cache&.clear(key: experiment_name)
  end

  describe '#write' do
    subject(:write) { service.write }

    context 'when variant is blank' do
      let(:variant) { nil }

      it 'returns error' do
        expect(write).to be_error
        expect(write.message).to eq('Variant is required')
      end
    end

    context 'when experiment does not exist' do
      let(:experiment_name) { 'nonexistent_experiment' }

      it 'returns error' do
        expect(write).to be_error
        expect(write.message).to include('not found')
      end
    end

    context 'when experiment does not declare context_keys' do
      before do
        allow(NullHypothesisExperiment).to receive(:context_keys).and_return(nil)
      end

      it 'returns error with guidance' do
        expect(write).to be_error
        expect(write.message).to include('does not declare `context_keys`')
      end
    end

    context 'when username is provided but user not found' do
      let(:context_params) { { user: 'nonexistent_user' } }

      it 'returns error' do
        expect(write).to be_error
        expect(write.message).to eq("User not found: nonexistent_user")
      end
    end

    context 'when context is empty' do
      let(:context_params) { {} }

      it 'defaults to current user and returns success' do
        expect(write).to be_success
        expect(write.payload[:experiment]).to eq(experiment_name)
        expect(write.payload[:variant]).to eq('candidate')
      end
    end

    context 'with valid parameters' do
      it 'returns success with payload' do
        expect(write).to be_success
        expect(write.payload[:experiment]).to eq(experiment_name)
        expect(write.payload[:variant]).to eq('candidate')
        expect(write.payload[:context_key]).to be_present
        expect(write.payload[:cached]).to be true
      end

      it 'writes variant to experiment cache' do
        write

        read_result = service.read
        expect(read_result.payload[:variant]).to eq('candidate')
      end
    end

    context 'with an arbitrary variant name' do
      let(:variant) { 'custom_variant' }

      it 'writes the variant without validation' do
        expect(write).to be_success
        expect(write.payload[:variant]).to eq('custom_variant')
      end
    end
  end

  describe '#read' do
    subject(:read) { service.read }

    context 'when no cached variant exists' do
      it 'returns success with nil variant' do
        expect(read).to be_success
        expect(read.payload[:experiment]).to eq(experiment_name)
        expect(read.payload[:variant]).to be_nil
        expect(read.payload[:cached]).to be false
        expect(read.payload[:context_key]).to be_present
      end
    end

    context 'when cached variant exists' do
      before do
        service.write
      end

      it 'returns success with cached variant' do
        expect(read).to be_success
        expect(read.payload[:experiment]).to eq(experiment_name)
        expect(read.payload[:variant]).to eq('candidate')
        expect(read.payload[:cached]).to be true
      end
    end

    context 'when context is empty' do
      let(:context_params) { {} }

      it 'reads using the current user as the default context' do
        expect(read).to be_success
        expect(read.payload[:experiment]).to eq(experiment_name)
        expect(read.payload[:context_key]).to be_present
      end
    end

    context 'when context resolution fails' do
      let(:context_params) { { user: 'nonexistent_user' } }

      it 'returns the resolver error without reading' do
        expect(read).to be_error
        expect(read.message).to eq('User not found: nonexistent_user')
      end
    end
  end

  describe '#clear' do
    subject(:clear) { service.clear }

    context 'when a variant is cached' do
      before do
        service.write
      end

      it 'returns success' do
        expect(clear).to be_success
      end

      it 'removes the variant from the experiment cache' do
        clear

        read_result = service.read
        expect(read_result.payload[:variant]).to be_nil
        expect(read_result.payload[:cached]).to be false
      end
    end

    context 'when no variant is cached' do
      it 'is idempotent and returns success' do
        expect(clear).to be_success
      end
    end

    context 'when context is empty' do
      let(:context_params) { {} }

      it 'defaults to current user and returns success' do
        expect(clear).to be_success
      end
    end

    context 'when context resolution fails' do
      let(:context_params) { { user: 'nonexistent_user' } }

      it 'returns the resolver error without clearing' do
        expect(clear).to be_error
        expect(clear.message).to eq('User not found: nonexistent_user')
      end
    end
  end
end
