# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CustomRoles::CodeGenerator, :silence_stdout, feature_category: :permissions do
  before do
    allow(MemberRole).to receive(:all_customizable_permissions).and_return(
      { test_new_ability: { feature_category: 'vulnerability_management' } }
    )
  end

  let(:ability) { 'test_new_ability' }
  let(:config) { { destination_root: destination_root } }
  let(:args) { ['--ability', ability] }

  subject(:run_generator) { described_class.start(args, config) }

  context 'when the ability is not yet defined' do
    let(:ability) { 'non_existing_ability' }

    it 'raises an error' do
      expect { run_generator }.to raise_error(ArgumentError)
    end
  end

  def destination_root
    File.expand_path("../tmp", __dir__)
  end
end
