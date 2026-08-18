# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks::BaseCheck, feature_category: :vulnerability_management do
  let_it_be(:project) { build_stubbed(:project) }

  let(:implementation) { Class.new(described_class) }
  let(:instance) { implementation.new(project) }

  describe 'synchronticity' do
    it 'defaults to false' do
      expect(implementation.synchronous?).to be(false)
    end

    it 'enqueues checks async by default' do
      expect(Vulnerabilities::ConsistencyCheckWorker).to receive(:perform_async)
        .with(implementation.name, project.id)

      implementation.enqueue(project)
    end

    context 'when implementation is declared as synchronous' do
      let(:implementation) do
        Class.new(described_class) do
          synchronous_check!
        end
      end

      it 'returns true' do
        expect(implementation.synchronous?).to be(true)
      end

      it 'enqueues checks synchronously' do
        expect_next_instance_of(described_class, project) do |next_instance|
          expect(next_instance).to receive(:execute)
        end

        implementation.enqueue(project)
      end
    end
  end

  describe '.execute' do
    it 'instantiates instance and calls #execute' do
      double = instance_double(described_class.name)

      expect(described_class).to receive(:new).with(project).and_return(double)
      expect(double).to receive(:execute)

      described_class.execute(project)
    end
  end

  describe '#fix!' do
    it 'raises an error when not defined on implementation' do
      expect { instance.fix! }.to raise_error('Must implement #fix!')
    end
  end

  describe '#consistent?' do
    it 'defaults to false' do
      expect(instance.consistent?).to be(false)
    end
  end
end
