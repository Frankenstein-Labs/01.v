<script>
import {
  GlFormGroup,
  GlCollapse,
  GlAvatar,
  GlButton,
  GlLink,
  GlFormInput,
  GlSprintf,
  GlTooltipDirective as GlTooltip,
  GlToggle,
  GlTableLite,
} from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Api from 'ee/api';
import { getUser } from '~/rest_api';
import { s__ } from '~/locale';
import AccessDropdown from '~/projects/settings/components/access_dropdown.vue';
import GroupsAccessDropdown from 'ee/groups/settings/components/access_dropdown.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import {
  ACCESS_LEVELS,
  INHERITED_GROUPS,
  NON_INHERITED_GROUPS,
  APPROVER_FIELDS,
} from './constants';

const mapUserToApprover = (user) => ({
  name: user.name,
  entityName: user.name,
  webUrl: user.web_url,
  avatarUrl: user.avatar_url,
  id: user.id,
  avatarShape: 'circle',
  approvals: 1,
  inputDisabled: true,
  type: 'user',
});

const mapGroupToApprover = (group) => ({
  name: group.full_name,
  entityName: group.name,
  webUrl: group.web_url,
  avatarUrl: group.avatar_url,
  id: group.id,
  avatarShape: 'rect',
  approvals: 1,
  groupInheritanceType: false,
  type: 'group',
});

const ID_FOR_TYPE = {
  user: 'user_id',
  group: 'group_id',
  access: 'access_level',
};

const MIN_APPROVALS_COUNT = 1;

const MAX_APPROVALS_COUNT = 5;

const USERS = 'users';

