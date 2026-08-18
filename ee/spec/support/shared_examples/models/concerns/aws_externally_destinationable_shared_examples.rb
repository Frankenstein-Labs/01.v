# frozen_string_literal: true

RSpec.shared_examples 'includes AwsExternallyDestinationable concern' do
  using RSpec::Parameterized::TableSyntax

  subject(:configuration) { build(model_factory_name, aws_region: region) }

  where(:region, :is_valid) { AuditEvents::AwsRegionTestCases::CASES }

  with_them do
    it { expect(configuration.valid?).to eq(is_valid) }
  end

  it 'strips surrounding whitespace from the region' do
    configuration = build(model_factory_name, aws_region: '  us-east-1  ')

    expect(configuration).to be_valid
    expect(configuration.aws_region).to eq('us-east-1')
  end

  it 'explains what a valid region looks like' do
    configuration = build(model_factory_name, aws_region: 'us east 1')

    expect(configuration).not_to be_valid
    expect(configuration.errors.full_messages)
      .to include('AWS region must be a valid region code, for example us-east-1')
  end

  it 'reports only the presence error when the region is blank' do
    configuration = build(model_factory_name, aws_region: '')

    expect(configuration).not_to be_valid
    expect(configuration.errors[:aws_region]).to contain_exactly("can't be blank")
  end

  context 'when an existing record already stores a malformed region' do
    # save! skips before_validation too, so assign_default_name never runs and the
    # name has to be set explicitly to satisfy the NOT NULL constraint.
    let(:existing) do
      build(model_factory_name, name: 'existing-destination', aws_region: stored_region)
        .tap { |record| record.save!(validate: false) }
    end

    let(:stored_region) { 'us east 1' }

    it 'can still be renamed without correcting the region' do
      existing.name = 'renamed'

      expect(existing).to be_valid
    end

    context 'when the stored region also carries surrounding whitespace' do
      let(:stored_region) { 'us east 1 ' }

      it 'can still be renamed, and the strip does not dirty the record' do
        existing.name = 'renamed'

        expect(existing).to be_valid
        expect(existing.aws_region).to eq('us east 1 ')
      end
    end

    it 'can still be deactivated without correcting the region' do
      expect { existing.deactivate! }.not_to raise_error
      expect(existing.reload).not_to be_active
    end

    it 'is rejected as soon as the region itself is changed' do
      existing.aws_region = 'us west 2'

      expect(existing).not_to be_valid
      expect(existing.errors.full_messages)
        .to include('AWS region must be a valid region code, for example us-east-1')
    end
  end
end
