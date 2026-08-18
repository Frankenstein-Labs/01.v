<script>
import { GlAlert, GlButton, GlFormInput } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import { ARTIFACT_SOURCE_TYPE } from '../constants';
import cdApplicationCreateMutation from '../graphql/cd_application_create.mutation.graphql';
import PanelFormField from './shared/panel_form_field.vue';
import PanelFormGroup from './shared/panel_form_group.vue';

export default {
  name: 'NewApplicationPanel',
  components: {
    GlAlert,
    DynamicPanel,
    GlButton,
    GlFormInput,
    MountingPortal,
    PanelFormField,
    PanelFormGroup,
  },
  props: {
    open: {
      type: Boolean,
      required: true,
    },
    organizationId: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['close', 'create'],
  data() {
    return {
      errors: undefined,
      isSubmitting: false,
      serviceIndex: null,
      services: [],
      showServiceForm: false,
      // application form data
      name: '',
      description: '',
      // service form data
      serviceName: '',
      serviceDescription: '',
      // artifact form data
      artifactName: '',
      artifactUrl: '',
      // validation errors
      showValidationErrors: false,
      showServiceValidationErrors: false,
      showEmptyServicesError: false,
    };
  },
  computed: {
    serviceFormHeading() {
      return this.serviceIndex == null
        ? s__('ContinuousDeployment|Add service')
        : s__('ContinuousDeployment|Edit service');
    },
    serviceFormButton() {
      return this.serviceIndex == null
        ? s__('ContinuousDeployment|Add service')
        : s__('ContinuousDeployment|Save service');
    },
    isNameValid() {
      return this.name.trim().length > 0;
    },
    nameState() {
      return this.showValidationErrors && !this.isNameValid ? false : null;
    },
    isServiceNameValid() {
      return this.serviceName.trim().length > 0;
    },
    serviceNameState() {
      return this.showServiceValidationErrors && !this.isServiceNameValid ? false : null;
    },
    isArtifactNameValid() {
      return this.artifactName.trim().length > 0;
    },
    artifactNameState() {
      return this.showServiceValidationErrors && !this.isArtifactNameValid ? false : null;
    },
    isArtifactUrlValid() {
      return this.artifactUrl.trim().length > 0;
    },
    artifactUrlState() {
      return this.showServiceValidationErrors && !this.isArtifactUrlValid ? false : null;
    },
  },
  methods: {
    cancelService() {
      if (this.serviceIndex != null) {
        // If user cancels a new form, we let the user resume with their data.
        // But if user cancels an editing form, we should clear the data
        // because it's confusing to continue showing it when re-displaying the form.
        this.clearServiceInputData();
      }
      this.showServiceForm = false;
      this.serviceIndex = null;
    },
    addService() {
      this.showServiceValidationErrors = true;

      if (!this.isServiceNameValid || !this.isArtifactNameValid || !this.isArtifactUrlValid) {
        return;
      }

      if (this.serviceIndex == null) {
        // Add new service
        this.services.push({
          name: this.serviceName,
          description: this.serviceDescription,
          artifactSources: [this.buildArtifactSource()],
        });
      } else {
        // Edit existing service
        this.services[this.serviceIndex].name = this.serviceName;
        this.services[this.serviceIndex].description = this.serviceDescription;
        this.services[this.serviceIndex].artifactSources = [this.buildArtifactSource()];
      }
      this.clearServiceInputData();
      this.showServiceForm = false;
      this.serviceIndex = null;
    },
    buildArtifactSource() {
      // sourceConfig is required for rollouts to start; ARTIFACT_SOURCE_TYPE is the only
      // driver type supported today, so it's set here rather than exposed as a field.
      return {
        name: this.artifactName,
        sourceRef: this.artifactUrl,
        sourceConfig: { name: this.artifactName, type: ARTIFACT_SOURCE_TYPE },
      };
    },
    editService(index) {
      this.serviceIndex = index;
      this.serviceName = this.services[index].name;
      this.serviceDescription = this.services[index].description;
      this.artifactName = this.services[index].artifactSources[0].name;
      this.artifactUrl = this.services[index].artifactSources[0].sourceRef;
      this.startEditingServiceForm();
    },
    removeService(index) {
      this.services.splice(index, 1);
    },
    async startEditingServiceForm() {
      this.showServiceForm = true;
      await this.$nextTick();
      this.$refs.serviceName.$el.focus();
    },
    closePanel() {
      this.$emit('close');
    },
    clearServiceInputData() {
      this.serviceName = '';
      this.serviceDescription = '';
      this.artifactName = '';
      this.artifactUrl = '';
      this.showServiceValidationErrors = false;
      this.showEmptyServicesError = false;
    },
    clearForm() {
      this.name = '';
      this.description = '';
      this.clearServiceInputData();
      this.serviceIndex = null;
      this.services = [];
      this.errors = undefined;
      this.showValidationErrors = false;
    },
    async submitForm() {
      this.showValidationErrors = true;

      if (!this.services.length) {
        this.showEmptyServicesError = true;
        return;
      }

      if (!this.isNameValid) {
        return;
      }

      try {
        this.isSubmitting = true;

        const { data } = await this.$apollo.mutate({
          mutation: cdApplicationCreateMutation,
          variables: {
            input: {
              name: this.name,
              description: this.description,
              organizationId: this.organizationId,
              services: this.services,
            },
          },
        });

        if (data.cdApplicationCreate.errors.length) {
          this.errors = data.cdApplicationCreate.errors;
          return;
        }

        this.$emit('create');
        this.clearForm();
        this.closePanel();
      } catch (error) {
        Sentry.captureException(error);
        this.errors = [__('An error occurred. Please try again.')];
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <mounting-portal v-if="open" mount-to="#contextual-panel-portal" append>
    <dynamic-panel @close="closePanel">
      <template #header>
        <div class="gl-py-3">
          <p
            class="gl-mb-2 gl-text-xs gl-font-bold gl-uppercase gl-tracking-wider gl-text-status-brand"
          >
            {{ s__('ContinuousDeployment|Add application') }}
          </p>
          <h3 class="gl-my-0 gl-text-base">
            {{ s__('ContinuousDeployment|Register application') }}
          </h3>
        </div>
      </template>

      <p class="gl-my-5 gl-text-subtle">
        {{
          s__(
            'ContinuousDeployment|Declare the topology of your application — services, environments, integrations — and Deploy will orchestrate rollouts for it.',
          )
        }}
      </p>

      <gl-alert v-if="errors" class="gl-my-4" variant="danger" @dismiss="errors = undefined">
        <ul class="gl-m-0 gl-pl-4">
          <li v-for="error in errors" :key="error">
            {{ error }}
          </li>
        </ul>
      </gl-alert>

      <panel-form-group
        :description="s__('ContinuousDeployment|A short name and description.')"
        step="1"
        :title="s__('ContinuousDeployment|Application identity')"
      >
        <div class="gl-flex gl-gap-3">
          <panel-form-field
            class="gl-grow"
            :label="s__('ContinuousDeployment|Application name')"
            :state="nameState"
            :invalid-feedback="s__('ContinuousDeployment|Application name is required.')"
          >
            <gl-form-input
              id="application-name"
              v-model="name"
              autofocus
              :state="nameState"
              :placeholder="s__('ContinuousDeployment|e.g. acme-platform')"
            />
          </panel-form-field>
          <panel-form-field class="gl-grow" :label="s__('ContinuousDeployment|Description')">
            <gl-form-input
              id="application-description"
              v-model="description"
              :placeholder="s__('ContinuousDeployment|Brief description')"
            />
          </panel-form-field>
        </div>
      </panel-form-group>

      <panel-form-group
        class="gl-mt-4"
        :description="
          s__(
            'ContinuousDeployment|The deployable units. Each service has its own deployment strategy.',
          )
        "
        step="2"
        :title="s__('ContinuousDeployment|Services')"
      >
        <template #actions>
          <gl-button
            class="gl-shrink-0"
            category="secondary"
            :disabled="showServiceForm"
            variant="confirm"
            data-testid="add-service-header"
            @click="startEditingServiceForm"
          >
            {{ s__('ContinuousDeployment|+ Add service') }}
          </gl-button>
        </template>
        <template v-if="services.length">
          <ul class="gl-m-0 gl-list-none gl-p-0" data-testid="services-list">
            <li
              v-for="(service, index) in services"
              :key="index"
              class="gl-border gl-mb-4 gl-flex gl-items-center gl-rounded-lg gl-px-4 gl-py-3"
            >
              <!-- eslint-disable tailwindcss/no-arbitrary-value -->
              <span
                class="gl-mr-4 gl-h-3 gl-w-3 gl-rounded-lg gl-bg-gray-200 gl-shadow-[0_0_0_3px_var(--gray-50)]"
              ></span>
              <!-- eslint-enable tailwindcss/no-arbitrary-value -->
              <div class="gl-mr-auto">
                <div class="gl-font-bold">{{ service.name }}</div>
                <div class="gl-font-monospace">
                  {{ service.artifactSources[0].name }}
                  &middot;
                  {{ service.artifactSources[0].sourceRef }}
                </div>
              </div>
              <gl-button
                category="tertiary"
                size="small"
                data-testid="edit-service"
                @click="editService(index)"
              >
                {{ s__('ContinuousDeployment|Edit') }}
              </gl-button>
              <gl-button
                category="tertiary"
                size="small"
                variant="danger"
                data-testid="remove-service"
                @click="removeService(index)"
              >
                {{ s__('ContinuousDeployment|Remove') }}
              </gl-button>
            </li>
          </ul>
        </template>
        <div
          v-else-if="!showServiceForm"
          class="gl-border gl-mb-4 gl-rounded-lg gl-border-dashed gl-bg-subtle gl-px-4 gl-py-3 gl-text-sm gl-text-subtle"
          data-testid="service-empty-state"
        >
          {{
            s__(
              'ContinuousDeployment|No services yet. Add at least one — a service is the deployable unit (Git repo with K8s manifests, or a container image).',
            )
          }}
        </div>
        <div
          v-if="showServiceForm"
          class="gl-border gl-rounded-lg gl-border-purple-100 gl-bg-purple-50 gl-px-4 gl-py-3"
          data-testid="service-form"
        >
          <span class="gl-text-sm gl-font-bold gl-uppercase gl-tracking-wide gl-text-purple-500">
            {{ serviceFormHeading }}
          </span>
          <div class="gl-mt-3 gl-flex gl-gap-3">
            <panel-form-field
              class="gl-grow"
              :label="s__('ContinuousDeployment|Service name')"
              :state="serviceNameState"
              :invalid-feedback="s__('ContinuousDeployment|Service name is required.')"
            >
              <gl-form-input
                id="service-name"
                ref="serviceName"
                v-model="serviceName"
                :state="serviceNameState"
                :placeholder="s__('ContinuousDeployment|e.g. api-gateway')"
              />
            </panel-form-field>
            <panel-form-field class="gl-grow" :label="s__('ContinuousDeployment|Description')">
              <gl-form-input
                id="service-description"
                v-model="serviceDescription"
                :placeholder="s__('ContinuousDeployment|Brief description')"
              />
            </panel-form-field>
          </div>
          <div class="gl-mt-3 gl-flex gl-gap-3">
            <panel-form-field
              class="gl-grow"
              :label="s__('ContinuousDeployment|Artifact name')"
              :state="artifactNameState"
              :invalid-feedback="s__('ContinuousDeployment|Artifact name is required.')"
            >
              <gl-form-input
                id="artifact-name"
                v-model="artifactName"
                :state="artifactNameState"
                :placeholder="s__('ContinuousDeployment|e.g. api-gateway')"
              />
            </panel-form-field>
            <panel-form-field
              class="gl-grow"
              :label="s__('ContinuousDeployment|Artifact URL')"
              :state="artifactUrlState"
              :invalid-feedback="s__('ContinuousDeployment|Artifact URL is required.')"
            >
              <gl-form-input
                id="artifact-url"
                v-model="artifactUrl"
                :state="artifactUrlState"
                :placeholder="
                  s__('ContinuousDeployment|e.g. registry.example.com/acme/api-gateway')
                "
              />
            </panel-form-field>
          </div>
          <div class="gl-flex gl-justify-end">
            <gl-button category="tertiary" data-testid="cancel-service" @click="cancelService">
              {{ s__('ContinuousDeployment|Cancel') }}
            </gl-button>
            <gl-button variant="confirm" data-testid="add-service" @click="addService">
              {{ serviceFormButton }}
            </gl-button>
          </div>
        </div>
        <button
          v-else
          class="gl-border gl-w-full gl-rounded-lg gl-border-dashed gl-border-neutral-800 gl-bg-transparent gl-py-3 gl-text-sm"
          data-testid="add-another-service"
          @click="startEditingServiceForm"
        >
          {{ s__('ContinuousDeployment|+ Add another service') }}
        </button>
        <div role="status">
          <div
            v-if="showEmptyServicesError"
            class="gl-mt-2 gl-text-danger"
            data-testid="empty-services-error"
          >
            {{ s__('ContinuousDeployment|Add at least one service.') }}
          </div>
        </div>
      </panel-form-group>

      <template #footer>
        <div class="gl-flex gl-justify-end gl-gap-3">
          <gl-button data-testid="cancel-button" @click="closePanel">
            {{ __('Cancel') }}
          </gl-button>
          <gl-button
            :loading="isSubmitting"
            variant="confirm"
            data-testid="register-button"
            @click="submitForm"
          >
            {{ s__('ContinuousDeployment|Register application') }}
          </gl-button>
        </div>
      </template>
    </dynamic-panel>
  </mounting-portal>
</template>
