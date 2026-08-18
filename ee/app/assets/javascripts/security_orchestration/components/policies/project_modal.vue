<script>
import { GlAlert, GlButton, GlLink, GlModal, GlSprintf, GlToggle } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import linkSecurityPolicyProject from '../../graphql/mutations/link_security_policy_project.mutation.graphql';
import unlinkSecurityPolicyProject from '../../graphql/mutations/unlink_security_policy_project.mutation.graphql';
import SppSelector from './spp_selector.vue';

export default {
  name: 'ProjectModal',
  i18n: {
    modal: {
      header: s__('SecurityOrchestration|Select security policy project'),
      subheader: s__('SecurityOrchestration|Filter and search projects'),
      description: s__(
        `SecurityOrchestration|Security policy projects store your organization's security policies. They are identified when policies are created, or when a project is linked as a security policy project. %{linkStart}Learn more%{linkEnd}.`,
      ),
      showOption: s__('SecurityOrchestration|Show only linked security policy projects'),
      saveButtonText: __('Save'),
    },
    save: {
      okLink: s__('SecurityOrchestration|Security policy project was linked successfully'),
      okUnlink: s__('SecurityOrchestration|Security policy project will be unlinked soon'),
      errorLink: s__(
        'SecurityOrchestration|An error occurred assigning your security policy project',
      ),
      errorUnlink: s__(
        'SecurityOrchestration|An error occurred unassigning your security policy project',
      ),
    },
    unlinkButtonLabel: s__('SecurityOrchestration|Unlink project'),
    unlinkWarning: s__(
      'SecurityOrchestration|Unlinking a security policy project will stop enforcing all policies from the linked project on this namespace. The policy project and its policies will not be deleted. Save to confirm this action.',
    ),
    disabledWarning: s__('SecurityOrchestration|Only owners can update Security Policy Project'),
    description: s__(
      'SecurityOrchestration|Select a project to store your security policies in. %{linkStart}More information.%{linkEnd}',
    ),
    emptyPlaceholder: s__('SecurityOrchestration|Choose a project'),
  },
  components: {
    GlAlert,
    GlButton,
    GlLink,
    GlModal,
    GlSprintf,
    GlToggle,
    SppSelector,
  },
  inject: [
    'disableSecurityPolicyProject',
    'documentationPath',
    'namespacePath',
    'assignedPolicyProject',
  ],
  props: {
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close', 'project-updated', 'updating-project'],
  data() {
    const initialSelectedProject = this.assignedPolicyProject
      ? { ...this.assignedPolicyProject }
      : null;

    return {
      initialSelectedProject,
      selectedProject: initialSelectedProject,
      hasSelectedNewProject: false,
      shouldShowUnlinkWarning: false,
      savingChanges: false,
      searchOnlyPolicyProjects: false,
    };
  },
  computed: {
    selectedProjectId() {
      return this.selectedProject?.id || '';
    },
    isModalOkButtonDisabled() {
      if (this.shouldShowUnlinkWarning) {
        return false;
      }

      return this.disableSecurityPolicyProject || !this.hasSelectedNewProject;
    },
  },
  methods: {
    async linkProject() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: linkSecurityPolicyProject,
          variables: {
            input: {
              fullPath: this.namespacePath,
              securityPolicyProjectId: this.selectedProjectId,
            },
          },
        });

        if (data?.securityPolicyProjectAssign?.errors?.length) {
          throw new Error(data.securityPolicyProjectAssign.errors);
        }

        this.initialSelectedProject = this.selectedProject;

        this.$emit('project-updated', {
          text: this.$options.i18n.save.okLink,
          variant: 'success',
          hasPolicyProject: true,
        });
      } catch (e) {
        this.selectedProject = null;

        const text = e?.message || this.$options.i18n.save.errorLink;
        this.$emit('project-updated', {
          text,
          variant: 'danger',
          hasPolicyProject: false,
        });
      }
    },

    async unlinkProject() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: unlinkSecurityPolicyProject,
          variables: {
            input: {
              fullPath: this.namespacePath,
            },
          },
        });

        if (data?.securityPolicyProjectUnassign?.errors?.length) {
          throw new Error(data.securityPolicyProjectUnassign.errors);
        }

        this.shouldShowUnlinkWarning = false;
        this.initialSelectedProject = null;
        this.$emit('project-updated', {
          text: this.$options.i18n.save.okUnlink,
          variant: 'success',
          hasPolicyProject: false,
        });
      } catch (e) {
        this.selectedProject = { ...this.assignedPolicyProject };

        const text = e?.message || this.$options.i18n.save.errorUnlink;
        this.$emit('project-updated', {
          text,
          variant: 'danger',
          hasPolicyProject: true,
        });
      }
    },

    async saveChanges() {
      this.savingChanges = true;
      this.$emit('updating-project');

      if (this.shouldShowUnlinkWarning) {
        await this.unlinkProject();
      } else {
        await this.linkProject();
      }

      this.savingChanges = false;
    },
    setSelectedProject(data) {
      this.shouldShowUnlinkWarning = false;
      this.hasSelectedNewProject = true;
      this.selectedProject = data;
    },
    confirmUnlink() {
      this.shouldShowUnlinkWarning = true;
      this.selectedProject = null;
      this.hasSelectedNewProject = true;
    },
    restoreProject() {
      this.selectedProject = this.initialSelectedProject;
    },
    closeModal() {
      if (this.hasSelectedNewProject && !this.savingChanges) {
        this.restoreProject();
      }

      this.hasSelectedNewProject = false;
      this.shouldShowUnlinkWarning = false;
      this.$emit('close');
    },
  },
};
</script>

<template>
  <gl-modal
    v-bind="$attrs"
    ref="modal"
    cancel-variant="light"
    size="sm"
    modal-id="scan-new-policy"
    :scrollable="false"
    :ok-title="$options.i18n.modal.saveButtonText"
    :title="$options.i18n.modal.header"
    :ok-disabled="isModalOkButtonDisabled"
    :visible="visible"
    @ok="saveChanges"
    @change="closeModal"
  >
    <div>
      <gl-alert
        v-if="disableSecurityPolicyProject"
        class="gl-mb-4"
        variant="warning"
        :dismissible="false"
      >
        {{ $options.i18n.disabledWarning }}
      </gl-alert>
      <gl-alert
        v-if="shouldShowUnlinkWarning"
        class="gl-mb-4"
        variant="warning"
        :dismissible="false"
      >
        {{ $options.i18n.unlinkWarning }}
      </gl-alert>
      <div>
        <h5>{{ $options.i18n.modal.subheader }}</h5>
        <gl-sprintf :message="$options.i18n.modal.description">
          <template #link="{ content }">
            <gl-link :href="documentationPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
        <gl-toggle
          v-model="searchOnlyPolicyProjects"
          class="gl-flex-col gl-items-start gl-py-3 @md/panel:gl-flex-row @md/panel:gl-items-center"
          :label="$options.i18n.modal.showOption"
          label-position="left"
        />
      </div>
      <div class="gl-mb-3 gl-flex">
        <spp-selector
          class="gl-w-9/10"
          :disabled="disableSecurityPolicyProject"
          :only-linked="searchOnlyPolicyProjects"
          :selected-project="selectedProject"
          @project-clicked="setSelectedProject"
        />
        <gl-button
          v-if="selectedProjectId"
          icon="remove"
          class="gl-ml-3"
          data-testid="unlink-button"
          :aria-label="$options.i18n.unlinkButtonLabel"
          @click="confirmUnlink"
        />
      </div>
    </div>
  </gl-modal>
</template>
