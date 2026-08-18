<script>
import {
  GlAvatar,
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlTooltipDirective as GlTooltip,
  GlToggle,
  GlSprintf,
  GlTableLite,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions, mapGetters } from 'vuex';
import { s__, __ } from '~/locale';
import AccessDropdown from '~/projects/settings/components/access_dropdown.vue';
import GroupsAccessDropdown from 'ee/groups/settings/components/access_dropdown.vue';
import ShowMore from '~/vue_shared/components/show_more.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import {
  ACCESS_LEVELS,
  DEPLOYER_RULE_KEY,
  APPROVER_RULE_KEY,
  INHERITED_GROUPS,
  APPROVER_FIELDS,
  DEPLOYER_FIELDS,
} from './constants';
import EditProtectedEnvironmentRulesCard from './edit_protected_environment_rules_card.vue';
import AddRuleModal from './add_rule_modal.vue';
import AddApprovers from './add_approvers.vue';
import ProtectedEnvironments from './protected_environments.vue';

export default {
  components: {
    GlAvatar,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlToggle,
    GlTableLite,
    AccessDropdown,
    GroupsAccessDropdown,
    ProtectedEnvironments,
    EditProtectedEnvironmentRulesCard,
    AddRuleModal,
    AddApprovers,
    ShowMore,
    GlSprintf,
    HelpPageLink,
    HelpIcon,
  },
  directives: {
    GlTooltip,
  },
  inject: { accessLevelsData: { default: [] }, entityType: { default: 'projects' } },
  data() {
    return { isAddingRule: false, addingEnvironment: null, addingRule: '' };
  },
  computed: {
    ...mapState(['entityId', 'loading', 'protectedEnvironments', 'editingRules']),
    ...mapGetters(['getUsersForRule']),
    isAddingDeploymentRule() {
      return this.addingRule === DEPLOYER_RULE_KEY;
    },
    addRuleModalTitle() {
      return this.isAddingDeploymentRule
        ? this.$options.i18n.addDeploymentRuleModalTitle
        : this.$options.i18n.addApprovalRuleModalTitle;
    },
    isProjectType() {
      return this.entityType === 'projects';
    },
    approvalRules() {
      if (!this.addingEnvironment) return [];
      return this.addingEnvironment[APPROVER_RULE_KEY];
    },
  },
  mounted() {
    this.fetchProtectedEnvironments();
  },
  methods: {
    ...mapActions([
      'fetchProtectedEnvironments',
      'deleteRule',
      'setRule',
      'saveRule',
      'editRule',
      'updateRule',
      'unprotectEnvironment',
      'updateApproverInheritance',
      'updateRequiredApprovals',
    ]),
    canDeleteDeployerRules(env) {
      return env[DEPLOYER_RULE_KEY].length > 1;
    },
    addRule({ environment, ruleKey }) {
      this.addingEnvironment = environment;
      this.addingRule = ruleKey;
      this.isAddingRule = true;
    },
    isUserRule({ user_id: userId }) {
      return userId != null;
    },
    isGroupRule({ group_id: groupId }) {
      return groupId != null;
    },
    isUsingGroupInheritance({ group_inheritance_type: type }) {
      return type === INHERITED_GROUPS;
    },
    isEditingRules({ id }) {
      return Boolean(this.editingRules[id]);
    },
    getApprovalInheritanceToggleId(rule) {
      return this.isEditingRules(rule) ? `approval-inheritance-${rule.id}` : null;
    },
    getApprovalInheritanceToggleValue(rule) {
      return this.isUsingGroupInheritance(
        this.isEditingRules(rule) ? this.editingRules[rule.id] : rule,
      );
    },
    onApprovalInheritanceToggleChange(rule, value) {
      if (this.isEditingRules(rule)) {
        this.updateApproverInheritance({ rule: this.editingRules[rule.id], value });
      }
    },
    onApprovalsInputChange(rule, value) {
      if (this.isEditingRules(rule) && value) {
        this.updateRequiredApprovals({ rule: this.editingRules[rule.id], value });
      }
    },
  },
  i18n: {
    addDeployerText: s__('ProtectedEnvironments|Add deployment rules'),
    addApproverText: s__('ProtectedEnvironments|Add approval rules'),
    deployerDeleteButtonTitle: s__('ProtectedEnvironments|Delete deployer rule'),
    approverDeleteButtonTitle: s__('ProtectedEnvironments|Delete approver rule'),
    addDeploymentRuleModalTitle: s__('ProtectedEnvironments|Create deployment rule'),
    addApprovalRuleModalTitle: s__('ProtectedEnvironments|Create approval rule'),
    addModalText: __('Set a group, access level or users who are required to deploy.'),
    addDeployerLabel: s__('ProtectedEnvironments|Allowed to deploy'),
    approvalCount: s__('ProtectedEnvironments|Required approval count'),
    editApproverButton: s__('ProtectedEnvironments|Edit'),
    saveApproverButton: s__('ProtectedEnvironments|Save'),
    accessDropdownLabel: s__('ProtectedEnvironments|Select users'),
    inheritanceLabel: s__('ProtectedEnvironments|Enable group inheritance'),
    inheritanceTooltip: s__(
      'ProtectedEnvironments|If a group is invited to the current project, its parent and members inherit the permissions of the invited group.',
    ),
    approvalRulesEmptyStateMessage: s__(
      'ProtectedEnvironments|This environment has no approval rules set up. %{linkStart}Learn more about deployment approvals.%{linkEnd}',
    ),
  },
  ACCESS_LEVELS,
  DEPLOYER_RULE_KEY,
  APPROVER_RULE_KEY,
  AVATAR_LIMIT: 5,
  APPROVER_FIELDS,
  DEPLOYER_FIELDS,
};
</script>
<template>
  <div data-testid="protected-environments-list">
    <add-rule-modal
      v-model="isAddingRule"
      :title="addRuleModalTitle"
      @save-rule="saveRule({ environment: addingEnvironment, ruleKey: addingRule })"
    >
      <template v-if="isAddingDeploymentRule" #add-rule-form>
        <p>{{ $options.i18n.addModalText }}</p>
        <gl-form-group
          :label="$options.i18n.addDeployerLabel"
          label-for="update-deployer-dropdown"
          data-testid="create-deployer-dropdown"
        >
          <access-dropdown
            v-if="isProjectType"
            id="update-deployer-dropdown"
            class="gl-w-3/10"
            :label="$options.i18n.accessDropdownLabel"
            :access-levels-data="accessLevelsData"
            groups-with-project-access
            :access-level="$options.ACCESS_LEVELS.DEPLOY"
            @hidden="setRule({ environment: addingEnvironment, newRules: $event })"
          />
          <groups-access-dropdown
            v-else
            id="update-deployer-dropdown"
            class="gl-w-3/10"
            :label="$options.i18n.accessDropdownLabel"
            :access-levels-data="accessLevelsData"
            show-users
            inherited
            @hidden="setRule({ environment: addingEnvironment, newRules: $event })"
          />
        </gl-form-group>
      </template>
      <template v-else #add-rule-form>
        <add-approvers
          :project-id="entityId"
          :approval-rules="approvalRules"
          @change="setRule({ environment: addingEnvironment, newRules: $event })"
        />
      </template>
    </add-rule-modal>

    <protected-environments :environments="protectedEnvironments" @unprotect="unprotectEnvironment">
      <template #default="{ environment }">
        <edit-protected-environment-rules-card
          :loading="loading"
          :add-button-text="$options.i18n.addDeployerText"
          :environment="environment"
          :rule-key="$options.DEPLOYER_RULE_KEY"
          :data-testid="`protected-environment-${environment.name}-deployers`"
          class="gl-border-t"
          @add-rule="addRule"
        >
          <template #table>
            <gl-table-lite
              :fields="$options.DEPLOYER_FIELDS"
              :items="environment[$options.DEPLOYER_RULE_KEY]"
              stacked="md"
            >
              <template #cell(deployers)="{ item: rule }">
                <span data-testid="rule-description">
                  {{ rule.access_level_description }}
                </span>
              </template>

              <template #cell(users)="{ item: rule }">
                <show-more
                  #default="{ item }"
                  :limit="$options.AVATAR_LIMIT"
                  :items="getUsersForRule(rule, $options.DEPLOYER_RULE_KEY)"
                >
                  <gl-avatar
                    :key="item.id"
                    v-gl-tooltip
                    :src="item.avatar_url"
                    :title="item.name"
                    :size="24"
                    class="gl-mr-2"
                  />
                </show-more>
              </template>

              <template #cell(actions)="{ item: rule }">
                <div class="gl-flex gl-justify-end">
                  <gl-button
                    v-if="canDeleteDeployerRules(environment)"
                    v-gl-tooltip
                    category="secondary"
                    variant="danger"
                    icon="remove"
                    :loading="loading"
                    :title="$options.i18n.deployerDeleteButtonTitle"
                    :aria-label="$options.i18n.deployerDeleteButtonTitle"
                    class="gl-ml-auto"
                    @click="deleteRule({ environment, rule, ruleKey: $options.DEPLOYER_RULE_KEY })"
                  />
                </div>
              </template>
            </gl-table-lite>
          </template>
        </edit-protected-environment-rules-card>
        <edit-protected-environment-rules-card
          :loading="loading"
          :add-button-text="$options.i18n.addApproverText"
          :environment="environment"
          :rule-key="$options.APPROVER_RULE_KEY"
          :data-testid="`protected-environment-${environment.name}-approvers`"
          class="gl-border-t"
          @add-rule="addRule"
        >
          <template #table>
            <gl-table-lite
              :fields="$options.APPROVER_FIELDS"
              :items="environment[$options.APPROVER_RULE_KEY]"
              stacked="md"
              show-empty
            >
              <template #cell(approvers)="{ item: rule }">
                <span data-testid="rule-description">
                  {{ rule.access_level_description }}
                </span>
              </template>

              <template #cell(users)="{ item: rule }">
                <show-more
                  #default="{ item }"
                  :limit="$options.AVATAR_LIMIT"
                  :items="getUsersForRule(rule, $options.APPROVER_RULE_KEY)"
                >
                  <gl-avatar
                    :key="item.id"
                    v-gl-tooltip
                    :src="item.avatar_url"
                    :title="item.name"
                    :size="24"
                    class="gl-mr-2"
                  />
                </show-more>
              </template>

              <template #cell(approvals)="{ item: rule }">
                <template v-if="isEditingRules(rule)">
                  <gl-form-group
                    :label-for="`approval-count-${rule.id}`"
                    :label="$options.i18n.approvalCount"
                    label-sr-only
                    class="gl-mb-0"
                  >
                    <gl-form-input
                      :id="`approval-count-${rule.id}`"
                      :name="`approval-count-${rule.id}`"
                      :value="editingRules[rule.id].required_approvals"
                      class="gl-text-center"
                      @input="onApprovalsInputChange(rule, $event)"
                    />
                  </gl-form-group>
                </template>

                <template v-else>
                  <span class="gl-text-center">{{ rule.required_approvals }}</span>
                </template>
              </template>

              <template #head(inheritance)="{ label }">
                <span>{{ label }}</span>
                <help-icon
                  v-gl-tooltip
                  :title="$options.i18n.inheritanceTooltip"
                  :aria-label="$options.i18n.inheritanceTooltip"
                  class="gl-ml-2"
                />
              </template>
              <template #cell(inheritance)="{ item: rule }">
                <gl-toggle
                  v-if="isGroupRule(rule)"
                  :id="getApprovalInheritanceToggleId(rule)"
                  :label="$options.i18n.inheritanceLabel"
                  :name="`approval-inheritance-${rule.id}`"
                  :data-testid="`approval-inheritance-toggle-${rule.id}`"
                  :value="getApprovalInheritanceToggleValue(rule)"
                  label-position="hidden"
                  :disabled="!isEditingRules(rule)"
                  @change="onApprovalInheritanceToggleChange(rule, $event)"
                />
              </template>

              <template #cell(actions)="{ item: rule }">
                <div class="gl-flex gl-justify-end">
                  <gl-button
                    v-if="isEditingRules(rule)"
                    class="gl-ml-auto gl-mr-4"
                    @click="updateRule({ rule, environment, ruleKey: $options.APPROVER_RULE_KEY })"
                  >
                    {{ $options.i18n.saveApproverButton }}
                  </gl-button>

                  <gl-button
                    v-else-if="!isUserRule(rule)"
                    class="gl-ml-auto gl-mr-4"
                    :data-testid="`edit-approver-button-${rule.id}`"
                    @click="editRule(rule)"
                  >
                    {{ $options.i18n.editApproverButton }}
                  </gl-button>

                  <gl-button
                    v-gl-tooltip
                    category="secondary"
                    variant="danger"
                    icon="remove"
                    :class="{ 'gl-ml-auto': isUserRule(rule) }"
                    :loading="loading"
                    :title="$options.i18n.approverDeleteButtonTitle"
                    :aria-label="$options.i18n.approverDeleteButtonTitle"
                    @click="deleteRule({ environment, rule, ruleKey: $options.APPROVER_RULE_KEY })"
                  />
                </div>
              </template>
            </gl-table-lite>
          </template>

          <template #empty-state>
            <gl-sprintf :message="$options.i18n.approvalRulesEmptyStateMessage">
              <template #link="{ content }">
                <help-page-link href="ci/environments/deployment_approvals">{{
                  content
                }}</help-page-link>
              </template>
            </gl-sprintf>
          </template>
        </edit-protected-environment-rules-card>
      </template>
    </protected-environments>
  </div>
</template>
