<script>
import { GlButton, GlForm, GlFormInput, GlFormTextarea, GlFormSelect } from '@gitlab/ui';
import { s__ } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import {
  AI_CATALOG_MCP_SERVERS_ROUTE,
  AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';
import { getCancelRoute, getSubmitButtonText } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import FormGroup from './form_group.vue';
import FormSection from './form_section.vue';

export default {
  name: 'AiCatalogMcpServerForm',
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    FormGroup,
    FormSection,
    GlButton,
    GlForm,
    GlFormInput,
    GlFormTextarea,
    GlFormSelect,
  },
  props: {
    mode: {
      type: String,
      required: false,
      default: 'create',
      validator: (value) => ['create', 'edit'].includes(value),
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    errors: {
      type: Array,
      required: true,
    },
    initialValues: {
      type: Object,
      required: false,
      default() {
        return {
          name: '',
          description: '',
          url: '',
          homepageUrl: '',
          transport: 'HTTP',
          authType: 'OAUTH',
        };
      },
    },
  },
  emits: ['submit', 'cancel', 'dismiss-errors'],
  data() {
    return {
      formData: {
        name: this.initialValues.name || '',
        description: this.initialValues.description || '',
        url: this.initialValues.url || '',
        homepageUrl: this.initialValues.homepageUrl || '',
        transport: 'HTTP',
        authType: this.initialValues.authType || 'OAUTH',
        oauthClientId: this.initialValues.oauthClientId || '',
        oauthClientSecret: this.initialValues.oauthClientSecret || '',
      },
    };
  },
  computed: {
    transportOptions() {
      return [{ value: 'HTTP', text: s__('AICatalog|HTTP') }];
    },
    authTypeOptions() {
      return [
        { value: 'OAUTH', text: s__('AICatalog|OAuth') },
        { value: 'NO_AUTH', text: s__('AICatalog|No authentication') },
      ];
    },
    isOAuth() {
      return this.formData.authType === 'OAUTH';
    },
    cancelRoute() {
      return getCancelRoute(
        this.$route.params,
        AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
        AI_CATALOG_MCP_SERVERS_ROUTE,
      );
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    submitButtonText() {
      return getSubmitButtonText(this.isEditMode, s__('AICatalog|Create MCP server'));
    },
  },
  methods: {
    validate() {
      return Object.keys(this.$refs)
        .filter((key) => key.startsWith('field'))
        .reduce((allValid, key) => {
          const field = this.$refs[key];
          if (!field) return allValid;
          const isFieldValid = this.$refs[key].validate();
          return allValid && isFieldValid;
        }, true);
    },
    handleSubmit() {
      if (!this.validate()) {
        return;
      }

      this.$emit('submit', {
        name: this.formData.name.trim(),
        description: this.formData.description.trim(),
        url: this.formData.url.trim(),
        homepageUrl: this.formData.homepageUrl.trim(),
        transport: this.formData.transport,
        authType: this.formData.authType,
        oauthClientId: this.formData.oauthClientId.trim(),
        oauthClientSecret: this.formData.oauthClientSecret.trim(),
      });
    },
  },
  fields: {
    name: {
      id: 'mcp-server-name',
      label: s__('AICatalog|Name'),
      validations: {
        requiredLabel: s__('AICatalog|Name is required.'),
      },
      inputAttrs: {
        placeholder: s__('AICatalog|Atlassian, Google Cloud'),
      },
    },
    description: {
      id: 'mcp-server-description',
      label: s__('AICatalog|Description'),
      inputAttrs: {
        placeholder: s__(
          'AICatalog|This MCP server has tools for finding, creating, and updating objects in...',
        ),
      },
    },
    url: {
      id: 'mcp-server-url',
      label: s__('AICatalog|Server URL'),
      validations: {
        requiredLabel: s__('AICatalog|Server URL is required.'),
      },
    },
    homepageUrl: {
      id: 'mcp-server-homepage-url',
      label: s__('AICatalog|Homepage URL'),
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|Link to the homepage or documentation for this MCP server',
        ),
        optional: true,
      },
    },
    transport: {
      id: 'mcp-server-transport',
      label: s__('AICatalog|Transport protocol'),
      validations: {
        requiredLabel: s__('AICatalog|Transport protocol is required.'),
      },
    },
    authType: {
      id: 'mcp-server-auth-type',
      label: s__('AICatalog|Authentication method'),
      validations: {
        requiredLabel: s__('AICatalog|Authentication method is required.'),
      },
    },
    oauthClientId: {
      id: 'mcp-server-oauth-client-id',
      label: s__('AICatalog|OAuth Client ID'),
      groupAttrs: {
        labelDescription: s__('AICatalog|Leave blank to use dynamic client registration'),
        optional: true,
      },
    },
    oauthClientSecret: {
      id: 'mcp-server-oauth-client-secret',
      label: s__('AICatalog|OAuth Client Secret'),
      groupAttrs: {
        labelDescription: s__('AICatalog|Leave blank to use dynamic client registration'),
        optional: true,
      },
    },
  },
};
</script>

