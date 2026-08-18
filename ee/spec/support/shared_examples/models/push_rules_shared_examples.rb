# frozen_string_literal: true

# Shared examples for models that include the PushRuleable concern.
RSpec.shared_examples 'a push ruleable model' do
  # NOTE: We use push_rule prefix for convenience to refer to any push ruleable class.
  # Do not confuse it with the `PushRule` model, which is associated with a project only.
  let(:push_rule_name) { described_class.name.underscore.to_sym }
  # rubocop:disable Rails/SaveBang -- This is not creating a record but a factory.
  # See Rubocop issue: https://github.com/thoughtbot/factory_bot/issues/1620
  let(:push_rule_record) { create(push_rule_name) }
  # rubocop:enable Rails/SaveBang

  describe 'validations' do
    described_class::SHORT_REGEX_COLUMNS.each do |column|
      context "with #{column}: length validation" do
        it { is_expected.to validate_length_of(column).is_at_most(511) }
      end
    end

    described_class::LONG_REGEX_COLUMNS.each do |column|
      context "with #{column}: length validation" do
        it { is_expected.to validate_length_of(column).is_at_most(2047) }
      end
    end

    it 'validates max_file_size' do
      is_expected.to validate_numericality_of(:max_file_size)
        .is_greater_than_or_equal_to(0)
        .is_less_than_or_equal_to(Gitlab::Database::MAX_INT_VALUE)
        .only_integer
    end
  end

  describe '#available?' do
    it 'implements the available? instance method' do
      expect { push_rule_record.available?(:reject_non_dco_commits) }.not_to raise_error
    end
  end

  describe '#branch_name_allowed?' do
    subject(:push_rule_record) { create(push_rule_name, branch_name_regex: '\d+\-.*') }

    it 'checks branch against regex' do
      expect(push_rule_record.branch_name_allowed?('123-feature')).to be true
      expect(push_rule_record.branch_name_allowed?('feature-123')).to be false
    end

    it 'tolerates nil messages' do
      expect(push_rule_record.branch_name_allowed?(nil)).to be false
    end
  end

  describe '#commit_message_allowed?' do
    subject(:push_rule_record) { create(push_rule_name, commit_message_regex: '^Signed-off-by') }

    it 'uses multiline regex' do
      commit_message = "Some git commit feature\n\nSigned-off-by: Someone"

      expect(push_rule_record.commit_message_allowed?(commit_message)).to be true
    end

    it 'tolerates nil messages' do
      expect(push_rule_record.commit_message_allowed?(nil)).to be false
    end
  end

  describe '#commit_message_blocked?' do
    subject(:push_rule_record) { create(push_rule_name, commit_message_negative_regex: 'commit') }

    it 'uses multiline regex' do
      commit_message = "Some git commit feature\n\nSigned-off-by: Someone"

      expect(push_rule_record.commit_message_blocked?(commit_message)).to be true
    end

    it 'tolerates nil messages' do
      expect(push_rule_record.commit_message_blocked?(nil)).to be false
    end

    context 'when commit message with break line in the last' do
      subject(:push_rule_record) { create(push_rule_name, commit_message_negative_regex: '^[0-9]*$') }

      it 'uses multiline regex' do
        commit_message = "Some git commit feature\n"
        expect(push_rule_record.commit_message_blocked?(commit_message)).to be false
      end
    end

    context 'when commit message without break line in the last' do
      subject(:push_rule_record) { create(push_rule_name, commit_message_negative_regex: '^[0-9]*$') }

      it 'uses multiline regex' do
        commit_message = "1234"
        expect(push_rule_record.commit_message_blocked?(commit_message)).to be true
      end
    end
  end

  methods_and_regexes = {
    commit_message_allowed?: :commit_message_regex,
    commit_message_blocked?: :commit_message_negative_regex,
    branch_name_allowed?: :branch_name_regex,
    author_email_allowed?: :author_email_regex,
    filename_denylisted?: :file_name_regex
  }

  methods_and_regexes.each do |method_name, regex_attr|
    describe "##{method_name}" do
      it 'raises a MatchError when the regex is invalid' do
        push_rule_record[regex_attr] = '+'

        expect { push_rule_record.public_send(method_name, 'foo') }
          .to raise_error(PushRule::MatchError, /\ARegular expression '\+' is invalid/)
      end
    end
  end
end
