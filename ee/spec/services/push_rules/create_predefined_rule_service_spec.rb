# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRules::CreatePredefinedRuleService, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(container: project, current_user: user, params: {}) }

  describe "#execute" do
    let_it_be_with_reload(:global_push_rule) do
      create(:organization_push_rule, organization_id: project.organization.id)
    end

    describe "guard clauses" do
      context "when feature is unavailable" do
        before do
          allow(project).to receive(:feature_available?).with(:push_rules).and_return(false)
        end

        it "returns nil" do
          # #predefined_push_rule is the second guard clause, immediately following the
          #   feature check, so we test it here to ensure that we're failing the
          #   **expected** guard clause.
          #
          expect(service).not_to receive(:predefined_push_rule)
          expect(service.execute).to be_nil
        end
      end

      context "when there is no existing predefined push rule" do
        before do
          allow(service).to receive(:predefined_push_rule).and_return(nil)
        end

        it "returns nil" do
          expect(service).not_to receive(:log_info)
          expect(service.execute).to be_nil
        end
      end
    end

    it "logs the predefined push rule" do
      expect(service).to receive(:log_info)

      service.execute
    end

    it "sets project.push_rule.is_sample to false" do
      service.execute

      expect(project.push_rule.is_sample).to be_falsey
    end

    it "updates project.project_setting with the new push rule" do
      service.execute

      expect(project.project_setting.push_rule).to be(project.push_rule)
    end

    describe "override_push_rule param" do
      before do
        # Regex's here are arbitrary, non-nil placeholders
        #
        global_push_rule.update!(
          commit_message_regex: ".+",
          commit_message_negative_regex: ".+",
          branch_name_regex: ".+"
        )
      end

      context "when false (default)" do
        it "doesn't override the attributes from the global push rule" do
          expect(service).not_to receive(:override_push_rule)

          service.execute(override_push_rule: false)

          expect(project.push_rule.commit_message_regex).to eq(".+")
          expect(project.push_rule.commit_message_negative_regex).to eq(".+")
          expect(project.push_rule.branch_name_regex).to eq(".+")
        end
      end

      context "when true" do
        it "sets the expected push_rule attributes to nil" do
          expect(service).to receive(:override_push_rule).and_call_original

          service.execute(override_push_rule: true)

          expect(project.push_rule.commit_message_regex).to be_nil
          expect(project.push_rule.commit_message_negative_regex).to be_nil
          expect(project.push_rule.branch_name_regex).to be_nil
        end
      end
    end
  end
end