<template>
  <div>
    <errors-alert v-if="errors.length" :errors="errors" @dismiss="$emit('dismiss-errors')" />
    <gl-form class="gl-flex gl-flex-col gl-gap-5" @submit.prevent="handleSubmit">
      <form-section :title="s__('AICatalog|Basic information')">
        <form-group
          #default="{ state, blur }"
          ref="fieldName"
          :field="$options.fields.name"
          :field-value="formData.name"
        >
          <gl-form-input
            :id="$options.fields.name.id"
            v-model="formData.name"
            :placeholder="$options.fields.name.inputAttrs.placeholder"
            :state="state"
            :disabled="isLoading"
            @blur="blur"
          />
        </form-group>

        <form-group :field="$options.fields.description" :field-value="formData.description">
          <gl-form-textarea
            :id="$options.fields.description.id"
            v-model="formData.description"
            :disabled="isLoading"
            :placeholder="$options.fields.description.inputAttrs.placeholder"
          />
        </form-group>

        <form-group :field="$options.fields.homepageUrl" :field-value="formData.homepageUrl">
          <gl-form-input
            :id="$options.fields.homepageUrl.id"
            v-model="formData.homepageUrl"
            type="url"
            :disabled="isLoading"
          />
        </form-group>
      </form-section>

      <form-section :title="s__('AICatalog|Configuration')">
        <form-group
          #default="{ state, blur }"
          ref="fieldUrl"
          :field="$options.fields.url"
          :field-value="formData.url"
        >
          <gl-form-input
            :id="$options.fields.url.id"
            v-model="formData.url"
            type="url"
            :state="state"
            :disabled="isLoading"
            @blur="blur"
          />
        </form-group>

        <form-group :field="$options.fields.transport" :field-value="formData.transport">
          <gl-form-select
            :id="$options.fields.transport.id"
            v-model="formData.transport"
            :options="transportOptions"
            disabled
          />
        </form-group>

        <form-group :field="$options.fields.authType" :field-value="formData.authType">
          <gl-form-select
            :id="$options.fields.authType.id"
            v-model="formData.authType"
            :options="authTypeOptions"
            :disabled="isLoading"
          />
        </form-group>

        <form-group
          v-if="isOAuth"
          :field="$options.fields.oauthClientId"
          :field-value="formData.oauthClientId"
        >
          <gl-form-input
            :id="$options.fields.oauthClientId.id"
            v-model="formData.oauthClientId"
            type="text"
            :disabled="isLoading"
          />
        </form-group>

        <form-group
          v-if="isOAuth"
          :field="$options.fields.oauthClientSecret"
          :field-value="formData.oauthClientSecret"
        >
          <gl-form-input
            :id="$options.fields.oauthClientSecret.id"
            v-model="formData.oauthClientSecret"
            type="password"
            :disabled="isLoading"
          />
        </form-group>
      </form-section>

      <ai-catalog-form-buttons :cancel-route="cancelRoute">
        <gl-button
          type="submit"
          variant="confirm"
          :loading="isLoading"
          class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
        >
          {{ submitButtonText }}
        </gl-button>
      </ai-catalog-form-buttons>
    </gl-form>
  </div>
</template>
