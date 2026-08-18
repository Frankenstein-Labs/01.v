# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRule, :saas, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organization: organization) }
  # Call CreateService directly so create_predefined_push_rule method can run
  let(:project) { Projects::CreateService.new(user, { name: 'test', namespace: user.namespace }).execute }
  let(:global_push_rule) { create(:push_rule_sample) }

  it_behaves_like 'a push ruleable model'

  describe "Associations" do
    it { is_expected.to belong_to(:project).inverse_of(:push_rule) }
    it { is_expected.to belong_to(:organization) }
  end

  describe "Validations" do
    subject { build(:push_rule) }

    context 'presence' do
      it { is_expected.to validate_presence_of(:project_id) }

      it 'does not allow push rules with nil project_id' do
        push_rule = build(:push_rule, project: nil)

        expect(push_rule).not_to be_valid
        expect(push_rule.errors[:project_id]).to include("can't be blank")
      end
    end

    context 'uniqueness' do
      it { is_expected.to validate_uniqueness_of(:project_id).on(:create) }

      it 'prevents creating duplicate push rules for the same project' do
        create(:push_rule, project: project)

        duplicate_rule = build(:push_rule, project: project)

        expect(duplicate_rule).not_to be_valid
        expect(duplicate_rule.errors[:project_id]).to include('has already been taken')
      end
    end

    it 'validates RE2 regex syntax' do
      push_rule = build(:push_rule, branch_name_regex: '(ee|ce).*\1')

      expect(push_rule).not_to be_valid
      expect(push_rule.errors.full_messages.join).to match(/invalid escape sequence/)
    end
  end

  it 'always sets regexp_uses_re2 to true' do
    push_rule = create(:push_rule)
    expect(push_rule.regexp_uses_re2).to be(true)

    push_rule.regexp_uses_re2 = false
    expect(push_rule.regexp_uses_re2).to be(true)

    push_rule.save!
    expect(push_rule.reload.regexp_uses_re2).to be(true)
  end

  it 'cannot set regexp_uses_re2 to false' do
    push_rule = create(:push_rule)

    push_rule.regexp_uses_re2 = false
    expect(push_rule.regexp_uses_re2).to be(true)

    push_rule.update_column(:regexp_uses_re2, false)
    push_rule.reload

    push_rule.save!
    expect(push_rule.reload.regexp_uses_re2).to be(true)
  end

  describe '#branch_name_allowed?' do
    subject(:push_rule) { create(:push_rule, branch_name_regex: '\d+\-.*') }

    it 'always uses RE2 regex engine' do
      expect_any_instance_of(Gitlab::UntrustedRegexp).to receive(:===)

      subject.branch_name_allowed?('123-feature')
    end
  end

  shared_examples 'commit validated push rule' do |factory_name|
    let(:global_push_rule) { create(factory_name, organization_id: organization.id) }
    let(:settings_with_global_default) { %i[reject_unsigned_commits] }

    where(:setting, :value, :result) do
      :commit_message_regex        | 'regex'       | true
      :branch_name_regex           | 'regex'       | true
      :author_email_regex          | 'regex'       | true
      :file_name_regex             | 'regex'       | true
      :reject_unsigned_commits     | true          | true
      :commit_committer_check      | true          | true
      :commit_committer_name_check | true          | true
      :member_check                | true          | true
      :prevent_secrets             | true          | true
      :max_file_size               | 1             | false
    end

    with_them do
      context "when rule is enabled at global level" do
        before do
          stub_feature_flags(inherited_push_rule_for_project: false)
          global_push_rule.update_column(setting, value)
        end

        it "returns the default value at project level" do
          rule = project.push_rule

          if settings_with_global_default.include?(setting)
            rule.update_column(setting, nil)
          end

          expect(rule.commit_validation?).to eq(result)
        end
      end
    end
  end

  describe '#commit_validation?' do
    include_examples 'commit validated push rule', :organization_push_rule
  end

  shared_examples 'commit signature allowed push rule' do |factory_name|
    let(:global_push_rule) { create(factory_name, organization_id: organization.id) }
    let!(:premium_license) { create(:license, plan: License::PREMIUM_PLAN) }
    let(:signed_commit) { instance_double(Commit, has_signature?: true) }
    let(:unsigned_commit) { instance_double(Commit, has_signature?: false) }
    let(:push_rule) { create(:push_rule, project: project) }

    context 'when feature is not licensed and it is enabled' do
      before do
        stub_licensed_features(reject_unsigned_commits: false)
        global_push_rule.update_attribute(:reject_unsigned_commits, true)
      end

      it 'accepts unsigned commits' do
        expect(push_rule.commit_signature_allowed?(unsigned_commit)).to be(true)
      end
    end

    context 'when enabled at a global level' do
      before do
        global_push_rule.update_attribute(:reject_unsigned_commits, true)
      end

      it 'returns false if commit is not signed' do
        expect(push_rule.commit_signature_allowed?(unsigned_commit)).to be(false)
      end

      context 'and disabled at a Project level' do
        it 'returns true if commit is not signed' do
          push_rule.update_attribute(:reject_unsigned_commits, false)

          expect(push_rule.commit_signature_allowed?(unsigned_commit)).to be(true)
        end
      end

      context 'and unset at a Project level' do
        it 'returns false if commit is not signed' do
          push_rule.update_attribute(:reject_unsigned_commits, nil)

          expect(push_rule.commit_signature_allowed?(unsigned_commit)).to be(false)
        end
      end
    end

    context 'when disabled at a global level' do
      before do
        global_push_rule.update_attribute(:reject_unsigned_commits, false)
      end

      it 'returns true if commit is not signed' do
        expect(push_rule.commit_signature_allowed?(unsigned_commit)).to be(true)
      end

      context 'but enabled at a Project level' do
        before do
          push_rule.update_attribute(:reject_unsigned_commits, true)
        end

        it 'returns false if commit is not signed' do
          expect(push_rule.commit_signature_allowed?(unsigned_commit)).to be(false)
        end

        it 'returns true if commit is signed' do
          expect(push_rule.commit_signature_allowed?(signed_commit)).to be(true)
        end
      end

      context 'when user has enabled and disabled it at a project level' do
        before do
          # Let's test with the same boolean values that are sent through the form
          push_rule.update_attribute(:reject_unsigned_commits, '1')
          push_rule.update_attribute(:reject_unsigned_commits, '0')
        end

        context 'and it is enabled globally' do
          before do
            global_push_rule.update_attribute(:reject_unsigned_commits, true)
          end

          it 'returns false if commit is not signed' do
            expect(push_rule.commit_signature_allowed?(unsigned_commit)).to be(false)
          end

          it 'returns true if commit is signed' do
            expect(push_rule.commit_signature_allowed?(signed_commit)).to be(true)
          end
        end
      end
    end
  end

  describe '#commit_signature_allowed?' do
    include_examples 'commit signature allowed push rule', :organization_push_rule
  end

  describe '#committer_allowed?' do
    let_it_be(:human_user) { create(:user) }
    let_it_be(:service_account) { create(:user, :ai_service_account) }
    let_it_be(:push_rule) { create(:push_rule, commit_committer_check: true) }

    before do
      stub_licensed_features(commit_committer_check: true)
    end

    context 'when current_user has the committer email verified' do
      it 'returns true' do
        expect(push_rule.committer_allowed?(human_user.email, human_user)).to be(true)
      end
    end

    context 'when current_user is a composite identity service account', :request_store do
      before do
        ::Gitlab::Auth::Identity.new(service_account).link!(human_user)
      end

      it 'returns true when committer email is verified for the linked scope user' do
        expect(push_rule.committer_allowed?(human_user.email, service_account)).to be(true)
      end

      it 'returns true when committer email is the scope user private_commit_email' do
        expect(push_rule.committer_allowed?(human_user.private_commit_email, service_account)).to be(true)
      end

      it 'returns false when committer email is not verified for the scope user or the service account' do
        expect(push_rule.committer_allowed?('unknown@example.com', service_account)).to be(false)
      end
    end

    context 'when current_user is a service account without an active composite identity link' do
      it 'returns false when committer email is not verified for the service account' do
        expect(push_rule.committer_allowed?(human_user.email, service_account)).to be(false)
      end
    end
  end

  describe '#committer_name_allowed?' do
    let_it_be(:human_user) { create(:user, name: 'John Doe') }
    let_it_be(:service_account) { create(:user, :ai_service_account) }
    let_it_be(:push_rule) { create(:push_rule, commit_committer_name_check: true) }

    before do
      stub_licensed_features(commit_committer_name_check: true)
    end

    context 'when current_user matches the committer name' do
      it 'returns true' do
        expect(push_rule.committer_name_allowed?(human_user.name, human_user)).to be(true)
      end
    end

    context 'when committer name differs only by Unicode normalization form' do
      let_it_be(:accented_user) { create(:user, name: "Ségolène") }

      it 'returns true when the committer name is the NFD form of the account name', :aggregate_failures do
        nfd_name = "Ségolène".unicode_normalize(:nfd)

        expect(nfd_name).not_to eq(accented_user.name)
        expect(push_rule.committer_name_allowed?(nfd_name, accented_user)).to be(true)
      end

      context 'when the name does not match' do
        where(:case_name, :committer_name) do
          'a genuinely different name' | 'Someone Else'
          'a nil name'                 | nil
          'an invalid-encoding name'   | (+"foo\xC3").force_encoding("UTF-8")
          'a binary-encoded name'      | "foo".b
        end

        with_them do
          it 'returns false' do
            expect(push_rule.committer_name_allowed?(committer_name, accented_user)).to be(false)
          end
        end
      end
    end

    context 'when current_user is a composite identity service account', :request_store do
      before do
        ::Gitlab::Auth::Identity.new(service_account).link!(human_user)
      end

      it 'returns true when committer name matches the linked scope user' do
        expect(push_rule.committer_name_allowed?(human_user.name, service_account)).to be(true)
      end

      it 'returns false when committer name matches neither the service account nor the scope user' do
        expect(push_rule.committer_name_allowed?('Some Other Name', service_account)).to be(false)
      end
    end

    context 'when current_user is a service account without an active composite identity link' do
      it 'returns false when committer name is not the service account name' do
        expect(push_rule.committer_name_allowed?(human_user.name, service_account)).to be(false)
      end
    end
  end

  context 'with caching', :request_store do
    let(:push_rule) { create(:push_rule) }
    let(:push_rule_second) { create(:push_rule) }

    it 'memoizes the right push rules' do
      finder_double = instance_double(OrganizationPushRuleFinder, execute: global_push_rule)

      allow(OrganizationPushRuleFinder).to receive(:new).and_return(finder_double)

      expect(global_push_rule).to receive(:public_send).with(:commit_committer_check).and_return(false)
      expect(global_push_rule).to receive(:public_send).with(:reject_unsigned_commits).and_return(true)

      2.times do
        expect(push_rule.commit_committer_check).to be_falsey
        expect(push_rule_second.reject_unsigned_commits).to be_truthy
      end
    end
  end

  describe '#available?' do
    shared_examples 'an unavailable push_rule' do
      it 'is not available' do
        expect(push_rule.available?(:reject_unsigned_commits)).to be(false)
      end
    end

    shared_examples 'an available push_rule' do
      it 'is available' do
        expect(push_rule.available?(:reject_unsigned_commits)).to be(true)
      end
    end

    describe 'reject_unsigned_commits' do
      context 'with the global push_rule' do
        let(:push_rule) { create(:push_rule_sample) }

        context 'with a EE starter license' do
          let!(:license) { create(:license, plan: License::STARTER_PLAN) }

          it_behaves_like 'an unavailable push_rule'
        end

        context 'with a EE premium license' do
          let!(:license) { create(:license, plan: License::PREMIUM_PLAN) }

          it_behaves_like 'an available push_rule'
        end
      end

      context 'with GL.com plans' do
        let(:group) { create(:group) }
        let(:plan) { :free }
        let!(:gitlab_subscription) { create(:gitlab_subscription, plan, namespace: group) }
        let(:project) { create(:project, namespace: group) }
        let(:push_rule) { create(:push_rule, project: project) }

        before do
          create(:license, plan: License::PREMIUM_PLAN)
          stub_application_setting(check_namespace_plan: true)
        end

        shared_examples 'different payment plans verifications' do
          context 'with a Bronze plan' do
            let(:plan) { :bronze }

            it_behaves_like 'an unavailable push_rule'
          end

          context 'with a Premium plan' do
            let(:plan) { :premium }

            it_behaves_like 'an available push_rule'
          end

          context 'with a Ultimate plan' do
            let(:plan) { :ultimate }

            it_behaves_like 'an available push_rule'
          end
        end

        it_behaves_like 'different payment plans verifications'
      end
    end
  end
end
