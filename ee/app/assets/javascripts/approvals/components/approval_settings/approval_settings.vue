<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormGroup,
  GlLoadingIcon,
  GlLink,
  GlFormRadioGroup,
  GlToastMixin,
} from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapGetters, mapState } from 'vuex';
import { helpPagePath } from '~/helpers/help_page_helper';
import { sprintf } from '~/locale';
import {
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { APPROVAL_SETTINGS_I18N, TYPE_GROUP } from '../../constants';
import PolicyOverrideWarningIcon from '../security_orchestration/policy_override_warning_icon.vue';
import ApprovalSettingsCheckbox from './approval_settings_checkbox.vue';
import ApprovalSettingsRadio from './approval_settings_radio.vue';

export default {
  name: 'ApprovalSettings',
  components: {
    ApprovalSettingsCheckbox,
    ApprovalSettingsRadio,
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlLoadingIcon,
    GlLink,
    GlFormRadioGroup,
    PolicyOverrideWarningIcon,
  },
  mixins: [GlToastMixin],
  props: {
    approvalSettingsPath: {
      type: String,
      required: true,
    },
    settingsLabels: {
      type: Object,
      required: true,
    },
    canPreventMrApprovalRuleEdit: {
      type: Boolean,
      required: false,
      default: true,
    },
    canPreventAuthorApproval: {
      type: Boolean,
      required: false,
      default: true,
    },
    canPreventCommittersApproval: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    ...mapState({
      isLoading: (state) => state.approvalSettings.isLoading,
      settings: (state) => state.approvalSettings.settings,
      errorMessage: (state) => state.approvalSettings.errorMessage,
      preventAuthorApproval: (state) => state.approvalSettings.settings.preventAuthorApproval,
      preventCommittersApproval: (state) =>
        state.approvalSettings.settings.preventCommittersApproval,
      preventMrApprovalRuleEdit: (state) =>
        state.approvalSettings.settings.preventMrApprovalRuleEdit,
      removeApprovalsOnPush: (state) => state.approvalSettings.settings.removeApprovalsOnPush,
      selectiveCodeOwnerRemovals: (state) =>
        state.approvalSettings.settings.selectiveCodeOwnerRemovals,
      requireUserPassword: (state) => state.approvalSettings.settings.requireUserPassword,
      groupName: (state) => state.settings.groupName,
    }),
    ...mapGetters(['settingChanged']),
    hasSettings() {
      return !isEmpty(this.settings);
    },
    isLoaded() {
      return this.hasSettings || this.errorMessage;
    },
    showSelectiveCodeOwnerRemovals() {
      // eslint-disable-next-line @gitlab/no-hardcoded-urls -- False positive, substring check, not constructing a URL
      return this.approvalSettingsPath.includes('/projects/');
    },
    whenCommitIsAddedRadioGroupValue() {
      if (this.removeApprovalsOnPush.value) {
        return this.$options.whenCommitIsAddedRadios.removeApprovalsOnPush;
      }
      if (this.selectiveCodeOwnerRemovals.value) {
        return this.$options.whenCommitIsAddedRadios.selectiveCodeOwnerRemovals;
      }

      return this.$options.whenCommitIsAddedRadios.keepApprovals;
    },
  },
  created() {
    this.fetchSettings(this.approvalSettingsPath);
  },
  methods: {
    ...mapActions([
      'fetchSettings',
      'updateSettings',
      'dismissErrorMessage',
      'setPreventAuthorApproval',
      'setPreventCommittersApproval',
      'setPreventMrApprovalRuleEdit',
      'setRemoveApprovalsOnPush',
      'setSelectiveCodeOwnerRemovals',
      'setRequireUserPassword',
    ]),
    handleWhenCommitIsAddedRadioGroupInput(value) {
      switch (value) {
        case this.$options.whenCommitIsAddedRadios.keepApprovals:
          this.setSelectiveCodeOwnerRemovals(false);
          this.setRemoveApprovalsOnPush(false);

          break;
        case this.$options.whenCommitIsAddedRadios.removeApprovalsOnPush:
          this.setSelectiveCodeOwnerRemovals(false);
          this.setRemoveApprovalsOnPush(true);

          break;

        case this.$options.whenCommitIsAddedRadios.selectiveCodeOwnerRemovals:
          this.setRemoveApprovalsOnPush(false);
          this.setSelectiveCodeOwnerRemovals(true);
          break;

        default:
          break;
      }
    },
    async onSubmit() {
      await this.updateSettings(this.approvalSettingsPath);
      this.$toast.show(APPROVAL_SETTINGS_I18N.savingSuccessMessage);
    },
    lockedText({ locked, inheritedFrom, enforcedByPolicy }) {
      if (!locked) {
        return null;
      }
      if (enforcedByPolicy) {
        return APPROVAL_SETTINGS_I18N.enforcedByPolicy;
      }
      if (inheritedFrom === TYPE_GROUP) {
        const { groupName } = this;
        return sprintf(APPROVAL_SETTINGS_I18N.lockedByGroupOwner, { groupName });
      }
      return APPROVAL_SETTINGS_I18N.lockedByAdmin;
    },
  },
  i18n: APPROVAL_SETTINGS_I18N,
  links: {
    approvalSettingsDocsPath: helpPagePath('user/project/merge_requests/approvals/settings'),
  },
  whenCommitIsAddedRadios: {
    keepApprovals: 'keep-approvals',
    removeApprovalsOnPush: 'remove-approvals-on-push',
    selectiveCodeOwnerRemovals: 'selective-code-owner-removals',
  },
  approvalSettings: [
    PREVENT_APPROVAL_BY_AUTHOR,
    PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
    REQUIRE_PASSWORD_TO_APPROVE,
  ],
  commitAddedSettings: [REMOVE_APPROVALS_WITH_NEW_COMMIT],
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="!isLoaded" size="md" />
    <gl-alert
      v-if="errorMessage"
      variant="danger"
      :dismissible="hasSettings"
      :class="{ 'gl-mb-6': hasSettings }"
      data-testid="error-alert"
      @dismiss="dismissErrorMessage"
    >
      {{ errorMessage }}
    </gl-alert>
    <gl-form v-if="hasSettings" @submit.prevent="onSubmit">
      <label class="label-bold"> {{ $options.i18n.approvalSettingsHeader }} </label>
      <p>
        {{ $options.i18n.approvalSettingsDescription }}
        <gl-link :href="$options.links.approvalSettingsDocsPath" target="_blank">
          {{ $options.i18n.learnMore }}
        </gl-link>
        <policy-override-warning-icon
          class="gl-inline-block"
          data-testid="approval-settings-warning-icon"
          :settings="$options.approvalSettings"
        />
      </p>
      <gl-form-group>
        <approval-settings-checkbox
          :checked="preventAuthorApproval.value"
          :label="settingsLabels.authorApprovalLabel"
          :locked="!canPreventAuthorApproval || preventAuthorApproval.locked"
          :locked-text="lockedText(preventAuthorApproval)"
          data-testid="prevent-author-approval"
          @input="setPreventAuthorApproval"
        />
        <approval-settings-checkbox
          :checked="preventCommittersApproval.value"
          :label="settingsLabels.preventCommittersApprovalLabel"
          :locked="!canPreventCommittersApproval || preventCommittersApproval.locked"
          :locked-text="lockedText(preventCommittersApproval)"
          data-testid="prevent-committers-approval"
          @input="setPreventCommittersApproval"
        />
        <approval-settings-checkbox
          :checked="preventMrApprovalRuleEdit.value"
          :label="settingsLabels.preventMrApprovalRuleEditLabel"
          :locked="!canPreventMrApprovalRuleEdit || preventMrApprovalRuleEdit.locked"
          :locked-text="lockedText(preventMrApprovalRuleEdit)"
          data-testid="prevent-mr-approval-rule-edit"
          @input="setPreventMrApprovalRuleEdit"
        />
        <approval-settings-checkbox
          :checked="requireUserPassword.value"
          :label="settingsLabels.requireUserPasswordLabel"
          :locked="requireUserPassword.locked"
          :locked-text="lockedText(requireUserPassword)"
          data-testid="require-user-password"
          @input="setRequireUserPassword"
        />
        <div class="gl-mb-3 gl-mt-5">
          {{ settingsLabels.whenCommitAddedLabel }}
          <policy-override-warning-icon
            class="gl-inline-block"
            data-testid="commit-settings-warning-icon"
            icon-id="policy-override-warning-icon-commit"
            :settings="$options.commitAddedSettings"
          />
        </div>
        <gl-form-radio-group
          :checked="whenCommitIsAddedRadioGroupValue"
          data-testid="when-commit-is-added-radios"
          @input="handleWhenCommitIsAddedRadioGroupInput"
        >
          <approval-settings-radio
            name="approval-removal-setting"
            :value="$options.whenCommitIsAddedRadios.keepApprovals"
            :label="settingsLabels.keepApprovalsLabel"
            :locked="removeApprovalsOnPush.locked"
            :locked-text="lockedText(removeApprovalsOnPush)"
            data-testid="keep-approvals-on-push"
          />
          <approval-settings-radio
            name="approval-removal-setting"
            :value="$options.whenCommitIsAddedRadios.removeApprovalsOnPush"
            :label="settingsLabels.removeApprovalsOnPushLabel"
            :locked="removeApprovalsOnPush.locked"
            :locked-text="lockedText(removeApprovalsOnPush)"
            data-testid="remove-approvals-on-push"
          />
          <approval-settings-radio
            v-if="showSelectiveCodeOwnerRemovals"
            name="approval-removal-setting"
            :value="$options.whenCommitIsAddedRadios.selectiveCodeOwnerRemovals"
            :label="settingsLabels.selectiveCodeOwnerRemovalsLabel"
            :locked="removeApprovalsOnPush.locked"
            :locked-text="lockedText(selectiveCodeOwnerRemovals)"
            data-testid="selective-code-owner-removals"
          />
        </gl-form-radio-group>
      </gl-form-group>
      <gl-button
        type="submit"
        variant="confirm"
        category="primary"
        :disabled="!settingChanged"
        :loading="isLoading"
      >
        {{ $options.i18n.saveChanges }}
      </gl-button>
    </gl-form>
  </div>
</template>
