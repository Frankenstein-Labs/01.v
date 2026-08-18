<script>
import {
  GlAvatarLabeled,
  GlCollapsibleListbox,
  GlFormCheckbox,
  GlDatepicker,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlModal,
  GlSprintf,
  GlToastMixin,
} from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { createAlert } from '~/alert';
import { formatGraphQLError } from 'ee/ci/secrets/utils';
import { getDateInFuture, toISODateFormat } from '~/lib/utils/datetime_utility';
import {
  ACCESS_LEVEL_NO_ACCESS_INTEGER,
  ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER,
  ACCESS_LEVEL_GUEST_INTEGER,
  ACCESS_LEVEL_PLANNER_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  ACCESS_LEVEL_REPORTER_STRING,
  ACCESS_LEVEL_DEVELOPER_STRING,
  ACCESS_LEVEL_MAINTAINER_STRING,
  BASE_ROLES,
} from '~/access_level/constants';
import { __, s__ } from '~/locale';
import { SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG } from '../context_config';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
  ALERT_CONTAINER_SELECTOR,
} from '../constants';

export default {
  name: 'SecretsManagerPermissionsModal',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
    GlFormCheckbox,
    GlDatepicker,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlModal,
    GlSprintf,
  },
  mixins: [GlToastMixin],
  i18n: {
    groupPathFormatError: s__(
      'SecretsManagerPermissions|Group names must start and end with letters or numbers, and can only contain letters, numbers, periods, hyphens and underscores. Separate subgroups with slashes.',
    ),
  },
  inject: ['groupPathRegex'],
  props: {
    permissionCategory: {
      type: String,
      required: false,
      default: null,
    },
    fullPath: {
      type: String,
      required: true,
    },
    context: {
      type: String,
      required: true,
    },
  },
  emits: ['hide', 'refetch'],
  data() {
    return {
      expiration: null,
      groupPath: '',
      isGroupPathValid: true,
      isListboxLoading: false,
      isSubmitting: false,
      listboxItems: [],
      principal: null,
      actions: {
        read: false,
        read_value: false,
        write: false,
        delete: false,
      },
      selectedListboxItem: '',
    };
  },
  computed: {
    contextConfig() {
      return SECRETS_MANAGER_PERMISSIONS_CONTEXT_CONFIG[this.context];
    },
    isCategoryUser() {
      return this.permissionCategory === PERMISSION_CATEGORY_USER;
    },
    isCategoryGroup() {
      return this.permissionCategory === PERMISSION_CATEGORY_GROUP;
    },
    isCategoryRole() {
      return this.permissionCategory === PERMISSION_CATEGORY_ROLE;
    },
    isSubmittable() {
      const hasPrincipal = this.isCategoryGroup
        ? this.groupPath.trim() && this.isGroupPathValid
        : this.principal !== null;
      return hasPrincipal && this.selectedActions.length > 0;
    },
    listboxTitle() {
      if (this.isCategoryUser) {
        return __('Username or name');
      }
      return __('Group');
    },
    listboxToggleText() {
      if (!this.principal) {
        return __('Select');
      }

      if (this.isCategoryUser) {
        return this.principal.name;
      }

      return this.principal.text;
    },
    minExpirationDate() {
      const today = new Date();
      return getDateInFuture(today, 1);
    },
    modalOptions() {
      return {
        actionPrimary: {
          text: __('Add'),
          attributes: {
            disabled: !this.isSubmittable,
            loading: this.isSubmitting,
            variant: 'confirm',
          },
        },
        actionSecondary: {
          text: __('Cancel'),
          attributes: {
            variant: 'default',
          },
        },
      };
    },
    modalTitle() {
      if (this.isCategoryUser) {
        return __('Add user');
      }

      if (this.isCategoryGroup) {
        return __('Add group');
      }

      return __('Add role');
    },
    rolesList() {
      const excludedRoles = [
        ACCESS_LEVEL_NO_ACCESS_INTEGER,
        ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER,
        ACCESS_LEVEL_GUEST_INTEGER,
        ACCESS_LEVEL_PLANNER_INTEGER,
        ACCESS_LEVEL_OWNER_INTEGER,
      ];

      return BASE_ROLES.filter((role) => !excludedRoles.includes(role.accessLevel));
    },
    selectedActions() {
      return Object.keys(this.actions)
        .filter((action) => this.actions[action])
        .map((action) => action.toUpperCase());
    },
  },
  methods: {
    async createPermission() {
      if (this.isCategoryGroup) {
        this.validateGroupPath();
        if (!this.isGroupPathValid) {
          return;
        }
      }

      this.isSubmitting = true;

      try {
        const principal = {
          type: this.permissionCategory,
        };

        if (this.isCategoryRole) {
          principal.id = this.principal.accessLevel;
        } else if (this.isCategoryGroup) {
          principal.groupPath = this.groupPath;
        } else {
          principal.id = getIdFromGraphQLId(this.principal.id);
        }

        const { data } = await this.$apollo.mutate({
          mutation: this.contextConfig.createPermission.mutation,
          variables: {
            fullPath: this.fullPath,
            principal,
            actions: this.selectedActions,
            expiredAt: this.expiration ? toISODateFormat(this.expiration) : null,
          },
        });

        const error = data?.secretsPermissionUpdate?.errors[0];
        if (error) {
          createAlert({
            message: error,
            containerSelector: ALERT_CONTAINER_SELECTOR,
          });
          return;
        }

        this.$emit('refetch');
        this.$toast.show(
          s__('SecretsManagerPermissions|Secrets manager permissions were successfully updated.'),
        );
      } catch (e) {
        createAlert({
          message: formatGraphQLError(
            e.message,
            s__(
              'SecretsManagerPermissions|Failed to create secrets manager permission. Please try again.',
            ),
          ),
          captureError: true,
          error: e,
          containerSelector: ALERT_CONTAINER_SELECTOR,
        });
      } finally {
        this.hideModal();
        this.isSubmitting = false;
      }
    },
    debouncedSearchListbox: debounce(function debouncedSearch(search) {
      this.searchListbox(search);
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    transformMemberToListboxItem(member) {
      const { user } = member;
      return {
        text: user.name,
        value: user.username,
        name: user.name,
        username: user.username,
        avatarUrl: user.avatarUrl,
        id: user.id,
      };
    },
    async searchListbox(search) {
      try {
        this.isListboxLoading = true;

        const { data } = await this.$apollo.query({
          query: this.contextConfig.searchMembers.query,
          variables: {
            fullPath: this.fullPath,
            search: search || '',
            accessLevels: [
              ACCESS_LEVEL_REPORTER_STRING,
              ACCESS_LEVEL_DEVELOPER_STRING,
              ACCESS_LEVEL_MAINTAINER_STRING,
            ],
            relations: this.contextConfig.searchMembers.relations,
          },
        });

        const members = this.contextConfig.searchMembers.lookup(data);
        this.listboxItems = members.nodes.map(this.transformMemberToListboxItem);
      } catch (e) {
        createAlert({
          message: __('An error occurred while fetching. Please try again.'),
          captureError: true,
          error: e,
          containerSelector: ALERT_CONTAINER_SELECTOR,
        });
      } finally {
        this.isListboxLoading = false;
      }
    },
    selectListboxItem(listboxItem) {
      this.selectedListboxItem = listboxItem;
      const sourceList = this.isCategoryRole ? this.rolesList : this.listboxItems;
      [this.principal] = sourceList.filter((item) => item.value === listboxItem);
    },
    validateGroupPath() {
      if (!this.groupPath) {
        this.isGroupPathValid = true;
        return;
      }

      this.isGroupPathValid = this.groupPathRegex.test(this.groupPath);
    },
    clearGroupPathError() {
      this.isGroupPathValid = true;
    },
    hideModal() {
      this.listboxItems = [];
      this.principal = null;
      this.expiration = null;
      this.groupPath = '';
      this.isGroupPathValid = true;
      this.selectedListboxItem = '';
      this.actions = {
        read: false,
        read_value: false,
        write: false,
        delete: false,
      };

      this.$emit('hide');
    },
  },
  datePlaceholder: 'YYYY-MM-DD',
};
</script>

<template>
  <gl-modal
    :visible="permissionCategory !== null"
    :title="modalTitle"
    :action-primary="modalOptions.actionPrimary"
    :action-secondary="modalOptions.actionSecondary"
    modal-id="secrets-manager-permissions-modal"
    @primary.prevent="createPermission"
    @secondary="hideModal"
    @canceled="hideModal"
    @hidden="hideModal"
  >
    <gl-form>
      <gl-form-group
        v-if="isCategoryUser"
        label-for="secret-permission-principal"
        :label="listboxTitle"
      >
        <gl-collapsible-listbox
          id="secret-permission-principal"
          :items="listboxItems"
          :selected="selectedListboxItem"
          :toggle-text="listboxToggleText"
          :search-placeholder="__('Search users...')"
          :searching="isListboxLoading"
          searchable
          block
          fluid-width
          is-check-centered
          @select="selectListboxItem"
          @search="debouncedSearchListbox"
          @shown="searchListbox"
        >
          <template #list-item="{ item }">
            <gl-avatar-labeled
              :label="item.name"
              :sub-label="item.username"
              :src="item.avatarUrl"
              :entity-name="item.name"
              :size="32"
            />
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
      <gl-form-group
        v-else-if="isCategoryGroup"
        label-for="secret-permission-group-path"
        data-testid="secret-permissions-group-path"
        :label="__('Group path')"
        :state="isGroupPathValid"
        :invalid-feedback="$options.i18n.groupPathFormatError"
      >
        <template #label-description>
          <gl-sprintf
            :message="
              s__(
                'SecretsManagerPermissions|The full path to the group to add. For example, %{example}.',
              )
            "
          >
            <template #example>
              <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
              <code>group-name</code> or <code>group-name/sub-group-name</code>
            </template>
          </gl-sprintf>
        </template>
        <gl-form-input
          id="secret-permission-group-path"
          v-model.trim="groupPath"
          :state="isGroupPathValid"
          @blur="validateGroupPath"
          @input="clearGroupPathError"
        />
      </gl-form-group>
      <gl-form-group
        v-else-if="isCategoryRole"
        label-for="secret-permission-principal"
        :label="__('Role')"
      >
        <gl-collapsible-listbox
          id="secret-permission-principal"
          :items="rolesList"
          :selected="selectedListboxItem"
          :toggle-text="listboxToggleText"
          block
          fluid-width
          is-check-centered
          @select="selectListboxItem"
        />
      </gl-form-group>
      <gl-form-group label-for="secret-permission-expiration" :label="__('Access expiration date')">
        <gl-datepicker
          id="secret-expiration"
          v-model="expiration"
          optional
          :placeholder="$options.datePlaceholder"
          :min-date="minExpirationDate"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Scopes')"
        :label-description="
          s__(
            'SecretsManagerPermissions|Select the access scopes to grant to this user for the secrets manager and related API endpoints.',
          )
        "
      >
        <gl-form-checkbox v-model="actions.read" class="-gl-mb-4">
          {{ __('Read metadata') }}
          <p class="gl-text-subtle">
            {{
              s__(
                'SecretsManagerPermissions|Can authenticate with the secrets manager and related API endpoints.',
              )
            }}
            {{
              s__(
                'SecretsManagerPermissions|Can read the metadata of secrets but not the secret values.',
              )
            }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="actions.read_value" class="-gl-mb-4" :disabled="!actions.read">
          {{ __('Read value') }}
          <p class="gl-text-subtle">
            {{ s__('SecretsManagerPermissions|Can fetch secret values with direct API requests.') }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="actions.write" class="-gl-mb-4" :disabled="!actions.read">
          {{ __('Write') }}
          <p class="gl-text-subtle">
            {{ s__('SecretsManagerPermissions|Can create and update secrets.') }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="actions.delete" class="-gl-mb-4" :disabled="!actions.read">
          {{ __('Delete') }}
          <p class="gl-text-subtle">
            {{ s__('SecretsManagerPermissions|Can permanently delete secrets.') }}
          </p>
        </gl-form-checkbox>
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
