# frozen_string_literal: true

RSpec.shared_examples 'a local virtual registry object' do
  subject { described_class.new }

  it { is_expected.to include_module(::VirtualRegistries::Local) }
  it { is_expected.to be_local }
  it { is_expected.not_to be_remote }
end

RSpec.shared_examples 'a remote virtual registry object' do
  subject { described_class.new }

  it { is_expected.to include_module(::VirtualRegistries::Remote) }
  it { is_expected.to be_remote }
  it { is_expected.not_to be_local }
end
