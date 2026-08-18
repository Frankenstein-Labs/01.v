# frozen_string_literal: true

RSpec.shared_examples_for 'singleton record validation' do
  it 'allows creating the first record' do
    setting = described_class.new

    expect(setting).to be_valid
  end

  it 'prevents creating a second record' do
    _first_setting = described_class.create!
    second_setting = described_class.new

    expect(second_setting).not_to be_valid
    expect(second_setting.errors[:base]).to include("There can only be one #{described_class.name.demodulize} record")
  end

  it 'ensures only one record exists through the instance method' do
    first_instance = described_class.instance
    second_instance = described_class.instance

    expect(described_class.count).to eq(1)
    expect(first_instance).to eq(second_instance)
  end

  it "handles concurrent requests without uniqueness violations" do
    barrier = Concurrent::CyclicBarrier.new(2)

    allow(described_class).to receive(:first) do
      # Simulate slow database query to force race condition
      sleep 0.1
      nil
    end

    thread1 = Thread.new do
      ApplicationRecord.connection_pool.with_connection do
        barrier.wait
        described_class.instance
      end
    end

    thread2 = Thread.new do
      ApplicationRecord.connection_pool.with_connection do
        barrier.wait
        described_class.instance
      end
    end

    expect do
      thread1.join
      thread2.join
    end.not_to raise_error

    expect(described_class.count).to eq(1)
  end
end
