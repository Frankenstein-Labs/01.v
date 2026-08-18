<script>
import CEBranchRule from '~/projects/settings/repository/branch_rules/components/branch_rule.vue';
import DisabledByPolicyPopover from '~/projects/settings/branch_rules/components/disabled_by_policy_popover.vue';
import PolicyBadge from '~/projects/settings/repository/branch_rules/components/policy_badge.vue';
import { getAccessLevelsDeployKeysText } from '~/projects/settings/utils';
import { getAccessLevels, getAccessLevelsRolesAndEEText } from 'ee/projects/settings/utils';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'BranchRuleEE',
  components: {
    DisabledByPolicyPopover,
    PolicyBadge,
  },
  extends: CEBranchRule,
  inject: {
    securityPoliciesPath: { default: '' },
  },
  computed: {
    modificationBlockedByPolicy() {
      return Boolean(this.branchProtection?.modificationBlockedByPolicy);
    },
    warnModificationBlockedByPolicy() {
      return Boolean(this.branchProtection?.warnModificationBlockedByPolicy);
    },
    protectedFromPushBySecurityPolicy() {
      return Boolean(this.branchProtection?.protectedFromPushBySecurityPolicy);
    },
    warnProtectedFromPushBySecurityPolicy() {
      return Boolean(this.branchProtection?.warnProtectedFromPushBySecurityPolicy);
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    isEnforcedByAnyPolicy() {
      return this.protectedFromPushBySecurityPolicy || this.modificationBlockedByPolicy;
    },
    isPushAffectedByAnyPolicy() {
      return this.protectedFromPushBySecurityPolicy || this.warnProtectedFromPushBySecurityPolicy;
    },
    isModificationAffectedByAnyPolicy() {
      return this.modificationBlockedByPolicy || this.warnModificationBlockedByPolicy;
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    showPolicyBadge() {
      return this.isPushAffectedByAnyPolicy || this.isModificationAffectedByAnyPolicy;
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    getAccessLevels,
    hasPushAccessLevelsText(text) {
      return this.pushAccessLevelsText && text?.includes(this.pushAccessLevelsText);
    },
    hasMergeAccessLevelsText(text) {
      return this.mergeAccessLevelsText && text?.includes(this.mergeAccessLevelsText);
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    isAffectedByPolicy(text) {
      if (this.isPushAffectedByAnyPolicy && this.hasPushAccessLevelsText(text)) return true;
      if (
        this.isModificationAffectedByAnyPolicy &&
        (this.hasPushAccessLevelsText(text) || this.hasMergeAccessLevelsText(text))
      )
        return true;

      return false;
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    isEnforcedForRow(text) {
      if (this.protectedFromPushBySecurityPolicy && this.hasPushAccessLevelsText(text)) return true;
      if (
        this.modificationBlockedByPolicy &&
        (this.hasPushAccessLevelsText(text) || this.hasMergeAccessLevelsText(text))
      )
        return true;
      return false;
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    disabledText(text) {
      if (this.protectedFromPushBySecurityPolicy && this.hasPushAccessLevelsText(text)) return true;
      return Boolean(
        this.modificationBlockedByPolicy &&
        (this.hasPushAccessLevelsText(text) || this.hasMergeAccessLevelsText(text)),
      );
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    getAccessLevelsText(beginString = '', accessLevels) {
      const textParts = [
        ...getAccessLevelsRolesAndEEText(accessLevels),
        ...getAccessLevelsDeployKeysText(accessLevels),
      ];

      return textParts.length ? `${beginString}: ${textParts.join(', ')}` : '';
    },
  },
};
</script>
