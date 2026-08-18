# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::ReferenceExtractor, feature_category: :source_code_management do
  let(:text) do
    <<~TXT
      This is a long text that mentions some users.
      @user-1, @user-2 and user@gitlab.org who is an @@owner ,
      take a walk in the park. There they meet @user-4 who is a
      @@Developer that was out with other-user@gitlab.org who is a @@reporter.
      @user-1 thought it was late, so went home straight away not to run into
      some @group @group/nested-on/other-group. Another @@user called
      @@test was not 100% sure that this was a good idea. Roles are
      case-insensitive and singular or plural e.g. @@developers @@DeVeLoPeR are
      both valid.
    TXT
  end

  subject(:extractor) { described_class.new(text) }

  describe '#emails' do
    it 'includes all mentioned email addresses' do
      expect(extractor.emails).to contain_exactly('user@gitlab.org', 'other-user@gitlab.org')
    end

    describe "ReDOS vulnerability" do
      subject(:extractor) do
        described_class.new(text + email)
      end

      context "when valid email length" do
        let(:email) { generate_email(100, 255) }

        it "includes the email" do
          expect(extractor.emails).to include(email)
        end
      end

      context "when invalid email first part length" do
        let(:email) { generate_email(101, 255) }

        it "doesn't include the email" do
          expect(extractor.emails).not_to include(email)
        end
      end

      context "when invalid email second part length" do
        let(:email) { generate_email(100, 256) }

        it "doesn't include the email" do
          expect(extractor.emails).not_to include(email)
        end
      end
    end
  end

  describe '#names' do
    it 'includes all mentioned usernames and groupnames' do
      expect(extractor.names).to contain_exactly(
        'user-1', 'user-2', 'user-4', 'group', 'group/nested-on/other-group'
      )
    end
  end

  describe '#references' do
    it 'includes all user-references once' do
      expect(extractor.references).to contain_exactly(
        'user-1', 'user-2', 'user@gitlab.org', 'user-4',
        'other-user@gitlab.org', 'group', 'group/nested-on/other-group',
        Gitlab::Access::DEVELOPER, Gitlab::Access::OWNER
      )
    end
  end

  describe '#roles' do
    context 'when mentioned in text with email and name references' do
      it 'includes mentioned developer and owner roles' do
        expect(extractor.roles).to contain_exactly(
          Gitlab::Access::DEVELOPER, Gitlab::Access::OWNER
        )
      end

      it 'does not included the reporter role' do
        expect(extractor.roles).not_to include(Gitlab::Access::REPORTER)
      end
    end

    context 'when vanilla roles are specified' do
      let(:text) do
        <<~TXT
          @@owner @@maintainer
          filename @@developer
          @@developer
          filename @@reporter
          filename @@guest
        TXT
      end

      it 'matches possible roles' do
        expect(extractor.roles).to contain_exactly(
          Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER, Gitlab::Access::OWNER
        )
      end
    end

    context 'when possible roles have forbidden prefixes' do
      let(:text) do
        <<~TXT
          filename a@@owner @@@maintainer
          filename @developer
        TXT
      end

      it 'does not match them' do
        expect(extractor.roles).to be_empty
      end
    end

    context 'when possible roles have suffixes' do
      let(:text) do
        <<~TXT
          filename @@owner. @@maintainers
          filename @@developersy
        TXT
      end

      it 'only matches permissible ones' do
        expect(extractor.roles).to contain_exactly(
          Gitlab::Access::MAINTAINER
        )
      end
    end

    context 'when possible roles have unconventional casing' do
      let(:text) do
        <<~TXT
          filename @@Owner
          filename @@mAintainer
          filename @@deVeloperS
        TXT
      end

      it 'matches them' do
        expect(extractor.roles).to contain_exactly(
          Gitlab::Access::OWNER, Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER
        )
      end
    end

    context 'when roles are duplicated' do
      let(:text) do
        <<~TXT
          filename @@owner @@owner @@OWNER @@owners @@Owners
          filename @@mAintainer @@maintainers @@MAINTAINERS
          filename @@deVeloperS @@developers @@developer
        TXT
      end

      it 'deduplicates them' do
        expect(extractor.roles).to contain_exactly(
          Gitlab::Access::OWNER, Gitlab::Access::MAINTAINER, Gitlab::Access::DEVELOPER
        )
      end
    end
  end

  describe '#raw_names' do
    subject { extractor.raw_names }

    it { is_expected.to contain_exactly('@user-1', '@user-2', '@user-4', '@group', '@group/nested-on/other-group') }
  end

  describe '#raw_roles' do
    subject { extractor.raw_roles }

    it { is_expected.to contain_exactly('@@Developer', '@@owner', '@@developers', '@@DeVeLoPeR') }
  end

  describe '#raw_emails' do
    subject { extractor.raw_emails }

    it { is_expected.to match_array(extractor.emails) }
  end

  describe '#raw_references' do
    subject { extractor.raw_references }

    it { is_expected.to match_array(extractor.raw_names + extractor.raw_roles + extractor.raw_emails) }
  end

  def generate_email(left_length, right_length)
    "#{SecureRandom.alphanumeric(left_length)}@#{SecureRandom.alphanumeric(right_length)}"
  end
end
