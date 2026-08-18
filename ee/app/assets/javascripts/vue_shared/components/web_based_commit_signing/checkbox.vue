<script>
import { GlFormCheckbox, GlAlert, GlToastMixin } from '@gitlab/ui';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import GroupInheritancePopover from '~/vue_shared/components/settings/group_inheritance_popover.vue';
import getWebBasedCommitSigningQuery from 'ee/graphql_shared/queries/web_based_commit_signing.query.graphql';
import updateGroupWebBasedCommitSigningMutation from 'ee/graphql_shared/mutations/update_group_web_based_commit_signing.mutation.graphql';
import updateProjectWebBasedCommitSigningMutation from 'ee/graphql_shared/mutations/update_project_web_based_commit_signing.mutation.graphql';
import { __ } from '~/locale';

export default {
  name: 'WebBasedCommitSigningCheckbox',
  components: {
    GlFormCheckbox,
    GlAlert,
    GroupInheritancePopover,
  },
  mixins: [GlToastMixin],
  apollo: {
    webBasedCommitSigningEnabled: {
      query: getWebBasedCommitSigningQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          isGroupLevel: this.isGroupLevel,
        };
      },
      update(data) {
        if (this.isGroupLevel) {
          return data.group?.webBasedCommitSigningEnabled ?? false;
        }

        // For projects, store the group setting separately
        this.groupWebBasedCommitSigningEnabled =
          data.project?.group?.webBasedCommitSigningEnabled ?? false;

        // If group has it enabled, use that value (group overrides project)
        if (this.groupWebBasedCommitSigningEnabled) {
          return true;
        }

        return data.project?.webBasedCommitSigningEnabled ?? false;
      },
      skip() {
        return !this.fullPath;
      },
      error(error) {
        this.errorMessage = __('An error occurred while loading the settings.');
        captureException({ error, component: this.$options.name });
      },
    },
  },
  props: {
    hasGroupPermissions: {
      type: Boolean,
      required: true,
    },
    groupSettingsRepositoryPath: {
      type: String,
      required: true,
    },
    isGroupLevel: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      webBasedCommitSigningEnabled: false,
      groupWebBasedCommitSigningEnabled: false,
      isSaving: false,
      errorMessage: '',
    };
  },
  computed: {
    isInheritedFromGroup() {
      return !this.isGroupLevel && this.groupWebBasedCommitSigningEnabled;
    },
    isDisabled() {
      return (
        this.isSaving ||
        this.$apollo.queries.webBasedCommitSigningEnabled.loading ||
        this.isInheritedFromGroup
      );
    },
  },
  methods: {
    async handleChange(value) {
      const previousValue = this.webBasedCommitSigningEnabled;
      this.webBasedCommitSigningEnabled = value;
      this.errorMessage = '';
      this.isSaving = true;

      try {
        const mutation = this.isGroupLevel
          ? updateGroupWebBasedCommitSigningMutation
          : updateProjectWebBasedCommitSigningMutation;

        const response = await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              fullPath: this.fullPath,
              webBasedCommitSigningEnabled: value,
            },
          },
        });

        const errors = this.isGroupLevel
          ? response.data?.groupUpdate?.errors
          : response.data?.projectSettingsUpdate?.errors;

        if (errors?.length) {
          throw new Error(errors.join(', '));
        }

        const message = value
          ? __('Web-based commit signing enabled')
          : __('Web-based commit signing disabled');
        this.$toast.show(message);
      } catch (error) {
        captureException({ error, component: this.$options.name });
        this.errorMessage = error.message || __('An error occurred while updating the settings.');
        this.webBasedCommitSigningEnabled = previousValue;
      } finally {
        this.isSaving = false;
      }
    },
    dismissError() {
      this.errorMessage = '';
    },
  },
  i18n: {
    label: __('Sign web-based commits'),
    description: __('Automatically sign commits made through the web interface.'),
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="errorMessage" variant="danger" class="gl-mb-5" @dismiss="dismissError">
      {{ errorMessage }}
    </gl-alert>

    <gl-form-checkbox
      id="web-based-commit-signing-checkbox"
      data-testid="web-based-commit-signing-checkbox"
      :checked="webBasedCommitSigningEnabled"
      :disabled="isDisabled"
      @change="handleChange"
      ><span class="gl-inline-flex">
        {{ $options.i18n.label }}
        <group-inheritance-popover
          v-if="isInheritedFromGroup"
          class="gl-relative gl-bottom-2"
          :has-group-permissions="hasGroupPermissions"
          :group-settings-repository-path="groupSettingsRepositoryPath"
        />
      </span>
      <template #help>{{ $options.i18n.description }}</template>
    </gl-form-checkbox>
  </div>
</template>
