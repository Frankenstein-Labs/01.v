<script>
import {
  GlAvatar,
  GlAvatarLink,
  GlLink,
  GlTableLite,
  GlTooltipDirective as GlTooltip,
  GlFormRadio,
  GlIcon,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { ACCESS_LEVEL, APPROVAL_STATUSES } from 'ee/deployments/constants';

export default {
  name: 'MultipleApprovalRulesTable',
  components: {
    GlAvatar,
    GlAvatarLink,
    GlLink,
    GlTableLite,
    GlFormRadio,
    GlIcon,
  },
  directives: {
    GlTooltip,
  },
  props: {
    rules: {
      required: true,
      type: Array,
    },
  },
  emits: ['select-rule'],
  fields: [
    { key: 'approvers', label: s__('DeploymentApprovals|Approvers') },
    { key: 'approvals', label: s__('DeploymentApprovals|Approvals') },
    { key: 'approvedBy', label: s__('DeploymentApprovals|Approved By') },
    { key: 'giveApproval', label: s__('DeploymentApprovals|Give approval') },
  ],
  data() {
    return { selected: null };
  },
  computed: {
    items() {
      return this.rules.map((rule) => ({
        approvers: this.getRuleData(rule),
        approvals: `${rule.approvedCount}/${rule.requiredApprovals}`,
        approvedBy: rule.approvals.filter((a) => a.status === APPROVAL_STATUSES.APPROVED),
        giveApproval: {
          canApprove: rule.canApprove,
          ruleName: this.getRuleName(rule),
          ruleValue: this.getRuleValue(rule),
        },
      }));
    },
    currentUserApproved() {
      return Boolean(this.rules.find((rule) => this.hasApproval(rule)));
    },
  },
  mounted() {
    if (!this.selected) {
      const firstRuleToApprove = this.rules.find((rule) => rule.canApprove);
      this.selected = this.getRuleName(firstRuleToApprove);

      this.onChange(this.selected);
    }
  },
  methods: {
    getRuleData(rule) {
      if (rule?.group) {
        return { name: rule.group.name, link: rule.group.webUrl, value: rule.group.name };
      }
      if (rule?.user) {
        return { name: rule.user.name, link: rule.user.webUrl, value: rule.user.name };
      }
      if (rule?.accessLevel?.stringValue) {
        return {
          name: ACCESS_LEVEL[rule.accessLevel.stringValue]?.display,
          value: ACCESS_LEVEL[rule.accessLevel.stringValue]?.value,
        };
      }

      return {};
    },
    getRuleName(rule) {
      return this.getRuleData(rule).name;
    },
    getRuleValue(rule) {
      return this.getRuleData(rule).value;
    },
    hasApproval(rule) {
      const result = Boolean(
        rule.approvals.find(({ user }) => user.username === gon.current_username),
      );
      if (result) {
        this.selected = this.getRuleValue(rule);
      }
      return result;
    },
    onChange($event) {
      this.$emit('select-rule', $event);
    },
  },
};
</script>
<template>
  <gl-table-lite stacked="lg" :fields="$options.fields" :items="items">
    <template #cell(approvers)="{ value }">
      <gl-link v-if="value.link" :href="value.link">{{ value.name }}</gl-link>
      <span v-else-if="value.name">{{ value.name }}</span>
      <span
        v-else
        v-gl-tooltip
        data-testid="private-group-rule"
        :title="
          s__(
            'DeploymentApprovals|You do not have access to this group, but members of this group can approve this rule.',
          )
        "
        >{{ s__('DeploymentApprovals|Private group') }} <gl-icon name="question"
      /></span>
    </template>
    <template #cell(approvedBy)="{ value }">
      <gl-avatar-link
        v-for="approval in value"
        :key="approval.user.id"
        v-gl-tooltip
        :href="approval.user.webUrl"
        :title="approval.user.name"
      >
        <gl-avatar :src="approval.user.avatarUrl" :size="24" aria-hidden="true" />
      </gl-avatar-link>
    </template>
    <template #cell(giveApproval)="{ value }">
      <gl-form-radio
        v-if="value.canApprove"
        v-model="selected"
        :value="value.ruleValue"
        :disabled="currentUserApproved"
        @input="onChange"
        >{{ s__('DeploymentApprovals|Approve') }}</gl-form-radio
      >
    </template>
  </gl-table-lite>
</template>
