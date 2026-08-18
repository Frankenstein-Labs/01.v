<script>
import {
  GlFormGroup,
  GlFormInputGroup,
  GlTableLite,
  GlFormCheckbox,
  GlInputGroupText,
  GlFormInput,
  GlButton,
  GlSprintf,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { s__ } from '~/locale';

import { mapItemHeadersToFormData } from '../../utils';
import { createBlankHeader } from '../../constants';

const thClasses = `!gl-p-0 !gl-border-0`;
const tdClasses = `!gl-p-3 !gl-pr-4 !gl-pl-0 !gl-border-0`;
const activeTdClasses = `gl-whitespace-nowrap gl-w-2 ${tdClasses}`;
const actionsTdClasses = `gl-w-2 !gl-py-3 !gl-px-0 !gl-border-0`;

export default {
  name: 'StreamDestinationEditorHttpFields',
  components: {
    GlFormGroup,
    GlFormInputGroup,
    ClipboardButton,
    GlTableLite,
    GlFormCheckbox,
    GlInputGroupText,
    GlFormInput,
    GlButton,
    GlSprintf,
  },
  directives: {
    GlTooltip,
  },
  inject: ['maxHeaders'],
  props: {
    value: {
      type: Object,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  data() {
    return {
      destinationUrl: this.value.config.url,
      headers: mapItemHeadersToFormData(this.value),
    };
  },
  computed: {
    hasNoHeaders() {
      return this.headers.length === 0;
    },
    hasReachedMaxHeaders() {
      return this.headers.length >= this.maxHeaders;
    },
  },
  watch: {
    headers: {
      handler(newHeaders) {
        const headers = newHeaders
          .filter((header) => header.name && header.name.trim())
          .reduce(
            (headersObject, currentHeader) => ({
              ...headersObject,
              [currentHeader.name]: {
                value: currentHeader.value,
                active: currentHeader.active,
              },
            }),
            {},
          );

        const hasHeaderValidationErrors = newHeaders.some(
          (header) => header.validationErrors.name !== '',
        );
        const hasEmptyHeaders = newHeaders.some((header) => !header.name || !header.value);

        this.$emit('input', {
          ...this.value,
          config: {
            ...this.value.config,
            headers,
          },
          shouldDisableSubmitButton: hasHeaderValidationErrors || hasEmptyHeaders,
        });
      },
      deep: true,
    },
    destinationUrl: {
      handler(newUrl) {
        this.$emit('input', {
          ...this.value,
          config: {
            ...this.value.config,
            url: newUrl,
          },
        });
      },
    },
  },
  methods: {
    headerNameExists(value) {
      return this.headers.some((header) => header.name === value);
    },
    addBlankHeader() {
      this.headers.push(createBlankHeader());
    },
    setHeaders(index, value) {
      const copy = [...this.headers];
      copy[index] = value;
      this.headers = copy;
    },
    handleHeaderNameInput(index, name) {
      const header = this.headers[index];

      const updatedHeader = {
        ...header,
        name,
        validationErrors: {
          ...header.validationErrors,
          name: '',
        },
      };

      if (name !== '' && this.headerNameExists(name)) {
        updatedHeader.validationErrors.name = s__(
          'AuditStreams|A header with this name already exists.',
        );
      }

      this.setHeaders(index, updatedHeader);
    },
    handleHeaderValueInput(index, value) {
      this.setHeaders(index, { ...this.headers[index], value });
    },
    handleHeaderActiveInput(index, active) {
      this.setHeaders(index, { ...this.headers[index], active });
    },
    removeHeader(index) {
      const [removedHeader] = this.headers.splice(index, 1);
      const firstSameHeader = this.headers.find((h) => h.name === removedHeader.name);
      if (firstSameHeader) {
        firstSameHeader.validationErrors.name = '';
      }
    },
  },
  headersTableFields: [
    {
      key: 'active',
      label: '',
      thClass: thClasses,
      tdClass: activeTdClasses,
    },
    {
      key: 'name',
      label: '',
      thClass: thClasses,
      tdClass: tdClasses,
    },
    {
      key: 'value',
      label: '',
      thClass: thClasses,
      tdClass: tdClasses,
    },
    {
      key: 'actions',
      label: '',
      thClass: thClasses,
      tdClass: actionsTdClasses,
    },
  ],
};
</script>
<template>
  <div>
    <gl-form-group
      :label="s__('AuditStreams|Destination URL')"
      data-testid="destination-url-form-group"
    >
      <gl-form-input
        v-model="destinationUrl"
        :placeholder="'https://api.gitlab.com'"
        :disabled="isEditing"
        data-testid="destination-url"
      />
    </gl-form-group>

    <gl-form-group
      v-if="isEditing"
      :label="s__('AuditStreams|Verification token')"
      class="gl-max-w-34"
      data-testid="verification-token-form-group"
    >
      <gl-form-input-group readonly :value="value.secretToken" data-testid="verification-token">
        <template #append>
          <clipboard-button :text="value.secretToken" :title="__('Copy to clipboard')" />
        </template>
      </gl-form-input-group>
    </gl-form-group>

    <div class="gl-mb-5">
      <label class="gl-mb-3 gl-block gl-text-lg">{{
        s__('AuditStreams|Custom HTTP headers (optional)')
      }}</label>
      <gl-table-lite :items="headers" :fields="$options.headersTableFields">
        <template #cell(active)="{ index, item: { active } }">
          <gl-form-checkbox
            class="gl-mt-3"
            :checked="active"
            data-testid="header-active-input"
            @input="handleHeaderActiveInput(index, $event)"
          >
            {{ __('Active') }}
          </gl-form-checkbox>
        </template>
        <template
          #cell(name)="{
            index,
            item: {
              disabled,
              validationErrors: { name: feedback = '' },
              name,
            },
          }"
        >
          <gl-form-input-group
            class="gl-m-0"
            label-class="!gl-m-0 !gl-p-0"
            :invalid-feedback="feedback"
          >
            <template #prepend>
              <gl-input-group-text>
                {{ s__('AuditStreams|Header') }}
              </gl-input-group-text>
            </template>
            <gl-form-input
              :value="name"
              :placeholder="s__('AuditStreams|ex: limitation')"
              :disabled="disabled"
              :state="feedback === ''"
              data-testid="header-name-input"
              @input="handleHeaderNameInput(index, $event)"
            />
          </gl-form-input-group>
        </template>
        <template #cell(value)="{ index, item: { disabled, value: headerValue } }">
          <gl-form-input-group class="gl-m-0" label-class="!gl-m-0 !gl-p-0">
            <template #prepend>
              <gl-input-group-text>
                {{ __('Value') }}
              </gl-input-group-text>
            </template>
            <gl-form-input
              :value="headerValue"
              :placeholder="s__('AuditStreams|ex: 1000')"
              :disabled="disabled"
              data-testid="header-value-input"
              @input="handleHeaderValueInput(index, $event)"
            />
          </gl-form-input-group>
        </template>
        <template #cell(actions)="{ index }">
          <gl-button
            v-gl-tooltip
            :aria-label="s__('AuditStreams|Remove custom header')"
            :title="__('Remove')"
            category="tertiary"
            icon="remove"
            data-testid="header-delete-button"
            @click="removeHeader(index)"
          />
        </template>
      </gl-table-lite>
      <p v-if="hasNoHeaders" class="gl-mb-5 gl-text-subtle" data-testid="no-header-created">
        {{ s__('AuditStreams|No header created yet.') }}
      </p>
      <p
        v-if="hasReachedMaxHeaders"
        class="gl-mb-0 gl-mt-5 gl-text-subtle"
        data-testid="maximum-headers"
      >
        <gl-sprintf
          :message="s__('AuditStreams|Maximum of %{number} HTTP headers has been reached.')"
        >
          <template #number>
            {{ maxHeaders }}
          </template>
        </gl-sprintf>
      </p>
      <gl-button
        v-else
        :disabled="loading"
        :name="s__('AuditStreams|Add another custom header')"
        variant="confirm"
        category="secondary"
        size="small"
        data-testid="add-header-row-button"
        @click="addBlankHeader"
      >
        {{ s__('AuditStreams|Add header') }}
      </gl-button>
    </div>
  </div>
</template>
