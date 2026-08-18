# frozen_string_literal: true

RSpec.shared_examples 'a Geo bulk update worker' do |model_name:, service:|
  include ::EE::GeoHelpers

  it_behaves_like 'an idempotent worker' do
    let_it_be(:job_args, freeze: false) { model_name }
  end

  describe 'concurrent execution and deduplication' do
    before do
      stub_current_geo_node(create(:geo_node, :primary))
      create_list(factory_name(model_name.constantize), 2, :verification_succeeded)
    end

    it 'deduplicates jobs' do
      Sidekiq::Testing.fake! do
        described_class.clear

        3.times { described_class.perform_async(model_name) }

        expect(described_class.jobs.size).to eq(1)
        expect(described_class.jobs.first['args']).to eq([model_name])
      end
    end

    it 'schedules continuation jobs when time limit is reached' do
      Sidekiq::Testing.fake! do
        described_class.clear

        stubbed_service = instance_double(service)
        allow(service).to receive(:new).and_return(stubbed_service)
        allow(stubbed_service).to receive(:execute) do
          described_class.perform_in(service::PERFORM_IN, model_name)
          ServiceResponse.error(message: 'Time limit reached', payload: { status: :limit_reached })
        end

        described_class.new.perform(model_name)

        expect(described_class.jobs.size).to eq(1)
        expect(described_class.jobs.first['args']).to eq([model_name])
      end
    end
  end
end
