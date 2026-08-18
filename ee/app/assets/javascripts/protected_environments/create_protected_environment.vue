<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormGroup,
  GlCollapse,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { debounce, memoize } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Api from 'ee/api';
import axios from '~/lib/utils/axios_utils';
import { __, s__ } from '~/locale';
import AccessDropdown from '~/projects/settings/components/access_dropdown.vue';
import GroupsAccessDropdown from 'ee/groups/settings/components/access_dropdown.vue';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import AddApprovers from './add_approvers.vue';
import { ACCESS_LEVELS } from './constants';

export default {
  ACCESS_LEVELS,
  components: {
    GlAlert,
    GlButton,
    GlCollapse,
    GlForm,
    GlFormGroup,
    GlCollapsibleListbox,
    AccessDropdown,
    GroupsAccessDropdown,
    AddApprovers,
  },
  inject: {
    accessLevelsData: { default: [] },
    entityId: { default: '' },
    entityType: { default: 'projects' },
    searchUnprotectedEnvironmentsUrl: { default: '' },
    tiers: { default: [] },
  },
  emits: ['cancel', 'success'],
  data() {
    return {
      deployers: [],
      approvers: [],
      disabled: false,
      environment: '',
      environments: [],
      environmentsLoading: false,
      errorMessage: '',
      loading: false,
      environmentTier: '',
    };
  },
  computed: {
    isFormInvalid() {
      return !this.deployers.length || !this.hasSelectedEnvironment;
    },
    environmentText() {
      return this.environment || this.$options.i18n.environmentText;
    },
    hasSelectedEnvironment() {
      return Boolean(this.environment) || Boolean(this.environmentTier);
    },
    isProjectType() {
      return this.entityType === 'projects';
    },
    environmentTierText() {
      return this.environmentTier || this.$options.i18n.environmentTierText;
    },
    environmentTiers() {
      return this.tiers.map((tier) => ({ text: tier, value: tier }));
    },
    deployerHelpText() {
      return this.$options.i18n.deployerHelp[this.entityType];
    },
    addText() {
      return this.$options.i18n.addText[this.entityType];
    },
  },
  mounted() {
    if (!this.isProjectType) return;
    this.fetchEnvironments();
  },
  unmounted() {
    // cancel debounce if the component is unmounted to avoid unnecessary fetches
    this.fetchEnvironments.cancel();
  },
  created() {
    this.fetch = memoize(async function getProtectedEnvironments(query = '') {
      this.environmentsLoading = true;
      this.errorMessage = '';
      return axios
        .get(this.searchUnprotectedEnvironmentsUrl, { params: { query } })
        .catch((error) => {
          Sentry.captureException(error);
          this.environments = [];
          this.errorMessage = __('An error occurred while fetching environments.');
        })
        .finally(() => {
          this.environmentsLoading = false;
        });
    });

    this.fetchEnvironments = debounce(function debouncedFetchEnvironments(query = '') {
      this.fetch(query)
        .then(({ data }) => {
          const environments = [].concat(data);
          this.environments = environments.map((environment) => ({
            value: environment,
            text: environment,
          }));
        })
        .catch(() => {
          this.environments = [];
        });
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    onSearch(query) {
      this.fetchEnvironments(query);
    },
    updateDeployers(permissions) {
      this.deployers = permissions;
    },
    updateApprovers(permissions) {
      this.approvers = permissions;
    },
    submitForm() {
      this.errorMessage = '';
      this.loading = true;

      const protectedEnvironment = {
        name: this.environment || this.environmentTier,
        deploy_access_levels: this.deployers,
        approval_rules: this.approvers,
      };
      const entityType = this.isProjectType ? 'projects' : 'groups';
      Api.createProtectedEnvironment(this.entityId, entityType, protectedEnvironment)
        .then(() => {
          this.$emit('success', protectedEnvironment);
          this.deployers = [];
          this.approvers = [];
          this.environment = '';
        })
        .catch((error) => {
          this.errorMessage = s__('ProtectedEnvironment|Failed to protect the environment.');

          if (error.response.data?.message) {
            this.errorMessage = `${this.errorMessage} ${error.response.data.message}`;
          }

          Sentry.captureException(error);
        })
        .finally(() => {
          this.loading = false;
        });
    },
  },
  i18n: {
    header: s__('ProtectedEnvironment|Protect an environment'),
    addText: {
      projects: s__('ProtectedEnvironment|Add new protected environment'),
      groups: s__('ProtectedEnvironment|Protect environment tier'),
    },
    environmentLabel: s__('ProtectedEnvironment|Select environment'),
    environmentText: s__('ProtectedEnvironment|Select an environment'),
    environmentTierLabel: s__('ProtectedEnvironment|Select environment tier'),
    environmentTierText: s__('ProtectedEnvironment|Select environment tier'),
    approvalLabel: s__('ProtectedEnvironment|Required approvals'),
    deployerLabel: s__('ProtectedEnvironments|Allowed to deploy'),
    deployerHelp: {
      projects: s__(
        'ProtectedEnvironments|Set which groups, access levels, or users can deploy to this environment. Groups and users must be members of the project.',
      ),
      groups: s__(
        'ProtectedEnvironments|Set which groups, access levels, or users can deploy in this environment tier.',
      ),
    },
    buttonText: s__('ProtectedEnvironment|Protect'),
    buttonTextCancel: __('Cancel'),
    accessDropdownLabel: s__('ProtectedEnvironments|Select users'),
  },
};
</script>
<template>
  <gl-form @submit.prevent="submitForm">
    <div data-testid="new-protected-environment">
      <gl-alert v-if="errorMessage" variant="danger" class="gl-mb-5" @dismiss="errorMessage = ''">
        {{ errorMessage }}
      </gl-alert>

      <h4 class="gl-mt-0">{{ addText }}</h4>

      <gl-form-group
        v-if="isProjectType"
        label-for="environment"
        data-testid="create-environment"
        :label="$options.i18n.environmentLabel"
      >
        <gl-collapsible-listbox
          id="create-environment"
          v-model="environment"
          :toggle-text="environmentText"
          :items="environments"
          :searching="environmentsLoading"
          searchable
          @search="onSearch"
        />
      </gl-form-group>

      <gl-form-group
        v-else
        label-for="environment-tier"
        data-testid="create-environment"
        :label="$options.i18n.environmentTierLabel"
      >
        <gl-collapsible-listbox
          id="create-environment"
          v-model="environmentTier"
          :toggle-text="environmentTierText"
          :items="environmentTiers"
        />
      </gl-form-group>

      <gl-collapse :visible="hasSelectedEnvironment">
        <gl-form-group
          data-testid="create-deployer-dropdown"
          label-for="create-deployer-dropdown"
          :label="$options.i18n.deployerLabel"
        >
          <template #label-description>
            {{ deployerHelpText }}
          </template>
          <access-dropdown
            v-if="isProjectType"
            id="create-deployer-dropdown"
            :label="$options.i18n.accessDropdownLabel"
            :access-levels-data="accessLevelsData"
            :access-level="$options.ACCESS_LEVELS.DEPLOY"
            :disabled="disabled"
            :items="deployers"
            groups-with-project-access
            @select="updateDeployers"
          />
          <groups-access-dropdown
            v-else
            id="create-deployer-dropdown"
            :label="$options.i18n.accessDropdownLabel"
            :access-levels-data="accessLevelsData"
            :disabled="disabled"
            :items="deployers"
            show-users
            inherited
            @select="updateDeployers"
          />
        </gl-form-group>
        <add-approvers
          :project-id="entityId"
          @change="updateApprovers"
          @error="errorMessage = $event"
        />
      </gl-collapse>

      <div class="gl-mt-5 gl-flex">
        <gl-button
          type="submit"
          category="primary"
          variant="confirm"
          :loading="loading"
          :disabled="isFormInvalid"
          class="js-no-auto-disable gl-mr-3"
        >
          {{ $options.i18n.buttonText }}
        </gl-button>
        <gl-button
          type="button"
          category="secondary"
          variant="default"
          data-testid="cancel-button"
          @click="$emit('cancel')"
        >
          {{ $options.i18n.buttonTextCancel }}
        </gl-button>
      </div>
    </div>
  </gl-form>
</template>
