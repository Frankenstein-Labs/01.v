<script>
import {
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlCollapsibleListbox,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { BASE_ROLES_WITHOUT_OWNER } from '~/access_level/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import PermissionsSelector from './permissions_selector.vue';

export default {
  name: 'RoleForm',
  i18n: {
    descriptionHelpText: s__(
      'MemberRole|Example: "Developer with admin and read access to vulnerability"',
    ),
  },
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlSprintf,
    GlLink,
    GlCollapsibleListbox,
    PermissionsSelector,
    PageHeading,
    SettingsSection,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    role: {
      type: Object,
      required: false,
      default: null,
    },
    submitText: {
      type: String,
      required: true,
    },
    showBaseRole: {
      type: Boolean,
      required: false,
      default: false,
    },
    busy: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['cancel', 'submit'],
  data() {
    return {
      alert: null,
      name: this.role?.name || '',
      description: this.role?.description || '',
      baseAccessLevel: this.role?.baseAccessLevel?.stringValue || null,
      permissions: this.role?.enabledPermissions.nodes.map(({ value }) => value) || [],
      // If we're editing a role, mark the form as dirty so that validation is enabled immediately instead of after the
      // form is submitted for the first time.
      isDirty: Boolean(this.role),
    };
  },
  computed: {
    isNameValid() {
      return !this.isDirty || this.name.length > 0;
    },
    isDescriptionValid() {
      return !this.isDirty || this.description?.length > 0;
    },
    isBaseRoleValid() {
      return !this.showBaseRole || !this.isDirty || this.baseAccessLevel !== null;
    },
    isPermissionsValid() {
      return !this.isDirty || this.permissions.length > 0;
    },
    defaultRolesHelpPagePath() {
      return helpPagePath('user/permissions', { anchor: 'roles' });
    },
    roleDropdownText() {
      // Return the role name, or "Select a role" if we're creating a new role and a base role hasn't been
      // selected yet.
      return this.baseAccessLevel
        ? BASE_ROLES_WITHOUT_OWNER.find(({ value }) => value === this.baseAccessLevel).text
        : s__('MemberRole|Select a role');
    },
  },
  methods: {
    async saveRole() {
      this.isDirty = true;
      this.alert?.dismiss();

      if (
        !this.isNameValid ||
        !this.isDescriptionValid ||
        !this.isBaseRoleValid ||
        !this.isPermissionsValid
      ) {
        this.alert = createAlert({
          message: s__('MemberRole|You must fill out all required fields.'),
        });
      } else {
        const { name, description, baseAccessLevel, permissions } = this;
        this.$emit('submit', { name, description, baseAccessLevel, permissions });
      }
    },
  },
  BASE_ROLES_WITHOUT_OWNER,
};
</script>

<template>
  <gl-form @submit.prevent="saveRole">
    <page-heading :heading="title" />

    <settings-section>
      <gl-form-group
        :label="s__('MemberRole|Name')"
        label-for="role-name"
        :invalid-feedback="__('This field is required.')"
      >
        <gl-form-input
          id="role-name"
          v-model="name"
          :state="isNameValid"
          trim
          width="xl"
          maxlength="255"
        />
      </gl-form-group>

      <gl-form-group
        :label="s__('MemberRole|Description')"
        :invalid-feedback="__('This field is required.')"
        :description="$options.i18n.descriptionHelpText"
        label-for="description"
      >
        <gl-form-input
          id="description"
          v-model="description"
          trim
          :state="isDescriptionValid"
          width="xl"
          maxlength="255"
        />
      </gl-form-group>
    </settings-section>

    <settings-section :heading="__('Permissions')">
      <gl-form-group
        v-if="showBaseRole"
        :label="s__('MemberRole|Base role')"
        :invalid-feedback="__('This field is required.')"
        :state="isBaseRoleValid"
        label-for="base-role-select"
        label-class="!gl-pb-1"
        class="gl-mb-6"
        data-testid="base-role-form-group"
      >
        <template #label-description>
          <div class="gl-mb-3">
            <gl-sprintf
              :message="
                s__(
                  'MemberRole|Select a %{linkStart} default role%{linkEnd} to predefine a set of permissions.',
                )
              "
            >
              <template #link="{ content }">
                <gl-link :href="defaultRolesHelpPagePath" target="_blank">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </div>
        </template>
        <gl-collapsible-listbox
          v-model="baseAccessLevel"
          category="secondary"
          :variant="isBaseRoleValid ? 'default' : 'danger'"
          block
          class="gl-w-30"
          :items="$options.BASE_ROLES_WITHOUT_OWNER"
          :disabled="Boolean(role)"
          :toggle-text="roleDropdownText"
        />
      </gl-form-group>

      <permissions-selector
        v-model="permissions"
        :base-access-level="baseAccessLevel"
        :is-valid="isPermissionsValid"
      />
    </settings-section>

    <div class="settings-sticky-footer gl-flex gl-flex-wrap gl-gap-3">
      <gl-button
        type="submit"
        :loading="busy"
        data-testid="submit-button"
        variant="confirm"
        class="js-no-auto-disable"
      >
        {{ submitText }}
      </gl-button>
      <gl-button data-testid="cancel-button" :disabled="busy" @click="$emit('cancel')">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </gl-form>
</template>