export default {
  ACCESS_LEVELS,
  components: {
    GlFormGroup,
    GlCollapse,
    GlAvatar,
    GlButton,
    GlLink,
    GlFormInput,
    GlSprintf,
    GlToggle,
    AccessDropdown,
    GroupsAccessDropdown,
    GlTableLite,
    HelpIcon,
  },
  directives: { GlTooltip },
  inject: {
    accessLevelsData: { default: [] },
    apiLink: {},
    docsLink: {},
    entityType: { default: 'projects' },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    approvalRules: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['change', 'error'],
  data() {
    return {
      approvers: [],
      approverInfo: this.approvalRules,
      uniqueId: uniqueId('deployment-approvers-'),
    };
  },
  computed: {
    hasSelectedApprovers() {
      return Boolean(this.approvers.length);
    },
    approverHelpText() {
      return this.$options.i18n.approverHelp[this.entityType];
    },
    isProjectType() {
      return this.entityType === 'projects';
    },
  },
  watch: {
    async approvers() {
      try {
        this.$emit('error', '');
        this.approverInfo = await Promise.all(
          this.approvers.map((approver) => {
            if (approver.user_id) {
              return getUser(approver.user_id).then(({ data }) => mapUserToApprover(data));
            }

            if (approver.group_id) {
              return Api.group(approver.group_id).then(mapGroupToApprover);
            }

            return Promise.resolve({
              accessLevel: approver.access_level,
              id: approver.access_level,
              name: this.accessLevelsData.find(({ id }) => id === approver.access_level).text,
              approvals: 1,
              type: 'access',
            });
          }),
        );

        this.emitApprovalRules();
      } catch (e) {
        Sentry.captureException(e);
        this.$emit(
          'error',
          s__(
            'ProtectedEnvironments|An error occurred while fetching information on the selected approvers.',
          ),
        );
      }
    },
    approvalRules(rules, oldRules) {
      if (!rules.length && oldRules.length) {
        this.approvers = rules;
      }
    },
  },
  methods: {
    updateApprovers(permissions) {
      this.approvers = permissions;
    },
    updateApproverInfo(approver, approvals) {
      const i = this.approverInfo.indexOf(approver);
      this.approverInfo[i] = { ...approver, approvals };
      this.emitApprovalRules();
    },
    updateApproverInheritance(approver, groupInheritanceType) {
      const i = this.approverInfo.indexOf(approver);
      const copy = [...this.approverInfo];
      copy[i] = { ...approver, groupInheritanceType };
      this.approverInfo = copy;
      this.emitApprovalRules();
    },
    removeApprover({ type, id }) {
      const key = ID_FOR_TYPE[type];
      this.approvers = this.approvers.filter(({ [key]: i }) => id !== i);
    },
    isApprovalValid(approvals) {
      const count = parseFloat(approvals);
      return count >= MIN_APPROVALS_COUNT && count <= MAX_APPROVALS_COUNT;
    },
    approvalsId(index) {
      return `${this.uniqueId}-${index}`;
    },
    inheritanceId(index) {
      return `${this.uniqueId}-inheritance-${index}`;
    },
    emitApprovalRules() {
      const rules = this.approverInfo.map((info) => {
        switch (info.type) {
          case 'user':
            return { user_id: info.id, required_approvals: info.approvals };
          case 'group':
            return {
              group_id: info.id,
              required_approvals: info.approvals,
              group_inheritance_type: info.groupInheritanceType
                ? INHERITED_GROUPS
                : NON_INHERITED_GROUPS,
            };
          case 'access':
            return {
              access_level: info.accessLevel,
              required_approvals: info.approvals,
            };
          default:
            return {};
        }
      });
      this.$emit('change', rules);
    },
    doesApprovalExists(rule) {
      return this.approvalRules?.some((approver) => {
        return (
          (rule.type === 'user' && approver.user_id === rule.id) ||
          (rule.type === 'group' && approver.group_id === rule.id) ||
          approver.access_level === rule.accessLevel
        );
      });
    },
    isGroupRule(rule) {
      return rule.type === 'group';
    },
  },
  i18n: {
    approverLabel: s__('ProtectedEnvironment|Approvers'),
    approverHelp: {
      projects: s__(
        'ProtectedEnvironments|Set which groups, access levels, or users are required to approve. Groups and users must be members of the project.',
      ),
      groups: s__(
        'ProtectedEnvironments|Set which groups, access levels, or users are required to approve in this environment tier.',
      ),
    },
    approvalRulesLabel: s__('ProtectedEnvironments|Approval rules'),
    approvalsInvalid: s__('ProtectedEnvironments|Number of approvals must be between 1 and 5'),
    removeApprover: s__('ProtectedEnvironments|Remove approval rule'),
    unifiedRulesHelpText: s__(
      'ProtectedEnvironments|To configure unified approval rules, use the %{apiLinkStart}API%{apiLinkEnd}. Consider using %{docsLinkStart}multiple approval rules%{docsLinkEnd} instead.',
    ),
    accessDropdownLabel: s__('ProtectedEnvironments|Select users'),
    inheritanceLabel: s__('ProtectedEnvironments|Enable group inheritance'),
    inheritanceTooltip: s__(
      'ProtectedEnvironments|If a group is invited to the current project, its parent and members inherit the permissions of the invited group.',
    ),
    invalidFeedback: s__('ProtectedEnvironments|This rule already exists.'),
  },
  approverFields: APPROVER_FIELDS.filter(({ key }) => key !== USERS),
};
</script>
<template>
  <div>
    <gl-form-group
      data-testid="create-approver-dropdown"
      label-for="create-approver-dropdown"
      :label="$options.i18n.approverLabel"
    >
      <template #label-description>
        {{ approverHelpText }}
      </template>
      <access-dropdown
        v-if="isProjectType"
        id="create-approver-dropdown"
        :label="$options.i18n.accessDropdownLabel"
        :access-levels-data="accessLevelsData"
        :access-level="$options.ACCESS_LEVELS.DEPLOY"
        :disabled="disabled"
        :items="approvers"
        @select="updateApprovers"
      />
      <groups-access-dropdown
        v-else
        id="create-approver-dropdown"
        :label="$options.i18n.accessDropdownLabel"
        :access-levels-data="accessLevelsData"
        :disabled="disabled"
        :items="approvers"
        show-users
        inherited
        @select="updateApprovers"
      />
      <template #description>
        <gl-sprintf :message="$options.i18n.unifiedRulesHelpText">
          <template #apiLink="{ content }">
            <gl-link :href="apiLink">{{ content }}</gl-link>
          </template>
          <template #docsLink="{ content }">
            <gl-link :href="docsLink">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-form-group>
    <gl-collapse :visible="hasSelectedApprovers">
      <div class="gl-mb-5 gl-font-bold">{{ $options.i18n.approvalRulesLabel }}</div>
      <gl-table-lite
        :fields="$options.approverFields"
        :items="approverInfo"
        data-testid="approval-rules"
        stacked="md"
        class="-gl-mb-5 @md/panel:gl-mb-0"
      >
        <template #cell(approvers)="{ item: approver, index }">
          <gl-avatar
            v-if="approver.avatarShape"
            :key="`${index}-avatar`"
            :src="approver.avatarUrl"
            :size="24"
            :entity-id="approver.id"
            :entity-name="approver.entityName"
            :shape="approver.avatarShape"
          />
          <span v-else :key="`${index}-avatar`" class="gl-w-6"></span>
          <gl-link v-if="approver.webUrl" :key="`${index}-name`" :href="approver.webUrl">
            {{ approver.name }}
          </gl-link>
          <span v-else :key="`${index}-name`">{{ approver.name }}</span>
        </template>

        <template #cell(approvals)="{ item: approver, index }">
          <gl-form-group
            :key="`${index}-approvals`"
            :state="isApprovalValid(approver.approvals)"
            :label="$options.i18n.approverLabel"
            :label-for="approvalsId(index)"
            label-sr-only
            class="gl-mb-0"
          >
            <gl-form-input
              :id="approvalsId(index)"
              :value="approver.approvals"
              :disabled="approver.inputDisabled"
              :state="isApprovalValid(approver.approvals) && !doesApprovalExists(approver)"
              :name="`approval-count-${approver.name}`"
              type="number"
              @input="updateApproverInfo(approver, $event)"
            />
            <template #invalid-feedback>
              <span v-if="doesApprovalExists(approver)">
                {{ $options.i18n.invalidFeedback }}
              </span>
              <span v-else>
                {{ $options.i18n.approvalsInvalid }}
              </span>
            </template>
          </gl-form-group>
        </template>

        <template #head(inheritance)="data">
          <span>{{ data.label }}</span>
          <help-icon
            v-gl-tooltip
            :title="$options.i18n.inheritanceTooltip"
            :aria-label="$options.i18n.inheritanceTooltip"
          />
        </template>
        <template #cell(inheritance)="{ item: approver, index }">
          <gl-toggle
            v-if="isGroupRule(approver)"
            :id="inheritanceId(index)"
            :key="`${index}-inheritance`"
            :label="$options.i18n.inheritanceLabel"
            :name="`approval-inheritance-${approver.name}`"
            :value="approver.groupInheritanceType"
            label-position="hidden"
            @change="updateApproverInheritance(approver, $event)"
          />
          <span v-else :key="`${index}-inheritance`"></span>
        </template>

        <template #cell(actions)="{ item: approver, index }">
          <gl-button
            :key="`${index}-remove`"
            v-gl-tooltip
            :title="$options.i18n.removeApprover"
            :aria-label="$options.i18n.removeApprover"
            icon="remove"
            :data-testid="`remove-approver-${approver.name}`"
            @click="removeApprover(approver)"
          />
        </template>
      </gl-table-lite>
    </gl-collapse>
  </div>
</template>
