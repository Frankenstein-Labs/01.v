<script>
import { GlAlert, GlButton, GlFormInput } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_CD_APPLICATION } from 'ee/graphql_shared/constants';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import { MAX_NAME_LENGTH, MAX_DESCRIPTION_LENGTH } from '../constants';
import cdVersionSetCreateMutation from '../graphql/cd_version_set_create.mutation.graphql';
import PanelFormField from './shared/panel_form_field.vue';
import ServicesSelector from './services_selector.vue';

export default {
  name: 'NewReleasePanel',
  components: {
    GlAlert,
    GlButton,
    GlFormInput,
    DynamicPanel,
    MountingPortal,
    PanelFormField,
    ServicesSelector,
  },
  props: {
    applicationId: {
      type: String,
      required: true,
    },
  },
  emits: ['close', 'created'],
  data() {
    return {
      name: '',
      description: '',
      selection: [],
      changedCount: 0,
      isCreating: false,
      errorMessage: '',
    };
  },
  computed: {
    applicationGid() {
      return convertToGraphQLId(TYPENAME_CD_APPLICATION, this.applicationId);
    },
    isNameValid() {
      return this.name.length <= MAX_NAME_LENGTH;
    },
    nameState() {
      return this.isNameValid ? null : false;
    },
    nameInvalidFeedback() {
      return sprintf(s__('ReleaseCreation|Version name cannot exceed %{maxLength} characters.'), {
        maxLength: MAX_NAME_LENGTH,
      });
    },
    canCreateRelease() {
      return (
        this.name.trim().length > 0 &&
        this.isNameValid &&
        this.isDescriptionValid &&
        this.selection.length > 0
      );
    },
    isDescriptionValid() {
      return this.description.length <= MAX_DESCRIPTION_LENGTH;
    },
    descriptionState() {
      return this.isDescriptionValid ? null : false;
    },
    descriptionInvalidFeedback() {
      return sprintf(s__('ReleaseCreation|Description cannot exceed %{maxLength} characters.'), {
        maxLength: MAX_DESCRIPTION_LENGTH,
      });
    },
    changedText() {
      return this.changedCount
        ? sprintf(s__('ReleaseCreation|%{count} changed'), { count: this.changedCount })
        : '';
    },
  },
  methods: {
    handleClose() {
      this.$emit('close');
    },
    async createRelease() {
      this.isCreating = true;
      this.errorMessage = '';

      try {
        const { data } = await this.$apollo.mutate({
          mutation: cdVersionSetCreateMutation,
          variables: {
            input: {
              applicationId: this.applicationGid,
              name: this.name,
              description: this.description || null,
              versionIds: this.selection.map((entry) => entry.versionId),
            },
          },
        });

        const errors = data?.cdVersionSetCreate?.errors ?? [];
        if (errors.length) {
          this.errorMessage = errors.join(' ');
          return;
        }

        this.$emit('created', data.cdVersionSetCreate.versionSet?.id ?? null);
      } catch (error) {
        this.errorMessage = s__(
          'ReleaseCreation|Failed to create the release. Refresh the page to try again.',
        );
        Sentry.captureException(error);
      } finally {
        this.isCreating = false;
      }
    },
  },
};
</script>

<template>
  <mounting-portal mount-to="#contextual-panel-portal" append>
    <dynamic-panel data-testid="release-panel" @close="handleClose">
      <template #header>
        <div class="gl-py-3">
          <p
            class="gl-mb-2 gl-text-xs gl-font-bold gl-uppercase gl-tracking-wider gl-text-status-brand"
          >
            {{ s__('ReleaseCreation|Release') }}
          </p>
          <h3 class="gl-my-0 gl-text-base">
            {{ s__('ReleaseCreation|Create release') }}
          </h3>
        </div>
      </template>

      <gl-alert v-if="errorMessage" variant="danger" class="gl-mt-4" @dismiss="errorMessage = ''">
        {{ errorMessage }}
      </gl-alert>

      <p class="gl-mt-4 gl-text-sm gl-text-subtle">
        {{ s__('ReleaseCreation|Pick a version for each service.') }}
      </p>

      <panel-form-field
        id="release-name"
        data-testid="name-field"
        :label="s__('ReleaseCreation|Version')"
        :state="nameState"
        :invalid-feedback="nameInvalidFeedback"
      >
        <gl-form-input
          id="release-name"
          v-model="name"
          :state="nameState"
          :placeholder="s__('ReleaseCreation|e.g. v1.2.3')"
        />
      </panel-form-field>

      <panel-form-field
        id="release-description"
        data-testid="description-field"
        :label="s__('ReleaseCreation|Description')"
        :state="descriptionState"
        :invalid-feedback="descriptionInvalidFeedback"
        :help-text="
          s__(
            'ReleaseCreation|Optional. The release identity is the set of service versions below.',
          )
        "
      >
        <gl-form-input
          id="release-description"
          v-model="description"
          :state="descriptionState"
          :placeholder="s__('ReleaseCreation|e.g. May production release')"
        />
      </panel-form-field>

      <panel-form-field
        data-testid="services-field"
        :label="s__('ReleaseCreation|Services and versions')"
        :additional-text="changedText"
      >
        <services-selector
          :application-id="applicationGid"
          @change="selection = $event"
          @changed-count="changedCount = $event"
        />
      </panel-form-field>

      <template #footer>
        <div class="gl-flex gl-justify-end gl-gap-3">
          <gl-button data-testid="cancel-button" @click="handleClose">
            {{ __('Cancel') }}
          </gl-button>
          <gl-button
            variant="confirm"
            :disabled="!canCreateRelease"
            :loading="isCreating"
            data-testid="create-button"
            @click="createRelease"
          >
            {{ s__('ReleaseCreation|Create release') }}
          </gl-button>
        </div>
      </template>
    </dynamic-panel>
  </mounting-portal>
</template>
